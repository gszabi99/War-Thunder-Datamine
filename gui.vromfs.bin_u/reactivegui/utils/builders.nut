from "%rGui/globals/ui_library.nut" import *

function createScriptComponent(scriptPath, props = {}) {
  let script = load_das(scriptPath)
  return @(width, height) function() {
    props.size <- [width, height]
    props.rendObj <- ROBJ_DAS_CANVAS
    props.script <- script
    props.drawFunc <- "render"
    props.setupFunc <- "setup"

    return props
  }
}

function createScriptComponentWithPos(scriptPath, props = {}) {
  let script = load_das(scriptPath)
  return @(pos, size) function() {
    props.pos <- [pos[0], pos[1]]
    props.size <- [size[0], size[1]]
    props.rendObj <- ROBJ_DAS_CANVAS
    props.script <- script
    props.drawFunc <- "render"
    props.setupFunc <- "setup"

    return props
  }
}

return {
  createScriptComponent,
  createScriptComponentWithPos
}
