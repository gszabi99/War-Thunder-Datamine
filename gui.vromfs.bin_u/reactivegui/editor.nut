local editor = null
local editorState = null
local editorIsActive = Watched(false)
local daEditor4 = require_optional("daEditor4")
if (daEditor4 != null) {
  editor = require_optional("reactiveGui/editor/editor.nut")
  editorState = require_optional("reactiveGui/editor/state.nut")
  editorState.extraPropPanelCtors.update(@(v) v.append(require("editorCustomView.nut")))
  editorIsActive = editorState.editorIsActive
}

return {
  editor, editorIsActive
}