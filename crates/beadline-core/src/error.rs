#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("database error: {0}")]
    Database(#[from] sea_orm::DbErr),

    #[error("JSON serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("song unit not found: {0}")]
    NotFound(String),

    #[error("invalid input: {0}")]
    Invalid(String),
}
