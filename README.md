# SQL Logger for EQ 

LUA script that hadnles logging to a sqllite database

## Requirements

- MQ
- MQ2Lua
- lsqlite3
- luafilesystem

## Installation
Download the latest `sqllogger.zip` from the latest [release](https://github.com/peonMQ/sqllogger/releases) and unzip the contents to its own directory inside `lua` folder of your MQ directory. 

ie `lua\sqllogger`

## Usage
At the top of your startup script, add the following code`
```lua
local packageMan = require 'mq/PackageMan'
local sqlite3 = packageMan.Install('lsqlite3')
local lfs = packageMan.Install('luafilesystem')
```

Include the script where you want logging and start logging
```lua
-- Require the library
local logger = require sqllogger/sqllogger
-- Log an informational message
logger.Info('Hello World!')
```

Lastly, sqllogger handles string formatting for you, so you can use it just like you would string.format:
```lua
local logger = require('sqllogger/sqllogger')
Write.prefix = 'MyScript'
logger.Info('This is script (%s) which is written by %s', 'sqllogger', 'APerson')
```


### Default logging levels

`logger.Trace` - Useful for stepping through each bit of code and almost never shown to the end-user.

`logger.Debug` - Debug messages.  Often items that you might have an end-user turn on to help with debugging.

`logger.Info` - Standard level of messages.  Normal output.

`logger.Warn` - Warning messages.  Something might be wrong.

`logger.Error` - Error messages.  Something is wrong.

`logger.Fatal` - Fatal error messages, execution will stop after this message is displayed.

`logger.Help` - Help messages.  Usually usage instructions.


### Write Configuration Options

`logger.context` - `string` - The log context ie the name of your script.  Default is empty string.

#### Loglevel Configuration Options

Loglevels themselves can be configured as well.  The properties for these are `logger.loglevels['loglevel'].<property>`  For example, to set the MQ color of trace, you can do: `logger.loglevels['trace'].mqcolor = '\at'`

Properties are:

`level` - `number` - Used for ordering which log levels are "above" or "below" others.

`color` - `table` - The color in a table version of ARGB ie {A, R, G, B}

`abbreviation` - `string` - How a particular log level will be abbreviated

`terminate` - `boolean` - Whether to call the Terminate() (end program) function when this log level is hit



#### Adding or removing log levels

An example of adding and removing a custom log level is below.  Note that the loglevels only support lower case and handle changing to sentence case for calls on their own.

Example:

```lua
    -- Add the log level (note custom vs Custom)
    logger.loglevels.custom = {
        level = 8,
        color = {1, 0.5, 0.5, 0.5},
        abbreviation = '[CUSTOM]',
        terminate = false
    }

    -- Logs at the log level (note Custom vs custom)
    logger.Custom('Test')
    -- Remove the log level
    logger.loglevels.custom = nil
    -- This should show an error message and stop execution
    logger.Custom('Test2')
```

Setting one of the default log levels to nil will also remove it.

### Log Viewer
To view sql logging start the sql log viewer
```bash
/lua run sqllogger/sqllogviewer
```