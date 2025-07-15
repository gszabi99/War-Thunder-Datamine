from "%rGui/globals/ui_library.nut" import *
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

function createScriptComponent(scriptPath, props = {}) {
  return @(width, height) {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath(scriptPath)
    drawFunc = "render"
    setupFunc = "setup"
  }.__update(props)
}

function createScriptComponentWithPos(scriptPath, props = {}) {
  return @(pos, size) {
    pos = [pos[0], pos[1]]
    size = [size[0], size[1]]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath(scriptPath)
    drawFunc = "render"
    setupFunc = "setup"
  }.__update(props)
}

return {
  createScriptComponent,
  createScriptComponentWithPos
}
