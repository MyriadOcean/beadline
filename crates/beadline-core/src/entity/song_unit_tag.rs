use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "song_unit_tags")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub song_unit_id: String,
    #[sea_orm(primary_key, auto_increment = false)]
    pub tag_id: String,
    pub value: Option<String>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::song_unit::Entity",
        from = "Column::SongUnitId",
        to = "super::song_unit::Column::Id"
    )]
    SongUnit,
}

impl Related<super::song_unit::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SongUnit.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
