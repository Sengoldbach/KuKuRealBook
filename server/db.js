const { Database: SqliteDB } = require('node-sqlite3-wasm')
const path = require('path')
const fs   = require('fs')

const DATA_DIR    = process.env.DATA_DIR || path.join(__dirname, '..', 'data')
const DB_PATH     = path.join(DATA_DIR, 'forum.db')
const SCHEMA_PATH = path.join(__dirname, '..', 'schema.sql')

fs.mkdirSync(DATA_DIR, { recursive: true })
// 清理可能被强制终止的进程留下的 WAL 锁目录
try { fs.rmSync(DB_PATH + '.lock', { recursive: true, force: true }) } catch {}

// node-sqlite3-wasm 的 API 与 better-sqlite3 略有不同，
// 这个兼容层让路由代码无需修改。
class Statement {
  constructor(raw, db) {
    this._raw = raw
    this._db  = db
  }
  get(...args)  { return this._raw.get(args.flat()) }
  all(...args)  { return this._raw.all(args.flat()) }
  run(...args)  {
    this._raw.run(args.flat())
    const rowid = this._db.get('SELECT last_insert_rowid() as id').id
    return { lastInsertRowid: rowid }
  }
}

class DB {
  constructor(path) {
    this._db = new SqliteDB(path)
    this._db.run('PRAGMA journal_mode = WAL')
    this._db.run('PRAGMA foreign_keys = ON')
  }
  prepare(sql) { return new Statement(this._db.prepare(sql), this) }
  exec(sql)    { this._db.exec(sql) }
  get(sql, ...args) { return this._db.get(sql, args.flat()) }
}

const db = new DB(DB_PATH)

const schema = fs.readFileSync(SCHEMA_PATH, 'utf8')
db.exec(schema)

module.exports = db
