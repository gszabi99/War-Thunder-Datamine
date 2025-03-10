from "%globalScripts/ui_globals.nut" import *

from "daRg" import flex
from "ecs" import clear_vm_entity_systems

clear_vm_entity_systems()

local editorIsActive

if (require_optional("daEditorEmbedded") != null) {
  editorIsActive = require_optional("%daeditor/state.nut").editorIsActive
}

let editor = editorIsActive != null ? require_optional("%daeditor/editor.nut") : null

function root() {
  return editorIsActive != null ? {
    watch = editorIsActive
    size = flex()
    children = editorIsActive.value ? editor : null
  } : {watch = editorIsActive}
}

return root
