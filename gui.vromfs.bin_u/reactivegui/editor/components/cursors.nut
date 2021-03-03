local tooltipBox = @(content) {
  rendObj = ROBJ_BOX
  fillColor = Color(30, 30, 30, 160)
  borderColor = Color(50, 50, 50, 20)
  size = SIZE_TO_CONTENT
  borderWidth = hdpx(1)
  padding = sh(1)
  children = content
}

local tooltipGen = Watched(0)
local tooltipComp = {value = null}
local function setTooltip(val){
  tooltipComp.value = val
  tooltipGen(tooltipGen.value+1)
}
local getTooltip = @() tooltipComp.value

local colorBack = Color(0,0,0,120)

local tooltipCmp = @(){
  key = "tooltip"
  pos = [0, hdpx(38)]
  watch = tooltipGen
  behavior = Behaviors.BoundToArea
  transform = {}
  children = ::type(getTooltip()) == "string"
  ? tooltipBox({
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      maxWidth = hdpx(500)
      text = getTooltip()
      color = Color(180, 180, 180, 120)
    })
  : getTooltip()
}

local cursors = {getTooltip, setTooltip, tooltipCmp, tooltip = {}}

local cursorC = Color(255,255,255,255)

local cursorPc = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [sh(2), sh(2)]
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
local function mkPcCursor(children){
  return {
    size = [sh(2), sh(2)]
    hotspot = [0, 0]
    children = [cursorPc].extend(children)
    transform = {
      pivot = [0, 0]
    }
  }
}

cursors.normal <- ::Cursor(@() mkPcCursor([tooltipCmp]))

local helpSign = {rendObj = ROBJ_STEXT text = "?" fontSize = ::hdpx(20) vplace = ALIGN_CENTER fontFx = FFT_GLOW fontFxFactor=48 fontFxColor = colorBack, pos = [::hdpx(25), ::hdpx(10)]}

cursors.help <- ::Cursor(function(){
  return mkPcCursor([
    helpSign,
    tooltipCmp
  ])
})

local getEvenIntegerHdpx = @(px) ::hdpx(0.5 * px).tointeger() * 2
local cursorSzResizeDiag = getEvenIntegerHdpx(18)

local function mkResizeC(commands, angle=0){
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [cursorSzResizeDiag, cursorSzResizeDiag]
    commands = [
      [VECTOR_WIDTH, hdpx(1)],
      [VECTOR_FILL_COLOR, cursorC],
      [VECTOR_COLOR, Color(20, 40, 70, 250)],
      [VECTOR_POLY].extend(commands.map(@(v) v.tofloat()*100/7.0))
    ]
    hotspot = [cursorSzResizeDiag / 2, cursorSzResizeDiag / 2]
    transform = {rotate=angle}
  }
}
local horArrow = [0,3, 2,0, 2,2, 5,2, 5,0, 7,3, 5,6, 5,4, 2,4, 2,6]
cursors.sizeH <- ::Cursor(mkResizeC(horArrow))
cursors.sizeV <- ::Cursor(mkResizeC(horArrow, 90))
cursors.sizeDiagLtRb <- ::Cursor(mkResizeC(horArrow, 45))
cursors.sizeDiagRtLb <- ::Cursor(mkResizeC(horArrow, 135))

cursors.moveResizeCursors <- {
  [MR_LT] = cursors.sizeDiagLtRb,
  [MR_RB] = cursors.sizeDiagLtRb,
  [MR_LB] = cursors.sizeDiagRtLb,
  [MR_RT] = cursors.sizeDiagRtLb,
  [MR_T]  = cursors.sizeV,
  [MR_B]  = cursors.sizeV,
  [MR_L]  = cursors.sizeH,
  [MR_R]  = cursors.sizeH,
}

return cursors
