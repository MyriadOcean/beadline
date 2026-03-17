// Tag repository: CRUD, alias, hierarchy operations

use sea_orm::{
    ColumnTrait, Condition,
    DatabaseConnection, EntityTrait, QueryFilter,
    QueryOrder, Set,
};

use crate::entity::{tag, tag_alias};
use crate::error::TagError;
use crate::model::tag::{Tag, TagType};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn tag_type_to_str(tt: &TagType) -> &'static str {
    match tt {
        TagType::BuiltIn => "builtin",
        TagType::User => "user",
        TagType::Automatic => "automatic",
    }
}

fn str_to_tag_type(s: &str) -> TagType {
    match s {
        "builtin" => TagType::BuiltIn,
        "automatic" => TagType::Automatic,
        _ => TagType::User,
    }
}

/// Load aliases for a tag using SeaORM query builder.
async fn load_aliases(conn: &DatabaseConnection, tag_id: &str) -> Result<Vec<String>, TagError> {
    let alias_models = tag_alias::Entity::find()
        .filter(tag_alias::Column::PrimaryTagId.eq(tag_id))
        .all(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    Ok(alias_models.into_iter().map(|m| m.alias_name).collect())
}

/// Convert a `tag::Model` + its aliases into a domain `Tag`.
async fn model_to_tag(conn: &DatabaseConnection, model: tag::Model) -> Result<Tag, TagError> {
    let aliases = load_aliases(conn, &model.id).await?;

    Ok(Tag {
        id: model.id,
        key: model.key,
        value: model.name,
        tag_type: str_to_tag_type(&model.tag_type),
        parent_id: model.parent_id,
        alias_names: aliases,
        include_children: model.include_children,
        is_group: model.is_group,
        is_locked: model.is_locked,
        display_order: model.display_order,
        has_collection_metadata: model.playlist_metadata_json.is_some(),
    })
}

// ---------------------------------------------------------------------------
// CRUD operations (Task 7.1)
// ---------------------------------------------------------------------------

/// Create a new tag. If `value` contains `/` separators, auto-creates parent
/// tags that don't yet exist (hierarchical path creation).
///
/// Returns the leaf tag.
pub async fn create_tag(
    conn: &DatabaseConnection,
    key: Option<String>,
    value: String,
    parent_id: Option<String>,
) -> Result<Tag, TagError> {
    if value.trim().is_empty() {
        return Err(TagError::Invalid("tag value must not be empty".into()));
    }

    // If value contains '/', treat as hierarchical path and auto-create parents.
    if value.contains('/') {
        return create_hierarchical_tag(conn, key.clone(), &value, parent_id).await;
    }

    // Check for duplicate: same key + value + parent_id.
    let mut dup_cond = Condition::all().add(tag::Column::Name.eq(value.as_str()));
    match &key {
        Some(k) => { dup_cond = dup_cond.add(tag::Column::Key.eq(k.as_str())); }
        None => { dup_cond = dup_cond.add(tag::Column::Key.is_null()); }
    }
    match &parent_id {
        Some(pid) => { dup_cond = dup_cond.add(tag::Column::ParentId.eq(pid.as_str())); }
        None => { dup_cond = dup_cond.add(tag::Column::ParentId.is_null()); }
    }

    let existing = tag::Entity::find()
        .filter(dup_cond)
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    if existing.is_some() {
        return Err(TagError::Duplicate(format!(
            "tag already exists: {}{}",
            key.as_deref().map(|k| format!("{}:", k)).unwrap_or_default(),
            value
        )));
    }

    let id = uuid::Uuid::new_v4().to_string();

    let model = tag::ActiveModel {
        id: Set(id.clone()),
        key: Set(key),
        name: Set(value),
        tag_type: Set(tag_type_to_str(&TagType::User).to_owned()),
        parent_id: Set(parent_id),
        include_children: Set(true),
        is_locked: Set(false),
        display_order: Set(0),
        playlist_metadata_json: Set(None),
        is_group: Set(false),
    };
    tag::Entity::insert(model)
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    get_tag(conn, &id).await?.ok_or_else(|| TagError::NotFound(id))
}

/// Create a hierarchical tag path like "a/b/c", auto-creating parents.
async fn create_hierarchical_tag(
    conn: &DatabaseConnection,
    key: Option<String>,
    path: &str,
    root_parent_id: Option<String>,
) -> Result<Tag, TagError> {
    let segments: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();
    if segments.is_empty() {
        return Err(TagError::Invalid("empty path".into()));
    }

    let mut current_parent_id = root_parent_id;

    for (i, segment) in segments.iter().enumerate() {
        let is_leaf = i == segments.len() - 1;

        // Check if this segment already exists under current parent.
        let existing = find_tag_by_key_value_parent(
            conn,
            key.as_deref(),
            segment,
            current_parent_id.as_deref(),
        )
        .await?;

        if let Some(existing_tag) = existing {
            current_parent_id = Some(existing_tag.id.clone());
            if is_leaf {
                return Ok(existing_tag);
            }
        } else {
            // Create this segment.
            let id = uuid::Uuid::new_v4().to_string();

            let model = tag::ActiveModel {
                id: Set(id.clone()),
                key: Set(key.clone()),
                name: Set(segment.to_string()),
                tag_type: Set(tag_type_to_str(&TagType::User).to_owned()),
                parent_id: Set(current_parent_id.clone()),
                include_children: Set(true),
                is_locked: Set(false),
                display_order: Set(0),
                playlist_metadata_json: Set(None),
                is_group: Set(false),
            };
            tag::Entity::insert(model)
                .exec(conn)
                .await
                .map_err(|e| TagError::Database(e.into()))?;

            current_parent_id = Some(id.clone());

            if is_leaf {
                return get_tag(conn, &id)
                    .await?
                    .ok_or_else(|| TagError::NotFound(id));
            }
        }
    }

    Err(TagError::Invalid("unexpected end of path".into()))
}

/// Find a tag by key, value (name), and parent_id.
async fn find_tag_by_key_value_parent(
    conn: &DatabaseConnection,
    key: Option<&str>,
    value: &str,
    parent_id: Option<&str>,
) -> Result<Option<Tag>, TagError> {
    let mut cond = Condition::all().add(tag::Column::Name.eq(value));
    match key {
        Some(k) => { cond = cond.add(tag::Column::Key.eq(k)); }
        None => { cond = cond.add(tag::Column::Key.is_null()); }
    }
    match parent_id {
        Some(pid) => { cond = cond.add(tag::Column::ParentId.eq(pid)); }
        None => { cond = cond.add(tag::Column::ParentId.is_null()); }
    }

    let result = tag::Entity::find()
        .filter(cond)
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    match result {
        Some(model) => Ok(Some(model_to_tag(conn, model).await?)),
        None => Ok(None),
    }
}

/// Delete a tag by ID. Rejects deletion of built-in tags.
/// Also deletes associated aliases.
pub async fn delete_tag(conn: &DatabaseConnection, id: &str) -> Result<(), TagError> {
    let tag = get_tag(conn, id)
        .await?
        .ok_or_else(|| TagError::NotFound(id.to_owned()))?;

    if tag.tag_type == TagType::BuiltIn {
        return Err(TagError::CannotDeleteBuiltIn(format!(
            "{}:{}",
            tag.key.as_deref().unwrap_or(""),
            tag.value
        )));
    }

    // Delete aliases first.
    tag_alias::Entity::delete_many()
        .filter(tag_alias::Column::PrimaryTagId.eq(id))
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    // Delete the tag.
    tag::Entity::delete_by_id(id.to_owned())
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    Ok(())
}

/// Update an existing tag's key, value, parent_id, and include_children.
pub async fn update_tag(conn: &DatabaseConnection, tag: &Tag) -> Result<Tag, TagError> {
    // Verify tag exists and get the full model to preserve fields not in domain Tag.
    let existing_model = tag::Entity::find_by_id(tag.id.clone())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?
        .ok_or_else(|| TagError::NotFound(tag.id.clone()))?;

    if tag.value.trim().is_empty() {
        return Err(TagError::Invalid("tag value must not be empty".into()));
    }

    let model = tag::ActiveModel {
        id: Set(tag.id.clone()),
        key: Set(tag.key.clone()),
        name: Set(tag.value.clone()),
        tag_type: Set(existing_model.tag_type.clone()),
        parent_id: Set(tag.parent_id.clone()),
        include_children: Set(tag.include_children),
        is_locked: Set(existing_model.is_locked),
        display_order: Set(existing_model.display_order),
        playlist_metadata_json: Set(existing_model.playlist_metadata_json.clone()),
        is_group: Set(existing_model.is_group),
    };
    tag::Entity::update(model)
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    get_tag(conn, &tag.id)
        .await?
        .ok_or_else(|| TagError::NotFound(tag.id.clone()))
}

/// Get a single tag by ID, including its aliases.
pub async fn get_tag(conn: &DatabaseConnection, id: &str) -> Result<Option<Tag>, TagError> {
    let result = tag::Entity::find_by_id(id.to_owned())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    match result {
        Some(model) => Ok(Some(model_to_tag(conn, model).await?)),
        None => Ok(None),
    }
}

/// Get all tags, each with its aliases loaded.
pub async fn get_all_tags(conn: &DatabaseConnection) -> Result<Vec<Tag>, TagError> {
    let models = tag::Entity::find()
        .order_by_asc(tag::Column::DisplayOrder)
        .order_by_asc(tag::Column::Name)
        .all(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    let mut tags = Vec::with_capacity(models.len());
    for model in models {
        tags.push(model_to_tag(conn, model).await?);
    }
    Ok(tags)
}

/// Get all tags of a specific type (e.g., "builtin", "user", "automatic").
pub async fn get_tags_by_type(conn: &DatabaseConnection, tag_type: &str) -> Result<Vec<Tag>, TagError> {
    let models = tag::Entity::find()
        .filter(tag::Column::TagType.eq(tag_type))
        .order_by_asc(tag::Column::DisplayOrder)
        .order_by_asc(tag::Column::Name)
        .all(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    let mut tags = Vec::with_capacity(models.len());
    for model in models {
        tags.push(model_to_tag(conn, model).await?);
    }
    Ok(tags)
}

// ---------------------------------------------------------------------------
// Hierarchy and alias operations (Task 7.2)
// ---------------------------------------------------------------------------

/// Get direct children of a tag.
pub async fn get_children(
    conn: &DatabaseConnection,
    parent_id: &str,
) -> Result<Vec<Tag>, TagError> {
    let models = tag::Entity::find()
        .filter(tag::Column::ParentId.eq(parent_id))
        .order_by_asc(tag::Column::DisplayOrder)
        .order_by_asc(tag::Column::Name)
        .all(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    let mut tags = Vec::with_capacity(models.len());
    for model in models {
        tags.push(model_to_tag(conn, model).await?);
    }
    Ok(tags)
}

/// Get all descendants of a tag (recursive).
pub async fn get_descendants(
    conn: &DatabaseConnection,
    tag_id: &str,
) -> Result<Vec<Tag>, TagError> {
    let mut result = Vec::new();
    let mut stack = vec![tag_id.to_owned()];

    while let Some(current_id) = stack.pop() {
        let children = get_children(conn, &current_id).await?;
        for child in children {
            stack.push(child.id.clone());
            result.push(child);
        }
    }

    Ok(result)
}

/// Add an alias for a tag.
pub async fn add_alias(
    conn: &DatabaseConnection,
    tag_id: &str,
    alias: &str,
) -> Result<(), TagError> {
    if alias.trim().is_empty() {
        return Err(TagError::Invalid("alias must not be empty".into()));
    }

    // Verify the tag exists.
    get_tag(conn, tag_id)
        .await?
        .ok_or_else(|| TagError::NotFound(tag_id.to_owned()))?;

    // Check if alias already exists.
    let existing = tag_alias::Entity::find_by_id(alias.to_owned())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    if existing.is_some() {
        return Err(TagError::Duplicate(format!("alias already exists: {}", alias)));
    }

    let model = tag_alias::ActiveModel {
        alias_name: Set(alias.to_owned()),
        primary_tag_id: Set(tag_id.to_owned()),
    };
    tag_alias::Entity::insert(model)
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    Ok(())
}

/// Remove an alias by its name.
pub async fn remove_alias(conn: &DatabaseConnection, alias: &str) -> Result<(), TagError> {
    let result = tag_alias::Entity::delete_by_id(alias.to_owned())
        .exec(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    if result.rows_affected == 0 {
        return Err(TagError::NotFound(format!("alias not found: {}", alias)));
    }

    Ok(())
}

/// Resolve a name or alias to a tag. First checks tag names (value), then aliases.
pub async fn resolve_tag(
    conn: &DatabaseConnection,
    name_or_alias: &str,
) -> Result<Option<Tag>, TagError> {
    // First try to find by name (value).
    let tag_model = tag::Entity::find()
        .filter(tag::Column::Name.eq(name_or_alias))
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    if let Some(model) = tag_model {
        return Ok(Some(model_to_tag(conn, model).await?));
    }

    // Then try to find by alias.
    let alias_model = tag_alias::Entity::find_by_id(name_or_alias.to_owned())
        .one(conn)
        .await
        .map_err(|e| TagError::Database(e.into()))?;

    match alias_model {
        Some(alias) => get_tag(conn, &alias.primary_tag_id).await,
        None => Ok(None),
    }
}

/// Build the full hierarchical path string for a tag by walking up the parent chain.
/// E.g. if tag C has parent B which has parent A, returns "A/B/C".
pub async fn get_tag_path(conn: &DatabaseConnection, tag_id: &str) -> Result<String, TagError> {
    let mut segments = Vec::new();
    let mut current_id = Some(tag_id.to_owned());

    // Safety limit to prevent infinite loops from corrupt data.
    let mut depth = 0;
    const MAX_DEPTH: usize = 100;

    while let Some(ref id) = current_id {
        if depth >= MAX_DEPTH {
            return Err(TagError::CircularHierarchy(format!(
                "exceeded max depth {} while resolving path for tag {}",
                MAX_DEPTH, tag_id
            )));
        }

        let tag = get_tag(conn, id)
            .await?
            .ok_or_else(|| TagError::NotFound(id.clone()))?;

        segments.push(tag.value.clone());
        current_id = tag.parent_id.clone();
        depth += 1;
    }

    segments.reverse();
    Ok(segments.join("/"))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::init_database;
    use crate::model::tag::BUILT_IN_KEYS;
    use proptest::prelude::*;

    async fn test_db() -> DatabaseConnection {
        init_database(":memory:").await.expect("init_database failed")
    }

    // -- CRUD tests (7.1) --

    #[tokio::test]
    async fn test_create_and_get_nameless_tag() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        assert!(tag.is_nameless());
        assert_eq!(tag.value, "rock");
        assert_eq!(tag.key, None);

        let fetched = get_tag(&conn, &tag.id).await.unwrap().unwrap();
        assert_eq!(fetched.id, tag.id);
        assert_eq!(fetched.value, "rock");
    }

    #[tokio::test]
    async fn test_create_and_get_named_tag() {
        let conn = test_db().await;
        let tag = create_tag(&conn, Some("artist".into()), "luotianyi".into(), None)
            .await
            .unwrap();
        assert!(tag.is_named());
        assert_eq!(tag.key, Some("artist".into()));
        assert_eq!(tag.value, "luotianyi");
    }

    #[tokio::test]
    async fn test_create_duplicate_rejected() {
        let conn = test_db().await;
        create_tag(&conn, None, "rock".into(), None).await.unwrap();
        let result = create_tag(&conn, None, "rock".into(), None).await;
        assert!(matches!(result, Err(TagError::Duplicate(_))));
    }

    #[tokio::test]
    async fn test_create_empty_value_rejected() {
        let conn = test_db().await;
        let result = create_tag(&conn, None, "".into(), None).await;
        assert!(matches!(result, Err(TagError::Invalid(_))));
    }

    #[tokio::test]
    async fn test_delete_user_tag() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        delete_tag(&conn, &tag.id).await.unwrap();
        assert!(get_tag(&conn, &tag.id).await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_delete_builtin_rejected() {
        let conn = test_db().await;
        let all = get_all_tags(&conn).await.unwrap();
        let builtin = all.iter().find(|t| t.tag_type == TagType::BuiltIn).unwrap();
        let result = delete_tag(&conn, &builtin.id).await;
        assert!(matches!(result, Err(TagError::CannotDeleteBuiltIn(_))));
    }

    #[tokio::test]
    async fn test_delete_removes_aliases() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        add_alias(&conn, &tag.id, "ロック").await.unwrap();
        delete_tag(&conn, &tag.id).await.unwrap();
        // Alias should be gone too.
        let resolved = resolve_tag(&conn, "ロック").await.unwrap();
        assert!(resolved.is_none());
    }

    #[tokio::test]
    async fn test_update_tag() {
        let conn = test_db().await;
        let mut tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        tag.value = "metal".into();
        let updated = update_tag(&conn, &tag).await.unwrap();
        assert_eq!(updated.value, "metal");
    }

    #[tokio::test]
    async fn test_get_all_tags_includes_builtin() {
        let conn = test_db().await;
        create_tag(&conn, None, "rock".into(), None).await.unwrap();
        let all = get_all_tags(&conn).await.unwrap();
        // At least built-in tags + our new one.
        assert!(all.len() >= BUILT_IN_KEYS.len() + 1);
    }

    // -- Hierarchy tests (7.1 + 7.2) --

    #[tokio::test]
    async fn test_hierarchical_path_auto_creates_parents() {
        let conn = test_db().await;
        let leaf = create_tag(&conn, None, "a/b/c".into(), None).await.unwrap();
        assert_eq!(leaf.value, "c");
        assert!(leaf.parent_id.is_some());

        // Verify the full chain exists.
        let path = get_tag_path(&conn, &leaf.id).await.unwrap();
        assert_eq!(path, "a/b/c");
    }

    #[tokio::test]
    async fn test_hierarchical_path_reuses_existing_parents() {
        let conn = test_db().await;
        let first = create_tag(&conn, None, "a/b".into(), None).await.unwrap();
        let second = create_tag(&conn, None, "a/b/c".into(), None).await.unwrap();

        // "b" should be the same tag in both cases.
        assert_eq!(second.parent_id.as_deref(), Some(first.id.as_str()));
    }

    // -- Hierarchy and alias tests (7.2) --

    #[tokio::test]
    async fn test_get_children() {
        let conn = test_db().await;
        let parent = create_tag(&conn, None, "vocaloid".into(), None).await.unwrap();
        let _c1 = create_tag(&conn, None, "luotianyi".into(), Some(parent.id.clone()))
            .await
            .unwrap();
        let _c2 = create_tag(&conn, None, "yanhe".into(), Some(parent.id.clone()))
            .await
            .unwrap();

        let children = get_children(&conn, &parent.id).await.unwrap();
        assert_eq!(children.len(), 2);
    }

    #[tokio::test]
    async fn test_get_descendants() {
        let conn = test_db().await;
        // Create a/b/c hierarchy.
        let leaf = create_tag(&conn, None, "a/b/c".into(), None).await.unwrap();
        // Find root "a".
        let all = get_all_tags(&conn).await.unwrap();
        let root = all
            .iter()
            .find(|t| t.value == "a" && t.parent_id.is_none() && t.tag_type == TagType::User)
            .unwrap();

        let descendants = get_descendants(&conn, &root.id).await.unwrap();
        // Should have "b" and "c".
        assert_eq!(descendants.len(), 2);
        assert!(descendants.iter().any(|t| t.value == "b"));
        assert!(descendants.iter().any(|t| t.id == leaf.id));
    }

    #[tokio::test]
    async fn test_add_and_resolve_alias() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        add_alias(&conn, &tag.id, "ロック").await.unwrap();

        let resolved = resolve_tag(&conn, "ロック").await.unwrap().unwrap();
        assert_eq!(resolved.id, tag.id);

        // Also verify alias appears in tag's alias_names.
        let fetched = get_tag(&conn, &tag.id).await.unwrap().unwrap();
        assert!(fetched.alias_names.contains(&"ロック".to_owned()));
    }

    #[tokio::test]
    async fn test_resolve_by_name() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        let resolved = resolve_tag(&conn, "rock").await.unwrap().unwrap();
        assert_eq!(resolved.id, tag.id);
    }

    #[tokio::test]
    async fn test_resolve_nonexistent() {
        let conn = test_db().await;
        let resolved = resolve_tag(&conn, "nonexistent").await.unwrap();
        assert!(resolved.is_none());
    }

    #[tokio::test]
    async fn test_remove_alias() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        add_alias(&conn, &tag.id, "ロック").await.unwrap();
        remove_alias(&conn, "ロック").await.unwrap();

        let resolved = resolve_tag(&conn, "ロック").await.unwrap();
        assert!(resolved.is_none());
    }

    #[tokio::test]
    async fn test_remove_nonexistent_alias() {
        let conn = test_db().await;
        let result = remove_alias(&conn, "nope").await;
        assert!(matches!(result, Err(TagError::NotFound(_))));
    }

    #[tokio::test]
    async fn test_duplicate_alias_rejected() {
        let conn = test_db().await;
        let t1 = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        let t2 = create_tag(&conn, None, "metal".into(), None).await.unwrap();
        add_alias(&conn, &t1.id, "heavy").await.unwrap();
        let result = add_alias(&conn, &t2.id, "heavy").await;
        assert!(matches!(result, Err(TagError::Duplicate(_))));
    }

    #[tokio::test]
    async fn test_get_tag_path_single() {
        let conn = test_db().await;
        let tag = create_tag(&conn, None, "rock".into(), None).await.unwrap();
        let path = get_tag_path(&conn, &tag.id).await.unwrap();
        assert_eq!(path, "rock");
    }

    #[tokio::test]
    async fn test_named_tag_hierarchy() {
        let conn = test_db().await;
        // Named tags can also have hierarchy.
        let parent = create_tag(&conn, Some("genre".into()), "electronic".into(), None)
            .await
            .unwrap();
        let child = create_tag(
            &conn,
            Some("genre".into()),
            "trance".into(),
            Some(parent.id.clone()),
        )
        .await
        .unwrap();

        let children = get_children(&conn, &parent.id).await.unwrap();
        assert_eq!(children.len(), 1);
        assert_eq!(children[0].id, child.id);
        assert!(children[0].is_named());
    }

    // -----------------------------------------------------------------------
    // Property-based tests (Task 7.3)
    // -----------------------------------------------------------------------

    /// Strategy: pick a random index into BUILT_IN_KEYS.
    fn arb_builtin_key_index() -> impl Strategy<Value = usize> {
        0..BUILT_IN_KEYS.len()
    }

    /// Strategy: generate a simple alphabetic tag segment (1-8 lowercase chars).
    fn arb_tag_segment() -> impl Strategy<Value = String> {
        "[a-z]{1,8}"
    }

    /// Strategy: generate a hierarchical path with 2-5 unique segments joined by '/'.
    fn arb_hierarchical_path() -> impl Strategy<Value = (Vec<String>, String)> {
        // Generate 2-5 segments, then join them.
        proptest::collection::vec(arb_tag_segment(), 2..=5).prop_map(|segments| {
            // Ensure uniqueness by appending index suffix to avoid duplicates.
            let unique: Vec<String> = segments
                .iter()
                .enumerate()
                .map(|(i, s)| format!("{}{}", s, i))
                .collect();
            let path = unique.join("/");
            (unique, path)
        })
    }

    /// Strategy: whether the tag is named (Some key) or nameless (None).
    fn arb_optional_key() -> impl Strategy<Value = Option<String>> {
        prop_oneof![
            Just(None),
            "[a-z]{2,6}".prop_map(Some),
        ]
    }

    proptest! {
        // Feature: tag-search-system, Property 2: Built-in tag keys cannot be deleted
        // Validates: Requirements 3.2
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn builtin_tags_cannot_be_deleted(idx in arb_builtin_key_index()) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let conn = init_database(":memory:").await.unwrap();
                let key = BUILT_IN_KEYS[idx];

                // Find the built-in tag for this key.
                let all = get_all_tags(&conn).await.unwrap();
                let builtin = all
                    .iter()
                    .find(|t| t.tag_type == TagType::BuiltIn && t.key.as_deref() == Some(key))
                    .expect("built-in tag must exist after init");

                // Attempt to delete it — must fail.
                let result = delete_tag(&conn, &builtin.id).await;
                prop_assert!(
                    matches!(result, Err(TagError::CannotDeleteBuiltIn(_))),
                    "deleting built-in key '{}' must return CannotDeleteBuiltIn, got {:?}",
                    key,
                    result
                );

                // Tag must still exist.
                let still_there = get_tag(&conn, &builtin.id).await.unwrap();
                prop_assert!(still_there.is_some(), "built-in tag '{}' must still exist after failed delete", key);

                Ok(())
            })?;
        }
    }

    proptest! {
        // Feature: tag-search-system, Property 3: Parent-child relationships work for both named and nameless tags
        // Validates: Requirements 4.1
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn parent_child_works_for_named_and_nameless(
            parent_key in arb_optional_key(),
            child_key in arb_optional_key(),
            parent_value in arb_tag_segment(),
            child_value in arb_tag_segment(),
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let conn = init_database(":memory:").await.unwrap();

                // Create parent tag.
                let parent = create_tag(&conn, parent_key.clone(), parent_value.clone(), None)
                    .await
                    .unwrap();

                // Create child tag under parent.
                let child = create_tag(&conn, child_key.clone(), child_value.clone(), Some(parent.id.clone()))
                    .await
                    .unwrap();

                // Verify child's parent_id points to parent.
                prop_assert_eq!(
                    child.parent_id.as_deref(),
                    Some(parent.id.as_str()),
                    "child.parent_id must equal parent.id"
                );

                // Verify get_children returns the child.
                let children = get_children(&conn, &parent.id).await.unwrap();
                prop_assert!(
                    children.iter().any(|c| c.id == child.id),
                    "get_children must include the child tag"
                );

                // Verify named/nameless classification is preserved.
                let expected_parent_named = parent_key.as_ref().map_or(false, |k| !k.is_empty());
                prop_assert_eq!(parent.is_named(), expected_parent_named);

                let expected_child_named = child_key.as_ref().map_or(false, |k| !k.is_empty());
                prop_assert_eq!(child.is_named(), expected_child_named);

                Ok(())
            })?;
        }
    }

    proptest! {
        // Feature: tag-search-system, Property 4: Hierarchical path creation auto-creates parents
        // Validates: Requirements 4.2
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn hierarchical_path_auto_creates_parents(
            (segments, path) in arb_hierarchical_path(),
            key in arb_optional_key(),
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let conn = init_database(":memory:").await.unwrap();
                let n = segments.len();

                // Create the hierarchical tag.
                let leaf = create_tag(&conn, key.clone(), path.clone(), None)
                    .await
                    .unwrap();

                // The leaf's value should be the last segment.
                prop_assert_eq!(
                    &leaf.value,
                    segments.last().unwrap(),
                    "leaf value must be the last segment"
                );

                // Walk up the parent chain and collect all tags.
                let mut chain = Vec::new();
                let mut current_id = Some(leaf.id.clone());
                while let Some(ref id) = current_id {
                    let tag = get_tag(&conn, id).await.unwrap().unwrap();
                    current_id = tag.parent_id.clone();
                    chain.push(tag);
                }

                // Chain length must equal number of segments.
                prop_assert_eq!(
                    chain.len(),
                    n,
                    "parent chain length must equal number of path segments ({}), got {}",
                    n,
                    chain.len()
                );

                // Reverse to get root-to-leaf order and verify values match segments.
                chain.reverse();
                for (i, tag) in chain.iter().enumerate() {
                    prop_assert_eq!(
                        &tag.value,
                        &segments[i],
                        "segment {} value mismatch: expected '{}', got '{}'",
                        i,
                        segments[i],
                        tag.value
                    );
                }

                // Verify the full path via get_tag_path.
                let reconstructed_path = get_tag_path(&conn, &leaf.id).await.unwrap();
                prop_assert_eq!(
                    reconstructed_path,
                    path,
                    "get_tag_path must reconstruct the original path"
                );

                Ok(())
            })?;
        }
    }
}
