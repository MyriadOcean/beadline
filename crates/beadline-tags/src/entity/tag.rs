use sea_orm::entity::prelude::*;

/// sea-orm entity for the `tags` table.
///
/// The `key` column distinguishes named tags (key is Some) from nameless tags (key is None).
/// Existing columns from the Dart schema are preserved for compatibility.
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel)]
#[sea_orm(table_name = "tags")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    /// For named tags, this is the tag key (e.g. "artist", "album").
    /// For nameless tags, this is None/NULL.
    pub key: Option<String>,
    /// The tag's display name / value.
    pub name: String,
    /// One of: "builtin", "user", "automatic".
    pub tag_type: String,
    pub parent_id: Option<String>,
    pub include_children: bool,
    pub is_locked: bool,
    pub display_order: i32,
    pub playlist_metadata_json: Option<String>,
    pub is_group: bool,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::tag_alias::Entity")]
    Aliases,
}

impl Related<super::tag_alias::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Aliases.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
