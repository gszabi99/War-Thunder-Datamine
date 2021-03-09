// Put to global namespace for compatibility
::getroottable().__update(require("daRg"))
require("daRg/library.nut")
require("reactiveGui/library.nut")
local {editor, editorIsActive} = require("editor.nut")

local function root() {
  local children = []

  if (editorIsActive.value)
    children = [editor]

  return {
    watch = [editorIsActive]
    size = flex()
    children
  }
}

return root
