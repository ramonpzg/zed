use crate::{AppState, Error, Result, db::{UserId, queries::threads::{ThreadMetadata, ThreadData}}, rpc::Principal};
use axum::{
    Extension, Json, Router,
    extract::{Path, Query},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, put, delete},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use time::OffsetDateTime;
use uuid::Uuid;

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/threads", get(list_threads))
        .route("/threads/:id", get(get_thread))
        .route("/threads/:id", put(upsert_thread))
        .route("/threads/:id", delete(delete_thread))
        .layer(middleware::from_fn(crate::auth::validate_header))
}

#[derive(Deserialize)]
struct ListThreadsQuery {
    since: Option<String>,
}

#[derive(Serialize)]
struct ListThreadsResponse {
    threads: Vec<ThreadMetadata>,
}

async fn list_threads(
    Extension(principal): Extension<Principal>,
    Query(params): Query<ListThreadsQuery>,
    Extension(app): Extension<Arc<AppState>>,
) -> Result<Json<ListThreadsResponse>> {
    let user_id = match &principal {
        Principal::User(user) => user.id,
        Principal::Impersonated { user, .. } => user.id,
    };
    let threads = if let Some(since_str) = params.since {
        let since = OffsetDateTime::parse(&since_str, &time::format_description::well_known::Rfc3339)
            .map_err(|_| Error::http(
                StatusCode::BAD_REQUEST,
                "invalid since timestamp".to_string(),
            ))?;
        app.db.get_threads_updated_since(user_id, since.into()).await?
    } else {
        app.db.get_user_threads(user_id).await?
    };

    Ok(Json(ListThreadsResponse { threads }))
}

#[derive(Serialize)]
struct GetThreadResponse {
    id: Uuid,
    thread_type: String,
    data_type: String,
    data: String,
    updated_at: String,
}

async fn get_thread(
    Path(thread_id): Path<Uuid>,
    Extension(principal): Extension<Principal>,
    Extension(app): Extension<Arc<AppState>>,
) -> Result<impl IntoResponse> {
    let user_id = match &principal {
        Principal::User(user) => user.id,
        Principal::Impersonated { user, .. } => user.id,
    };
    let thread = app
        .db
        .get_thread(thread_id, user_id)
        .await?
        .ok_or_else(|| Error::http(
            StatusCode::NOT_FOUND,
            "thread not found".to_string(),
        ))?;

    let data_base64 = base64::engine::general_purpose::STANDARD.encode(&thread.data);

    Ok(Json(GetThreadResponse {
        id: thread.id,
        thread_type: thread.thread_type,
        data_type: thread.data_type,
        data: data_base64,
        updated_at: thread.updated_at.to_rfc3339(),
    }))
}

#[derive(Deserialize)]
struct UpsertThreadRequest {
    thread_type: String,
    title: String,
    summary: Option<String>,
    data_type: String,
    data: String,
}

#[derive(Serialize)]
struct UpsertThreadResponse {
    success: bool,
    updated_at: String,
}

async fn upsert_thread(
    Path(thread_id): Path<Uuid>,
    Extension(principal): Extension<Principal>,
    Extension(app): Extension<Arc<AppState>>,
    Json(request): Json<UpsertThreadRequest>,
) -> Result<Json<UpsertThreadResponse>> {
    let user_id = match &principal {
        Principal::User(user) => user.id,
        Principal::Impersonated { user, .. } => user.id,
    };
    let data = base64::engine::general_purpose::STANDARD
        .decode(&request.data)
        .map_err(|_| Error::http(
            StatusCode::BAD_REQUEST,
            "invalid base64 data".to_string(),
        ))?;

    let updated_at = app
        .db
        .upsert_thread(
            thread_id,
            user_id,
            request.thread_type,
            request.title,
            request.summary,
            request.data_type,
            data,
        )
        .await?;

    Ok(Json(UpsertThreadResponse {
        success: true,
        updated_at: updated_at.to_rfc3339(),
    }))
}

#[derive(Serialize)]
struct DeleteThreadResponse {
    success: bool,
}

async fn delete_thread(
    Path(thread_id): Path<Uuid>,
    Extension(principal): Extension<Principal>,
    Extension(app): Extension<Arc<AppState>>,
) -> Result<Json<DeleteThreadResponse>> {
    let user_id = match &principal {
        Principal::User(user) => user.id,
        Principal::Impersonated { user, .. } => user.id,
    };
    let deleted = app.db.delete_thread(thread_id, user_id).await?;

    if !deleted {
        return Err(Error::http(
            StatusCode::NOT_FOUND,
            "thread not found".to_string(),
        ));
    }

    Ok(Json(DeleteThreadResponse { success: true }))
}
