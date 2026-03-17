// Feature: song-unit-rust-migration, Property 11: Database initialization idempotence
// **Validates: Requirements 7.3**

use sea_orm::{ConnectOptions, ConnectionTrait, Database, DatabaseConnection, DbBackend, Statement};

async fn test_db() -> DatabaseConnection {
    let mut opts = ConnectOptions::new("sqlite::memory:");
    opts.sqlx_logging(false);
    Database::connect(opts).await.unwrap()
}

#[tokio::test]
async fn init_schema_is_idempotent_preserves_data() {
    let conn = test_db().await;

    // First init — creates tables
    beadline_core::database::init_song_units_schema(&conn)
        .await
        .unwrap();

    // Insert a song unit via raw SQL
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        r#"INSERT INTO song_units (id, metadata_json, sources_json, preferences_json, hash, is_temporary, created_at, updated_at)
           VALUES ('su-1', '{"title":"Test"}', '{}', '{}', 'abc123', 0, 1000, 1000)"#
            .to_owned(),
    ))
    .await
    .unwrap();

    // Insert a tag association
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        r#"INSERT INTO song_unit_tags (song_unit_id, tag_id, value)
           VALUES ('su-1', 'tag-1', 'hello')"#
            .to_owned(),
    ))
    .await
    .unwrap();

    // Second init — must not alter existing data
    beadline_core::database::init_song_units_schema(&conn)
        .await
        .unwrap();

    // Third init — still idempotent
    beadline_core::database::init_song_units_schema(&conn)
        .await
        .unwrap();

    // Verify song unit is still there and unchanged
    let rows = conn
        .query_all(Statement::from_string(
            DbBackend::Sqlite,
            "SELECT id, metadata_json, hash, is_temporary, created_at FROM song_units".to_owned(),
        ))
        .await
        .unwrap();

    assert_eq!(rows.len(), 1);
    let row = &rows[0];
    assert_eq!(
        row.try_get::<String>("", "id").unwrap(),
        "su-1"
    );
    assert_eq!(
        row.try_get::<String>("", "metadata_json").unwrap(),
        r#"{"title":"Test"}"#
    );
    assert_eq!(
        row.try_get::<String>("", "hash").unwrap(),
        "abc123"
    );
    assert_eq!(
        row.try_get::<i32>("", "is_temporary").unwrap(),
        0
    );
    assert_eq!(
        row.try_get::<i64>("", "created_at").unwrap(),
        1000
    );

    // Verify tag association is still there
    let tag_rows = conn
        .query_all(Statement::from_string(
            DbBackend::Sqlite,
            "SELECT song_unit_id, tag_id, value FROM song_unit_tags".to_owned(),
        ))
        .await
        .unwrap();

    assert_eq!(tag_rows.len(), 1);
    let tag_row = &tag_rows[0];
    assert_eq!(
        tag_row.try_get::<String>("", "song_unit_id").unwrap(),
        "su-1"
    );
    assert_eq!(
        tag_row.try_get::<String>("", "tag_id").unwrap(),
        "tag-1"
    );
    assert_eq!(
        tag_row.try_get::<String>("", "value").unwrap(),
        "hello"
    );
}

#[tokio::test]
async fn init_schema_on_fresh_db_succeeds() {
    let conn = test_db().await;

    // Should succeed on a completely empty database
    beadline_core::database::init_song_units_schema(&conn)
        .await
        .unwrap();

    // Tables should exist — verify by inserting
    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        r#"INSERT INTO song_units (id, metadata_json, sources_json, preferences_json, hash, is_temporary, created_at, updated_at)
           VALUES ('su-fresh', '{}', '{}', '{}', '', 0, 0, 0)"#
            .to_owned(),
    ))
    .await
    .unwrap();

    conn.execute(Statement::from_string(
        DbBackend::Sqlite,
        r#"INSERT INTO song_unit_tags (song_unit_id, tag_id, value)
           VALUES ('su-fresh', 'tag-x', NULL)"#
            .to_owned(),
    ))
    .await
    .unwrap();
}
