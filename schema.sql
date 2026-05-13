-- iReal Forum Database Schema

CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT    NOT NULL UNIQUE,
  email         TEXT    NOT NULL UNIQUE,
  password_hash TEXT    NOT NULL,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- 帖子主体：按曲名+作曲者分组
CREATE TABLE IF NOT EXISTS songs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  title      TEXT NOT NULL,
  composer   TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- 相同曲名+作曲者（不区分大小写）视为同一帖子
CREATE UNIQUE INDEX IF NOT EXISTS idx_songs_title_composer
  ON songs (LOWER(title), LOWER(composer));

-- 版本：每个用户对某首曲子的一次上传（帖子里的一条回复）
CREATE TABLE IF NOT EXISTS versions (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id    INTEGER NOT NULL REFERENCES songs(id),
  user_id    INTEGER NOT NULL REFERENCES users(id),
  style      TEXT NOT NULL DEFAULT '',
  key_sig    TEXT NOT NULL DEFAULT 'C',
  ireal_url  TEXT NOT NULL,               -- 不暴露给前端
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (song_id, user_id)               -- 每人每首曲只能有一个版本
);

-- 评论：挂在帖子（song）层级
CREATE TABLE IF NOT EXISTS comments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id    INTEGER NOT NULL REFERENCES songs(id),
  user_id    INTEGER NOT NULL REFERENCES users(id),
  content    TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 点赞：针对某个版本
CREATE TABLE IF NOT EXISTS likes (
  version_id INTEGER NOT NULL REFERENCES versions(id),
  user_id    INTEGER NOT NULL REFERENCES users(id),
  PRIMARY KEY (version_id, user_id)
);

-- 收藏：针对整首曲子（帖子）
CREATE TABLE IF NOT EXISTS favorites (
  song_id    INTEGER NOT NULL REFERENCES songs(id),
  user_id    INTEGER NOT NULL REFERENCES users(id),
  PRIMARY KEY (song_id, user_id)
);
