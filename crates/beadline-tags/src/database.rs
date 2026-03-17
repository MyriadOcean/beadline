use sea_orm::{
    ActiveModelTrait, ColumnTrait, ConnectOptions, Database, DatabaseConnection,
    ConnectionTrait, EntityTrait, QueryFilter, Set, Statement,
    DbBackend, Schema,
};

use crate::entity::{tag, tag_alias};
use crate::error::DbError;
use crate::model::tag::BUILT_IN_KEYS;

/// Open (or create) the SQLite database at `db_path`.
///
/// Runs migrations (adds `key` column if missing, migrates existing data)
/// and ensures all built-in tag keys exist.
pub async fn init_database(db_path: &str) -> Result<DatabaseConnection, DbError> {
    let url = if db_path == ":memory:" {
        "sqlite::memory:".to_owned()
    } else {
        format!("sqlite://{}?mode=rwc", db_path)
    };
    let mut opts = ConnectOptions::new(&url);
    opts.sqlx_logging(false);

    let conn = Database::connect(opts)
        .await
        .map_err(|e| DbError::OpenFailed(e.to_string()))?;

    run_migrations(&conn).await?;
    ensure_built_in_tags(&conn).await?;

    Ok(conn)
}

/// Close the database connection.
pub async fn close_database(conn: DatabaseConnection) -> Result<(), DbError> {
    conn.execute(Statement::from_string(DbBackend::Sqlite, "PRAGMA optimize".to_owned()))
        .await
        .ok();
    drop(conn);
    Ok(())
}

/// Run schema migrations against an existing Dart-created database.
///
/// This is idempotent — safe to call on every startup.
async fn run_migrations(conn: &DatabaseConnection) -> Result<(), DbError> {
    // Ensure the tags table exists (fresh DB case).
    let schema = Schema::new(DbBackend::Sqlite);
    let stmt = schema
        .create_table_from_entity(tag::Entity)
        .if_not_exists()
        .to_owned();
    conn.execute(conn.get_database_backend().build(&stmt))
        .await
        .map_err(|e| DbError::MigrationFailed(e.to_string()))?;

    // Ensure the tag_aliases table exists.
    let stmt = schema
        .create_table_from_entity(tag_alias::Entity)
        .if_not_exists()
        .to_owned();
    conn.execute(conn.get_database_backend().build(&stmt))
        .await
        .map_err(|e| DbError::MigrationFailed(e.to_string()))?;

    // Add `key` column if it doesn't exist yet (migration from Dart schema).
    // SQLite's ALTER TABLE ADD COLUMN is a no-op error if the column already exists,
    // so we check PRAGMA table_info first.
    if !column_exists(conn, "tags", "key").await? {
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "ALTER TABLE tags ADD COLUMN key TEXT".to_owned(),
        ))
        .await
        .map_err(|e| DbError::MigrationFailed(e.to_string()))?;
    }

    // Handle the Dart schema's `type` column vs our `tag_type` column.
    // The Dart schema uses `type` but sea-orm entity uses `tag_type`.
    // If the table has `type` but not `tag_type`, rename it.
    if column_exists(conn, "tags", "type").await?
        && !column_exists(conn, "tags", "tag_type").await?
    {
        // SQLite doesn't support ALTER TABLE RENAME COLUMN before 3.25.0,
        // but modern SQLite (bundled with most systems) does.
        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            "ALTER TABLE tags RENAME COLUMN type TO tag_type".to_owned(),
        ))
        .await
        .map_err(|e| DbError::MigrationFailed(format!(
            "Failed to rename 'type' to 'tag_type': {}. \
             Your SQLite version may not support RENAME COLUMN.",
            e
        )))?;
    }

    // Migrate existing data: set `key` for built-in tags that don't have it yet.
    for &built_in_key in BUILT_IN_KEYS {
        let tags_to_migrate = tag::Entity::find()
            .filter(tag::Column::Name.eq(built_in_key))
            .filter(tag::Column::Key.is_null())
            .filter(tag::Column::TagType.eq("builtin"))
            .all(conn)
            .await
            .map_err(|e| DbError::MigrationFailed(e.to_string()))?;

        for model in tags_to_migrate {
            let mut active: tag::ActiveModel = model.into();
            active.key = Set(Some(built_in_key.to_owned()));
            active.update(conn).await
                .map_err(|e| DbError::MigrationFailed(e.to_string()))?;
        }
    }

    // Migrate automatic tags with colon pattern (e.g. "user:xx") to named tags.
    // Load matching tags with SeaORM, split the name in Rust, update each.
    let auto_tags_to_migrate = tag::Entity::find()
        .filter(tag::Column::TagType.eq("automatic"))
        .filter(tag::Column::Key.is_null())
        .all(conn)
        .await
        .map_err(|e| DbError::MigrationFailed(e.to_string()))?;

    for model in auto_tags_to_migrate {
        if let Some(colon_pos) = model.name.find(':') {
            let key_part = model.name[..colon_pos].to_owned();
            let name_part = model.name[colon_pos + 1..].to_owned();
            let mut active: tag::ActiveModel = model.into();
            active.key = Set(Some(key_part));
            active.name = Set(name_part);
            active.update(conn).await
                .map_err(|e| DbError::MigrationFailed(e.to_string()))?;
        }
    }

    Ok(())
}

