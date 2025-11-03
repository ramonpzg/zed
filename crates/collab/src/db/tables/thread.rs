use crate::db::UserId;
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel)]
#[sea_orm(table_name = "threads")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: Uuid,
    pub user_id: UserId,
    pub thread_type: String,
    pub title: String,
    pub summary: Option<String>,
    pub data_type: String,
    pub data: Vec<u8>,
    pub created_at: DateTimeUtc,
    pub updated_at: DateTimeUtc,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::user::Entity",
        from = "Column::UserId",
        to = "super::user::Column::Id"
    )]
    User,
}

impl Related<super::user::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::User.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ThreadType {
    Text,
    Coding,
}

impl ThreadType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ThreadType::Text => "text",
            ThreadType::Coding => "coding",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "text" => Some(ThreadType::Text),
            "coding" => Some(ThreadType::Coding),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DataType {
    Json,
    Zstd,
}

impl DataType {
    pub fn as_str(&self) -> &'static str {
        match self {
            DataType::Json => "json",
            DataType::Zstd => "zstd",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "json" => Some(DataType::Json),
            "zstd" => Some(DataType::Zstd),
            _ => None,
        }
    }
}
