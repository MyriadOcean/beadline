// FRB-exposed database init/close functions

use sea_orm::DatabaseConnection;
use std::sync::OnceLock;
use tokio::sync::Mutex;

/// Global database connection, initialized once via `init_database()`.
/// Wrapped in Mutex<Option<...>> so we can take ownership on close.
static DB: OnceLock<Mutex<Option<DatabaseConnection>>> = OnceLock::new();

/// Get a reference to the global database Mutex.
fn db_slot() -> &'static Mutex<Option<DatabaseConnection>> {
    DB.get_or_init(|| Mutex::new(None))
}

/// Acquire the DB connection guard. Returns an error string if not initialized.
pub(crate) async fn lock_db() -> Result<tokio::sync::MutexGuard<'static, Option<DatabaseConnection>>, String> {
    let guard = db_slot().lock().await;
    if guard.is_none() {
        return Err("database not initialized — call init_database() first".to_string());
    }
    Ok(guard)
}

/// Initialize the SQLite database at `db_path`.
///
/// Runs migrations and ensures built-in tags exist.
/// Must be called once before any other tag/search operations.
pub async fn init_database(db_path: String) -> Result<(), String> {
    let conn = beadline_tags::database::init_database(&db_path)
        .await
        .map_err(|e| e.to_string())?;

    beadline_core::database::init_song_units_schema(&conn)
        .await
        .map_err(|e| e.to_string())?;

    let mut guard = db_slot().lock().await;
    if guard.is_some() {
        return Err("database already initialized".to_string());
    }
    *guard = Some(conn);
    Ok(())
}

/// Close the database connection.
///
/// After calling this, no further tag/search operations are possible
/// until `init_database()` is called again.
pub async fn close_database() -> Result<(), String> {
    let mut guard = db_slot().lock().await;
    let conn = guard.take().ok_or("database not initialized")?;
    beadline_tags::database::close_database(conn)
        .await
        .map_err(|e| e.to_string())
}
