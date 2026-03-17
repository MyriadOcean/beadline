use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "song_units")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    pub metadata_json: String,
    pub sources_json: String,
    pub preferences_json: String,
    pub hash: String,
    pub library_location_id: Option<String>,
    pub is_temporary: i32, // 0 or 1
    pub discovered_at: Option<i64>,
    pub original_file_path: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::song_unit_tag::Entity")]
    SongUnitTags,
}

impl Related<super::song_unit_tag::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SongUnitTags.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
