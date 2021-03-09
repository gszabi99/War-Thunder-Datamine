local editor = null
local editorState = null
local editorIsActive = Watched(false)
local showUIinEditor = Watched(false)
local daEditor4 = require_optional("daEditor4")
if (daEditor4 != null) {
  editor = require_optional("ui/editor/editor.nut")
  editorState = require_optional("ui/editor/state.nut")
  showUIinEditor = editorState.showUIinEditor
  editorIsActive = editorState.editorIsActive
}

return {
  editor, showUIinEditor, editorIsActive
}