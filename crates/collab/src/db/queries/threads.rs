use super::*;
use anyhow::Context as _;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThreadMetadata {
    pub id: Uuid,
    pub thread_type: String,
    pub title: String,
    pub summary: Option<String>,
    pub updated_at: DateTimeUtc,
}

#[derive(Debug, Clone)]
pub struct ThreadData {
    pub id: Uuid,
    pub thread_type: String,
    pub data_type: String,
    pub data: Vec<u8>,
    pub updated_at: DateTimeUtc,
}

impl Database {
    /// Get all threads for a user (metadata only)
    pub async fn get_user_threads(
        &self,
        user_id: UserId,
    ) -> Result<Vec<ThreadMetadata>> {
        self.transaction(|tx| async move {
            let threads = thread::Entity::find()
                .filter(thread::Column::UserId.eq(user_id))
                .order_by_desc(thread::Column::UpdatedAt)
                .all(&*tx)
                .await?;

            Ok(threads
                .into_iter()
                .map(|thread| ThreadMetadata {
                    id: thread.id,
                    thread_type: thread.thread_type,
                    title: thread.title,
                    summary: thread.summary,
                    updated_at: thread.updated_at,
                })
                .collect())
        })
        .await
    }

    /// Get a specific thread (full data)
    pub async fn get_thread(
        &self,
        thread_id: Uuid,
        user_id: UserId,
    ) -> Result<Option<ThreadData>> {
        self.transaction(|tx| async move {
            let thread = thread::Entity::find_by_id(thread_id)
                .filter(thread::Column::UserId.eq(user_id))
                .one(&*tx)
                .await?;

            Ok(thread.map(|t| ThreadData {
                id: t.id,
                thread_type: t.thread_type,
                data_type: t.data_type,
                data: t.data,
                updated_at: t.updated_at,
            }))
        })
        .await
    }

    /// Create or update a thread
    pub async fn upsert_thread(
        &self,
        thread_id: Uuid,
        user_id: UserId,
        thread_type: String,
        title: String,
        summary: Option<String>,
        data_type: String,
        data: Vec<u8>,
    ) -> Result<DateTimeUtc> {
        self.transaction(|tx| async move {
            let now = Utc::now();

            let existing = thread::Entity::find_by_id(thread_id)
                .filter(thread::Column::UserId.eq(user_id))
                .one(&*tx)
                .await?;

            if let Some(_existing) = existing {
                // Update existing thread
                thread::ActiveModel {
                    id: ActiveValue::Set(thread_id),
                    user_id: ActiveValue::Set(user_id),
                    thread_type: ActiveValue::Set(thread_type),
                    title: ActiveValue::Set(title),
                    summary: ActiveValue::Set(summary),
                    data_type: ActiveValue::Set(data_type),
                    data: ActiveValue::Set(data),
                    updated_at: ActiveValue::Set(now),
                    ..Default::default()
                }
                .update(&*tx)
                .await?;
            } else {
                // Insert new thread
                thread::ActiveModel {
                    id: ActiveValue::Set(thread_id),
                    user_id: ActiveValue::Set(user_id),
                    thread_type: ActiveValue::Set(thread_type),
                    title: ActiveValue::Set(title),
                    summary: ActiveValue::Set(summary),
                    data_type: ActiveValue::Set(data_type),
                    data: ActiveValue::Set(data),
                    created_at: ActiveValue::Set(now),
                    updated_at: ActiveValue::Set(now),
                }
                .insert(&*tx)
                .await?;
            }

            Ok(now)
        })
        .await
    }

    /// Delete a thread
    pub async fn delete_thread(
        &self,
        thread_id: Uuid,
        user_id: UserId,
    ) -> Result<bool> {
        self.transaction(|tx| async move {
            let result = thread::Entity::delete_many()
                .filter(thread::Column::Id.eq(thread_id))
                .filter(thread::Column::UserId.eq(user_id))
                .exec(&*tx)
                .await?;

            Ok(result.rows_affected > 0)
        })
        .await
    }

    /// Get threads updated since a given timestamp
    pub async fn get_threads_updated_since(
        &self,
        user_id: UserId,
        since: DateTimeUtc,
    ) -> Result<Vec<ThreadMetadata>> {
        self.transaction(|tx| async move {
            let threads = thread::Entity::find()
                .filter(thread::Column::UserId.eq(user_id))
                .filter(thread::Column::UpdatedAt.gt(since))
                .order_by_desc(thread::Column::UpdatedAt)
                .all(&*tx)
                .await?;

            Ok(threads
                .into_iter()
                .map(|thread| ThreadMetadata {
                    id: thread.id,
                    thread_type: thread.thread_type,
                    title: thread.title,
                    summary: thread.summary,
                    updated_at: thread.updated_at,
                })
                .collect())
        })
        .await
    }
}
