local mq = require 'mq'
local packageMan = require 'mq/PackageMan'
local sqlite3 = packageMan.Require('lsqlite3')
local lfs = packageMan.Require('luafilesystem', 'lfs')

---@param filePath string
---@return boolean|nil
local function ensurePathExists(filePath)
  return lfs.rmkdir(filePath)
end

local configDir = (mq.configDir.."/"):gsub("\\", "/"):gsub("%s+", "%%20")
local serverName = mq.TLO.MacroQuest.Server()
ensurePathExists(configDir..serverName.."/data")

local dbFileName = configDir..serverName.."/data/logDB.db"
local connectingString = string.format("file:///%s?cache=shared&mode=rwc&_journal_mode=WAL", dbFileName)
local db = sqlite3.open(connectingString, sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE + sqlite3.OPEN_URI)
-- http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#sqlite3_open
-- local db = sqlite3.open('file:memlogdb?mode=memory&cache=shared', sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE + sqlite3.OPEN_URI)

-- for pragmaJournalMode in db:nrows("SELECT * FROM pragma_journal_mode()") do
--   if pragmaJournalMode.journal_mode ~= "wal" then
--     print("Journal mode is not set to WAL")
--     db:exec("PRAGMA journal_mode=WAL;")
--   end
-- end

-- http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#db_exec
-- http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki#numerical_error_and_result_codes

db:exec[[
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS log (
      id INTEGER PRIMARY KEY
      , context TEXT
      , character TEXT
      , level INTEGER
      , message TEXT
      , timestamp INTEGER
  );
]]

local function vacuumMaxRows(maxRows)
  if not maxRows or maxRows < 1 then
    return
  end

  local sql = [[
    DELETE FROM log a
      WHERE a.character = '%s' AND a.id NOT IN (
        SELECT b.id FROM log b
          WHERE b.character = '%s'
          ORDER BY b.timestamp DESC LIMIT %d
  )
  ]]

  db:exec(sql:format(mq.TLO.Me.Name(), mq.TLO.Me.Name(), maxRows-1))
end

local function delete(character)
  local sql = [[
    DELETE FROM log
      WHERE '%s' = 'All' OR character = '%s'
  ]]
  db:exec(sql:format(character, character))
end

---@return table
local function getCharacters()
  local sql = [[
    SELECT DISTINCT character FROM log 
      ORDER BY character
  ]]

  local characters = {"All"}
  for character in db:urows(sql) do table.insert(characters, character) end
  return characters
end

---@return table
local function getContexts()
  local sql = [[
    SELECT DISTINCT context FROM log 
      ORDER BY character
  ]]

  local contexts = {"All"}
  for context in db:urows(sql) do table.insert(contexts, context) end
  return contexts
end

---@return table
local function getLatest(context, character, logLevels, numRows)
  local logRows = {}
  if not character or character == "" or not logLevels or logLevels == "" then
    return logRows
  end

  local dynamicWhere = "1=1"
  if context ~= "All" then
    dynamicWhere = dynamicWhere..string.format(" AND context = '%s'", context)
  end

  if character ~= "All" then
    dynamicWhere = dynamicWhere..string.format(" AND character = '%s'", character)
  end

  local sql = [[
    SELECT * FROM log 
      WHERE %s AND level IN (%s)
      ORDER BY timestamp DESC, id DESC
      LIMIT %d
  ]]

  for logRow in db:nrows(sql:format(dynamicWhere, logLevels, numRows)) do table.insert(logRows, 1, logRow) end
  return logRows
end

---@param paramLogLevel integer
---@param logMessage string
local function insert(context, paramLogLevel, logMessage)
  vacuumMaxRows()
  local insertStatement = string.format("INSERT INTO log(context, character, level, message, timestamp) VALUES('%s', '%s', %d, '%s', %d)", context, mq.TLO.Me.Name(), paramLogLevel, logMessage, os.time())
  local retries = 0
  local result = db:exec(insertStatement)
  while result ~= 0 and retries < 20 do
    mq.delay(10)
    retries = retries + 1
    result = db:exec(insertStatement)
  end

  if result ~= 0 then
    print("Failed <"..insertStatement..">")
  end
end

local sqllogger = {
  GetCharacters = getCharacters,
  GetContexts = getContexts,
  GetLatest = getLatest,
  Insert = insert,
  Delete = delete
}

return sqllogger