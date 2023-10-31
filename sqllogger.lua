local repository = require 'repository'

-- This module provides a set of sql logging utilities with support for different log levels.
local sqlLogger = { _version = '1.0', _author = 'PeonMQ' }

sqlLogger.loglevel = 'info'

-- Sets a context for log messages.  This appears at the very beginning of the line and can be a string or a function that returns a string
sqlLogger.context = ''

-- see MQ2ImGuiConsole.cpp linenumber 174 for colors
local initial_loglevels = {
  ['trace']  = { level = 1, color = {0,   1, 1, 1}, abbreviation = '[TRACE]', terminate = false },
  ['debug']  = { level = 2, color = {1,   0, 1, 1}, abbreviation = '[DEBUG]', terminate = false },
  ['info']   = { level = 3, color = {0,   0, 1, 1}, abbreviation = '[INFO]' , terminate = false },
  ['warn']   = { level = 4, color = {1,   1, 0, 1}, abbreviation = '[WARN]' , terminate = false },
  ['error']  = { level = 5, color = {1, 0.6, 0, 1}, abbreviation = '[ERROR]', terminate = false },
  ['fatal']  = { level = 6, color = {1,   0, 0, 1}, abbreviation = '[FATAL]', terminate = true  },
  ['help']   = { level = 7, color = {1,   1, 1, 1}, abbreviation = '[HELP]' , terminate = false },
}

-- Handle add/remove for log levels
local loglevels_mt = {
  __newindex = function(t, key, value)
    rawset(t, key, value)
    sqlLogger.GenerateShortcuts()
  end,
  __call = function(t, key)
    rawset(t, key, nil)
    sqlLogger.GenerateShortcuts()
  end,
}

sqlLogger.loglevels = setmetatable(initial_loglevels, loglevels_mt)

local mq = nil
if package.loaded['mq'] then
  mq = require('mq')
end

--- Terminates the program, using mq or os exit as appropriate
local function terminate()
  if mq then mq.exit() end
  os.exit()
end

--- Outputs a message at the specified log level, with colors and prefixes/postfixes if specified.
--- @param paramLogLevel string The log level for output
--- @param message string The message to output
local function Output(paramLogLevel, message)
  if rawget(sqlLogger.loglevels, paramLogLevel) == nil then
    if rawget(sqlLogger.loglevels, 'fatal') == nil then
      print(string.format("Write Error: Log level '%s' does not exist.", paramLogLevel))
      terminate()
    else
      print(string.format("Log level '%s' does not exist.", paramLogLevel))
    end
  elseif sqlLogger.loglevels[sqlLogger.loglevel:lower()].level <= sqlLogger.loglevels[paramLogLevel].level then
    repository.Insert((type(sqlLogger.context) == 'function' and sqlLogger.context() or sqlLogger.context), sqlLogger.loglevels[paramLogLevel].level, message)
  end
end

--- Generates shortcut functions for each log level defined in Write.loglevels.
--- The generated functions have the same name as the log level with the first letter capitalized.
--- For example, if there is a log level 'info', a function Write.Info() will be generated.
--- The functions output messages at their respective log levels, and a fatal log level message will terminate the program.
function sqlLogger.GenerateShortcuts()
  for level, level_params in pairs(sqlLogger.loglevels) do
      --- @diagnostic disable-next-line
    Write[GetSentenceCase(level)] = function(message, ...)
      Output(level, string.format(message, ...))
      if level_params.terminate then
        terminate()
      end
    end
  end
end

sqlLogger.GenerateShortcuts()

return sqlLogger