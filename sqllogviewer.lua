local mq = require 'mq'
local imgui = require 'ImGui'
local repository = require 'repository'
local sqllogger = require 'sqllogger'

local selected_context = 0

local selected_character = 0
local selected_character_name = ""

local contexts = {}
local contextComboOptions = ""
local characters = {}
local characterComboOptions = ""

local maxdisplayrows = 20

local checkedLogLevels = {}
for _, loglevel in pairs(sqllogger.loglevels) do
  checkedLogLevels[loglevel.level] = true
end

local function updateContexts()
  local foundPreviousSelected = false
  contexts = repository.GetContexts()
  contextComboOptions = ""
  for i,name in ipairs(contexts) do
    contextComboOptions = contextComboOptions..name.."\0"
    if name == selected_character_name then
      selected_context = i-1
      foundPreviousSelected = true
    end
  end

  if not foundPreviousSelected then
    selected_context = 0
    selected_character_name = contexts[selected_context+1]
  end
end

updateContexts()

local function updateCharacters()
  local foundPreviousSelected = false
  characters = repository.GetCharacters()
  characterComboOptions = ""
  for i,name in ipairs(characters) do
    characterComboOptions = characterComboOptions..name.."\0"
    if name == selected_character_name then
      selected_character = i-1
      foundPreviousSelected = true
    end
  end

  if not foundPreviousSelected then
    selected_character = 0
    selected_character_name = characters[selected_character+1]
  end
end

updateCharacters()

local logRows = {}
local function updateLogData()
  local searchLevels = {}
  for _, loglevel in pairs(sqllogger.loglevels) do
    if checkedLogLevels[loglevel.level] then
      table.insert(searchLevels, loglevel.level)
    end
  end

  if not next(searchLevels) then
    for _, loglevel in pairs(sqllogger.loglevels) do
      table.insert(searchLevels, loglevel.level)
    end
  end

  logRows = repository.GetLatest(contexts[selected_context+1], characters[selected_character+1], table.concat(searchLevels, ","), maxdisplayrows)
end

local function GetLevelText(level)
  for _, loglevel in pairs(sqllogger.loglevels) do
    if loglevel.level == level then
      return loglevel.abbreviation
    end
  end

  return "UKNOWN"
end

local function GetLevelColor(level)
  for _, loglevel in pairs(sqllogger.loglevels) do
    if loglevel.level == level then
      return unpack(loglevel.color)
    end
  end

  return unpack({0, 1, 1, 1})
end

local openGUI = true
local shouldDrawGUI = true
local terminate = false

local ColumnID_Context = 0
local ColumnID_Character = 1
local ColumnID_Level = 2
local ColumnID_Message = 3

-- ImGui main function for rendering the UI window
local renderLogViewer = function()
  openGUI, shouldDrawGUI = imgui.Begin('Log Viewer', openGUI)
  imgui.SetWindowSize(430, 277, ImGuiCond.FirstUseEver)
  if shouldDrawGUI then

    selected_context = imgui.Combo('##Context', selected_context, contextComboOptions)
    imgui.SameLine()

    selected_character = imgui.Combo('##Character', selected_character, characterComboOptions)
    selected_character_name = characters[selected_character+1]
    imgui.SameLine()
    if imgui.Button("Delete") then
      repository.Delete(selected_character_name)
    end

    for _, loglevel in pairs(sqllogger.loglevels) do
      checkedLogLevels[loglevel.level], _ = imgui.Checkbox(loglevel.abbreviation, checkedLogLevels[loglevel.level])
      imgui.SameLine()
    end

    if imgui.BeginTable('#LogTable', 3) then
      imgui.TableSetupColumn('Context', ImGuiTableColumnFlags.WidthFixed, -1.0, ColumnID_Context)
      imgui.TableSetupColumn('Character', ImGuiTableColumnFlags.WidthFixed, -1.0, ColumnID_Character)
      imgui.TableSetupColumn('Level', ImGuiTableColumnFlags.WidthFixed, -1.0, ColumnID_Level)
      imgui.TableSetupColumn('Message', ImGuiTableColumnFlags.WidthFixed, -1.0, ColumnID_Message)
    end

    imgui.TableHeadersRow()

    for _, logRow in ipairs(logRows) do
      imgui.TableNextRow()
      imgui.TableNextColumn()
      imgui.Text(logRow.context)
      imgui.TableNextColumn()
      imgui.Text(logRow.character)
      imgui.TableNextColumn()
      imgui.PushStyleColor(ImGuiCol.Text, GetLevelColor(logRow.level))
      imgui.Text(GetLevelText(logRow.level))
      imgui.PopStyleColor(1)
      imgui.TableNextColumn()
      imgui.Text(logRow.message)
    end

    imgui.EndTable()
  end

  imgui.End()

  if not openGUI then
    terminate = true
  end
end

mq.imgui.init('logviewer', renderLogViewer)

while not terminate do
  updateContexts()
  updateCharacters()
  updateLogData()
  mq.delay(500)
end