local frp = require("frp")

::Watched <- frp.Watched
::Computed <- frp.Computed


//This is list of all darg native functions and consts, to use in mockups
::Color <- function Color(r,g,b,a=255) {
  return (a << 24) + (r << 16) + (g << 8) + b;
}


::Fonts <-{}
::calc_comp_size <- @(comp) [0,0]
::gui_scene <-{
  setShutdownHandler = @(val) null
  circleButtonAsAction = false
  config = {
    defaultFont = 0
    joystickScrollCursor = null
    kbCursorControl = false
    gamepadCursorSpeed = 1.0
    defSceneBgColor =Color(10,10,10,160)
    setClickButtons = @(list) null
    gamepadCursorControl = true
    reportNestedWatchedUpdate = false
    gamepadCursorDeadZone = 0.05
    gamepadCursorNonLin = 1.5
    gamepadCursorHoverMinMul = 0.005
    gamepadCursorHoverMaxMul = 0.1
    gamepadCursorHoverMaxTime = 0.5
    gamepadCursorAxisH = 0
    gamepadCursorAxisV = 1
    clickRumbleEnabled = true
    clickRumbleLoFreq = 0.6
    clickRumbleHiFreq = 0
    clickRumbleDuration = 0.04
    dirPadRepeatDelay = 0.6
    dirPadRepeatTime = 0.2
  }
  cursorOverScroll = ::Watched(true)
  cursorOverClickable = ::Watched(true)
  cursorPresent = ::Watched(true)
  setHotkeysNavHandler = function(func){assert(::type(func)=="function")}
  setUpdateHandler = function(dt) {}
  setInterval = function(timeout, func){
    assert([type(0),type(0.0)].indexof(type(timeout))!=null, "timeout should number")
    assert(type(func)==type(type), "function should be function")
    func()
  }
  setTimeout = function(timeout, func){
    assert([type(0),type(0.0)].indexof(type(timeout))!=null, "timeout should number")
    assert(type(func)==type(type), "function should be function")
    func()
  }
  clearTimer = function(func){
    assert(type(func)==type(type), "function should be function")
  }
}
::ScrollHandler <- class{}
::ElemGroup <- @() {}
global enum AnimProp{
  color
  bgColor
  fgColor
  fillColor
  borderColor
  opacity
  rotate
  scale
  translate
  fValue
}

::anim_start<-@(anim) null
::anim_request_stop<-@(anim) null

::vlog <- function vlog(val) {
  print("".concat(val,"\n"))
}

::logerr <- function logerr(val) {
  print("".concat(val,"\n"))
}

::debug <- function debug(val) {
  print("".concat(val,"\n"))
}

::fontH <- function fontH(height) {
  return height
}

::flex <- function flex(weight=1) {
  return weight*100
}

::sw <- function sw(val) {
  return val*1920
}

::sh <- function sh(val) {
  return val*1080
}

::pw <- function pw(val) {
  return val*100
}

::ph <- function ph(val) {
  return val*100
}

::elemw <- function elemw(val) {
  return val*100
}

::elemh <- function elemh(val) {
  return val*100
}

::Behaviors <- {
  Button = "Button"
  TextArea="TextArea"
  MoveResize = "MoveResize"
  Marquee = "Marquee"
  BoundToArea = "BoundToArea"
  RecalcHandler = "RecalcHandler"
  DragAndDrop = "DragAndDrop"
  RtPropUpdate = "RtPropUpdate"
  Pannable = "Pannable"
  Pannable2touch = "Pannable2touch"
}

::Picture <- function Picture(val){return val}
::Cursor <- function Cursor(val) {return val}

::XmbNode <- function XmbNode(...) {return {}}

global enum Layers {
  Default
  Upper
  ComboPopup
  MsgBox
  Tooltip
  Inspector
}

global const ROBJ_IMAGE = "ROBJ_IMAGE"
global const ROBJ_STEXT = "ROBJ_STEXT"
global const ROBJ_DTEXT = "ROBJ_DTEXT"
global const ROBJ_TEXTAREA = "ROBJ_TEXTAREA"
global const ROBJ_9RECT = "ROBJ_9RECT"
global const ROBJ_BOX = "ROBJ_BOX"
global const ROBJ_SOLID = "ROBJ_SOLID"
global const ROBJ_FRAME = "ROBJ_FRAME"
global const ROBJ_PROGRESS_CIRCULAR = "ROBJ_PROGRESS_CIRCULAR"
global const ROBJ_WORLD_BLUR = "ROBJ_WORLD_BLUR"
global const ROBJ_WORLD_BLUR_PANEL = "ROBJ_WORLD_BLUR_PANEL"
global const ROBJ_VECTOR_CANVAS = "ROBJ_VECTOR_CANVAS"
global const VECTOR_POLY = "VECTOR_POLY"
global const ROBJ_MASK = "ROBJ_MASK"
global const ROBJ_PROGRESS_LINEAR = "ROBJ_PROGRESS_LINEAR"

global const FLOW_PARENT_RELATIVE = "PARENT_RELATIVE"
global const FLOW_HORIZONTAL = "FLOW_HORIZONTAL"
global const FLOW_VERTICAL = "FLOW_VERTICAL"

