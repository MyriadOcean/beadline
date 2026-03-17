use thiserror::Error;

/// Errors from tag CRUD operations.
#[derive(Debug, Error)]
pub enum TagError {
    #[error("tag not found: {0}")]
    NotFound(String),
    #[error("cannot delete built-in tag: {0}")]
    CannotDeleteBuiltIn(String),
    #[error("duplicate tag: {0}")]
    Duplicate(String),
    #[error("invalid tag: {0}")]
    Invalid(String),
    #[error("circular hierarchy detected: {0}")]
    CircularHierarchy(String),
    #[error("not a collection: {0}")]
    NotACollection(String),
    #[error("collection item not found: {0}")]
    CollectionItemNotFound(String),
    #[error("circular reference detected: {0} -> {1}")]
    CircularReference(String, String),
    #[error("max nesting depth exceeded")]
    MaxDepthExceeded,
    #[error("database error: {0}")]
    Database(#[from] DbError),
}

/// Errors from query parsing.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub struct ParseError {
    pub message: String,
    pub position: usize,
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "parse error at position {}: {}", self.position, self.message)
    }
}

/// Errors from database operations.
#[derive(Debug, Error)]
pub enum DbError {
    #[error("failed to open database: {0}")]
    OpenFailed(String),
    #[error("migration failed: {0}")]
    MigrationFailed(String),
    #[error("query failed: {0}")]
    QueryFailed(String),
    #[error("sea-orm error: {0}")]
    SeaOrm(#[from] sea_orm::DbErr),
}

/// Errors from query evaluation.
#[derive(Debug, Error)]
pub enum EvalError {
    #[error("evaluation error: {0}")]
    EvaluationFailed(String),
}

/// Errors from the suggestion engine.
#[derive(Debug, Error)]
pub enum SuggestionError {
    #[error("suggestion error: {0}")]
    Failed(String),
}
