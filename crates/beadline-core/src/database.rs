use sea_orm::{ConnectionTrait, DatabaseConnection, DbBackend, Schema};

use crate::entity::{song_unit, song_unit_tag};
use crate::error::CoreError;

pub async fn init_song_units_schema(conn: &DatabaseConnection) -> Result<(), CoreError> {
    let schema = Schema::new(DbBackend::Sqlite);

    let stmt = schema
        .create_table_from_entity(song_unit::Entity)
        .if_not_exists()
        .to_owned();
    conn.execute(conn.get_database_backend().build(&stmt))
        .await?;

    let stmt = schema
        .create_table_from_entity(song_unit_tag::Entity)
        .if_not_exists()
        .to_owned();
    conn.execute(conn.get_database_backend().build(&stmt))
        .await?;

    Ok(())
}
