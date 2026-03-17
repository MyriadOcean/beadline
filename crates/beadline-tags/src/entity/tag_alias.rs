use sea_orm::entity::prelude::*;

/// sea-orm entity for the `tag_aliases` table.
#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel)]
#[sea_orm(table_name = "tag_aliases")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub alias_name: String,
    pub primary_tag_id: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::tag::Entity",
        from = "Column::PrimaryTagId",
        to = "super::tag::Column::Id"
    )]
    Tag,
}

impl Related<super::tag::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Tag.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