global const ALIGN_LEFT = "ALIGN_LEFT_OR_TOP"
global const ALIGN_CENTER ="ALIGN_CENTER"
global const ALIGN_RIGHT="ALIGN_RIGHT_OR_BOTTOM"
global const ALIGN_TOP="ALIGN_LEFT_OR_TOP"
global const ALIGN_BOTTOM="ALIGN_RIGHT_OR_BOTTOM"

global const DIR_UP = "DIR_UP"
global const DIR_DOWN = "DIR_DOWN"
global const DIR_LEFT = "DIR_LEFT"
global const DIR_RIGHT = "DIR_RIGHT"

global const KEEP_ASPECT_FILL = "KEEP_ASPECT_FILL"
global const KEEP_ASPECT_NONE = false
global const KEEP_ASPECT_FIT  = true

global const VECTOR_WIDTH="VECTOR_WIDTH"
global const VECTOR_COLOR="VECTOR_COLOR"
global const VECTOR_FILL_COLOR="VECTOR_FILL_COLOR"
global const VECTOR_LINE="VECTOR_LINE"
global const VECTOR_ELLIPSE="VECTOR_ELLIPSE"
global const VECTOR_RECTANGLE="VECTOR_RECTANGLE"
global const VECTOR_MID_COLOR = "VECTOR_MID_COLOR"
global const VECTOR_OUTER_LINE="VECTOR_OUTER_LINE"
global const VECTOR_CENTER_LINE="VECTOR_CENTER_LINE"
global const VECTOR_LINE_INDENT_PCT="VECTOR_LINE_INDENT_PCT"
global const VECTOR_LINE_INDENT_PX="VECTOR_LINE_INDENT_PX"
global const VECTOR_LINE_DASHED = "VECTOR_LINE_DASHED"
global const VECTOR_SECTOR="VECTOR_SECTOR"
global const VECTOR_INVERSE_POLY="VECTOR_INVERSE_POLY"

global const FFT_NONE="FFT_NONE"
global const FFT_SHADOW="FFT_SHADOW"
global const FFT_GLOW="FFT_GLOW"
global const FFT_BLUR="FFT_BLUR"
global const FFT_OUTLINE="FFT_OUTLINE"

global const O_HORIZONTAL="O_HORIZONTAL"
global const O_VERTICAL="O_VERTICAL"

global const TOVERFLOW_CLIP="TOVERFLOW_CLIP"
global const TOVERFLOW_CHAR="TOVERFLOW_CHAR"
global const TOVERFLOW_WORD="TOVERFLOW_WORD"
global const TOVERFLOW_LINE="TOVERFLOW_LINE"
global const EVENT_BREAK = "EVENT_BREAK"
global const EVENT_CONTINUE= "EVENT_CONTINUE"
global const HOOK_ATTACH = "HOOK_ATTACH"





global const Linear = "Linear"

global const InQuad = "InQuad"
global const OutQuad = "OutQuad"
global const InOutQuad = "InOutQuad"

global const InCubic = "InCubic"
global const OutCubic = "OutCubic"
global const InOutCubic = "InOutCubic"

global const InQuintic = "InQuintic"
global const OutQuintic = "OutQuintic"
global const InOutQuintic = "InOutQuintic"

global const InQuart = "InQuart"
global const OutQuart = "OutQuart"
global const InOutQuart = "InOutQuart"

global const InSine = "InSine"
global const OutSine = "OutSine"
global const InOutSine = "InOutSine"

global const InCirc = "InCirc"
global const OutCirc = "OutCirc"
global const InOutCirc = "InOutCirc"

global const InExp = "InExp"
global const OutExp = "OutExp"
global const InOutExp = "InOutExp"

global const InElastic = "InElastic"
global const OutElastic = "OutElastic"
global const InOutElastic = "InOutElastic"

global const InBack = "InBack"
global const OutBack = "OutBack"
global const InOutBack = "InOutBack"

global const InBounce = "InBounce"
global const OutBounce = "OutBounce"
global const InOutBounce = "InOutBounce"

global const InOutBezier = "InOutBezier"
global const CosineFull = "CosineFull"

global const InStep = "InStep"
global const OutStep = "OutStep"

global const Blink = "Blink"
global const DoubleBlink = "DoubleBlink"
global const BlinkSin = "BlinkSin"
global const BlinkCos = "BlinkCos"

global const Discrete8 = "Discrete8"

global const Shake4 = "Shake4"
global const Shake6 = "Shake6"



global const S_KB_FOCUS=0
global const S_HOVER=1
global const S_TOP_HOVER=2
global const S_ACTIVE=3
global const S_DRAG=4

global const MR_NONE="MR_NONE"
global const MR_T="MR_T"
global const MR_R="MR_R"
global const MR_B="MR_B"
global const MR_L="MR_L"
global const MR_LT="MR_LT"
global const MR_RT="MR_RT"
global const MR_LB="MR_LB"
global const MR_RB="MR_RB"
global const MR_AREA="MR_AREA"
global const SIZE_TO_CONTENT="SIZE_TO_CONTENT"
global const DEVID_MOUSE = 1

global const FMT_NO_WRAP = 0x01
global const FMT_KEEP_SPACES = 0x02
global const FMT_IGNORE_TAGS = 0x04
global const FMT_HIDE_ELLIPSIS = 0x08
global const FMT_AS_IS = 0xFF
