from "%darg/ui_imports.nut" import *

let tooltipBox = @(content) {
  rendObj = ROBJ_BOX
  fillColor = Color(30, 30, 30, 220)
  borderColor = Color(50, 50, 50, 20)
  size = SIZE_TO_CONTENT
  borderWidth = hdpx(1)
  padding = sh(1)
  children = content
}

let tooltipGen = Watched(0)
let tooltipComp = {value = null}

function setTooltip(val){
  const id = "tooltip"
  if (val != null) {
    gui_scene.resetTimeout(0.6, function() {
      tooltipComp.value = val
      tooltipGen.modify(@(v) v+1)
    }, id)
  }
  else {
    tooltipGen.modify(@(v) v+1)
    tooltipComp.value = val
    gui_scene.clearTimer(id)
  }
}
let getTooltip = @() tooltipComp.value

let tooltipCmp = @(){
  key = "tooltip"
  pos = static [0, hdpx(38)]
  watch = tooltipGen
  behavior = Behaviors.BoundToArea
  safeAreaMargin = sh(1)
  transform = static {}
  children = type(getTooltip()) == "string"
  ? tooltipBox({
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      maxWidth = hdpx(500)
      text = getTooltip()
      color = Color(180, 180, 180, 120)
    })
  : getTooltip()
}


let cursorC = Color(255,255,255,255)

let cursor = static {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [sh(3), sh(3)]
  commands = [
    [VECTOR_WIDTH, hdpx(1)],
    [VECTOR_FILL_COLOR, cursorC],
    [VECTOR_COLOR, Color(20, 40, 70, 250)],
    [VECTOR_POLY, 0,0, 100,50, 56,56, 50,100],
  ]
  transform = {
    pivot = [0, 0]
    rotate = 29
  }
}

function mkCursor(...){
  return Cursor({
    size = static [sh(2), sh(2)]
    hotspot = static [0, 0]
    children = vargv
    transform = static {
      pivot = [0, 0]
    }
  })
}

return freeze({
  getTooltip,
  setTooltip,
  tooltipCmp,
  cursor,
  mkCursor,
  normal = mkCursor(cursor, tooltipCmp),
})
