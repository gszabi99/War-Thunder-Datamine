// Put to global namespace for compatibility
from "daRg" import flex
from "ecs" import clear_vm_entity_systems

clear_vm_entity_systems()

local editorIsActive

if (require_optional("daEditor4") != null) {
  editorIsActive = require_optional("%daeditor/state.nut").editorIsActive
}

local editor = editorIsActive != null ? require_optional("%daeditor/editor.nut") : null

local function root() {
  return editorIsActive != null ? {
    watch = editorIsActive
    size = flex()
    children = editorIsActive.value ? editor : null
  } : {watch = editorIsActive}
}

return root