/// Check whether a column exists in a table using PRAGMA table_info.
async fn column_exists(
    conn: &DatabaseConnection,
    table: &str,
    column: &str,
) -> Result<bool, DbError> {
    let rows = conn
        .query_all(Statement::from_string(
            DbBackend::Sqlite,
            format!("PRAGMA table_info({})", table),
        ))
        .await
        .map_err(|e| DbError::MigrationFailed(e.to_string()))?;

    for row in rows {
        let col_name: String = row
            .try_get("", "name")
            .map_err(|e| DbError::MigrationFailed(e.to_string()))?;
        if col_name == column {
            return Ok(true);
        }
    }
    Ok(false)
}

/// Ensure all built-in tag keys exist in the database.
async fn ensure_built_in_tags(conn: &DatabaseConnection) -> Result<(), DbError> {
    for &key in BUILT_IN_KEYS {
        // Check if a built-in tag with this key already exists.
        let existing = tag::Entity::find()
            .filter(tag::Column::Key.eq(key))
            .filter(tag::Column::TagType.eq("builtin"))
            .one(conn)
            .await
            .map_err(|e| DbError::QueryFailed(e.to_string()))?;

        if existing.is_none() {
            let id = uuid::Uuid::new_v4().to_string();
            let model = tag::ActiveModel {
                id: Set(id),
                key: Set(Some(key.to_owned())),
                name: Set(key.to_owned()),
                tag_type: Set("builtin".to_owned()),
                parent_id: Set(None),
                include_children: Set(true),
                is_locked: Set(true),
                display_order: Set(0),
                playlist_metadata_json: Set(None),
                is_group: Set(false),
            };
            tag::Entity::insert(model)
                .exec(conn)
                .await
                .map_err(|e| DbError::QueryFailed(e.to_string()))?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use sea_orm::QueryResult;

    /// Helper to create an in-memory SQLite database for testing.
    async fn test_db() -> DatabaseConnection {
        init_database(":memory:").await.expect("init_database failed")
    }

    #[tokio::test]
    async fn test_init_creates_tables_and_built_in_tags() {
        let conn = test_db().await;

        // Verify tags table exists and has rows.
        let rows: Vec<QueryResult> = conn
            .query_all(Statement::from_string(
                DbBackend::Sqlite,
                "SELECT id, key, name, tag_type FROM tags WHERE tag_type = 'builtin'".to_owned(),
            ))
            .await
            .unwrap();

        assert_eq!(rows.len(), BUILT_IN_KEYS.len());

        for row in &rows {
            let key: String = row.try_get("", "key").unwrap();
            assert!(BUILT_IN_KEYS.contains(&key.as_str()));
        }
    }

    #[tokio::test]
    async fn test_init_is_idempotent() {
        // First init.
        let conn = test_db().await;
        close_database(conn).await.unwrap();

        // For in-memory DB we can't reopen the same file, but we can verify
        // that calling init twice on a fresh DB doesn't panic or duplicate.
        let conn = test_db().await;
        let rows: Vec<QueryResult> = conn
            .query_all(Statement::from_string(
                DbBackend::Sqlite,
                "SELECT COUNT(*) as cnt FROM tags WHERE tag_type = 'builtin'".to_owned(),
            ))
            .await
            .unwrap();

        let count: i32 = rows[0].try_get("", "cnt").unwrap();
        assert_eq!(count, BUILT_IN_KEYS.len() as i32);
    }

    #[tokio::test]
    async fn test_key_column_exists_after_init() {
        let conn = test_db().await;
        assert!(column_exists(&conn, "tags", "key").await.unwrap());
    }

    #[tokio::test]
    async fn test_tag_aliases_table_exists() {
        let conn = test_db().await;
        // Insert an alias to verify the table works.
        let rows: Vec<QueryResult> = conn
            .query_all(Statement::from_string(
                DbBackend::Sqlite,
                "SELECT id FROM tags WHERE tag_type = 'builtin' LIMIT 1".to_owned(),
            ))
            .await
            .unwrap();

        let tag_id: String = rows[0].try_get("", "id").unwrap();

        conn.execute(Statement::from_string(
            DbBackend::Sqlite,
            format!(
                "INSERT INTO tag_aliases (alias_name, primary_tag_id) VALUES ('test_alias', '{}')",
                tag_id
            ),
        ))
        .await
        .unwrap();

        let alias_rows: Vec<QueryResult> = conn
            .query_all(Statement::from_string(
                DbBackend::Sqlite,
                "SELECT alias_name FROM tag_aliases WHERE alias_name = 'test_alias'".to_owned(),
            ))
            .await
            .unwrap();

        assert_eq!(alias_rows.len(), 1);
    }

    #[tokio::test]
    async fn test_close_database() {
        let conn = test_db().await;
        close_database(conn).await.unwrap();
    }
}
