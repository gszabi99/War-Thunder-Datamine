from "%darg/ui_imports.nut" import *
local {colors} = require("style.nut")
local scrollbar = require("%darg/components/scrollbar.nut")
local textButton = require("textButton.nut")


local helpText = @"
Q - Selection mode
W - Movement mode
E - Rotation mode
R - Scaling mode
P - Toggle property pane;
Z - Zoom-and-center for selection
X - Toggle local/world gizmo behaviour
Del - Delete selected object(s)

Ctrl-A - Select all
Ctrl-D - Deselect all
Ctrl-Z - Undo
Ctrl-Y - Redo

Ctrl-Alt-D - Drop objects
Ctrl-Alt-E - Drop objects on normal
Ctrl-Alt-W - Surf mode

Camera:
Space - Toggle free camera

Middle mouse button + Move - Camera pan
Alt + Middle mouse button + Move - Camera rotation
Mouse wheel - Move forward/backward (Ctrl=turbo, Alt=finer)

F1 - this help
Alt+H - Select by name
"


local help = @(showHelp) function help(){
  local btnClose = {
    hplace = ALIGN_RIGHT
    size = SIZE_TO_CONTENT
    children = textButton("X", function() {
      showHelp.update(false)
    }, {hotkeys = [["Esc"]]})
  }

  local caption = {
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_SOLID
    color = Color(50, 50, 50, 50)

    children = [
      {
        rendObj = ROBJ_DTEXT
        text = "Keyboard help"
        margin = fsh(0.5)
      }
      btnClose
    ]
  }

  local textContent = {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = helpText
    size = [flex(), SIZE_TO_CONTENT]
    margin = fsh(0.5)
  }


  return {
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    size = [sw(50), sh(80)]
    watch = showHelp
    rendObj = ROBJ_SOLID
    color = colors.ControlBg
    behavior = Behaviors.Button

    flow = FLOW_VERTICAL

    children = [
      caption
      scrollbar.makeVertScroll(textContent)
    ]
  }
}


return help
