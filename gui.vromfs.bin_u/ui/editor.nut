local { Watched } = require("frp")

local editor = null
local editorState = null
local editorIsActive = Watched(false)
local showUIinEditor = Watched(false)
local daEditor4 = require_optional("daEditor4")
if (daEditor4 != null) {
  editor = require_optional("%daeditor/editor.nut")
  editorState = require_optional("%daeditor/state.nut")
  showUIinEditor = editorState.showUIinEditor ?? showUIinEditor
  editorIsActive = editorState.editorIsActive ?? editorIsActive
}

return {
  editor, showUIinEditor, editorIsActive
}