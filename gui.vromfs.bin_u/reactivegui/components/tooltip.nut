from "%rGui/globals/ui_library.nut" import *
let { logerr } = require("dagor.debug")
let fontsState = require("%rGui/style/fontsState.nut")
let { bw, bh } = require("%rGui/style/screenState.nut")

let state = Watched(null)
local curContent = null

let TOOLTIP_PARAMS = {
  key = null
  flow = FLOW_VERTICAL 
  flowOffset = hdpx(20) 
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  content = null
  bgOvr = null
}

let tooltipBg = {
  rendObj = ROBJ_BOX
  fillColor = 0xFF2D343C
  borderColor = 0xFF3A434E
  borderWidth = hdpxi(1)
  padding = hdpx(10)
}

let mkTooltipText = @(text, ovr = {}) {
  maxWidth = hdpx(800)
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  font = fontsState.get("small")
  color = 0xFFC0C0C0
  text
}.__update(ovr)

function calcPosition(rectOrPos, flow, flowOffset, halign, valign) {
  let isArray = type(rectOrPos) == "array"
  assert(isArray || (("l" in rectOrPos) && ("b" in rectOrPos)))
  let res = {
    pos = isArray ? rectOrPos : [rectOrPos.l, rectOrPos.t]
    halign = halign == ALIGN_CENTER ? ALIGN_CENTER
      : halign == ALIGN_LEFT ? ALIGN_RIGHT 
      : ALIGN_LEFT
    valign = valign == ALIGN_CENTER ? ALIGN_CENTER
      : valign == ALIGN_TOP ? ALIGN_BOTTOM 
      : ALIGN_TOP
  }

  let size = isArray ? [0, 0] : [rectOrPos.r - rectOrPos.l, rectOrPos.b - rectOrPos.t]

  if (flow == FLOW_VERTICAL) {
    if (res.valign == ALIGN_CENTER)
      res.valign = (2.0 * res.pos[1] > sh(100) - res.pos[1] - size[1]) ? ALIGN_BOTTOM : ALIGN_TOP
    res.pos[1] += res.valign == ALIGN_BOTTOM ? -flowOffset : flowOffset + size[1]

    res.pos[0] += res.halign == ALIGN_CENTER ? size[0] / 2
      : res.halign == ALIGN_RIGHT ? size[0]
      : 0
  }
  else {
    if (res.halign == ALIGN_CENTER)
      res.halign = (res.pos[0] > sw(100) - res.pos[0] - size[0]) ? ALIGN_RIGHT : ALIGN_LEFT
    res.pos[0] += res.halign == ALIGN_RIGHT ? -flowOffset : flowOffset + size[0]

    res.pos[1] += res.valign == ALIGN_CENTER ? size[1] / 2
      : res.valign == ALIGN_BOTTOM ? size[1]
      : 0
  }

  return res
}

function hideTooltip(key = null) {
  if (key != null && state.get()?.key != key)
    return
  state.set(null)
  curContent = null
}

function showTooltip(rectOrPos, params) {
  if (params == null) {
    hideTooltip()
    return
  }
  let content = type(params) == "string" ? params : params?.content
  if (content == null || content == "") {
    logerr("try to show tooltip with empty content")
    hideTooltip()
    return
  }

  let newState = TOOLTIP_PARAMS.__merge(type(params) == "string" ? { content } : params)
  if (type(content) != "string") {
    curContent = content
    newState.content = null
  }

  let { flow, flowOffset, halign, valign } = newState
  newState.position <- calcPosition(rectOrPos, flow, flowOffset, halign, valign)
  state.set(newState)
}

let withTooltipImpl = @(stateFlags, key, showFunc, hideFunc = hideTooltip) function(sf) {
  let hasHint = (stateFlags.get() & S_HOVER) != 0
  let needHint = (sf & S_HOVER) != 0
  stateFlags.set(sf)
  if (hasHint == needHint)
    return
  if (needHint)
    showFunc()
  else
    hideFunc(key)
}

let tooltipDetach = @(stateFlags, key) @() (stateFlags.get() & S_HOVER) != 0 ? hideTooltip(key) : null

let withTooltip = @(stateFlags, key, tooltipCtor)
  withTooltipImpl(stateFlags, key, @() showTooltip(gui_scene.getCompAABBbyKey(key), tooltipCtor()))

function tooltipComp() {
  if (state.get() == null)
    return { watch = state }

  let { position, content, bgOvr } = state.get()
  let { halign, valign } = position

  let visibleChild = tooltipBg.__merge(
    bgOvr ?? {},
    {
      key = state.get()
      children = curContent ?? mkTooltipText(content)
    })

  return position.__merge({
    watch = [state, bw, bh]
    size = 0
    halign
    valign
    children = {
      size = SIZE_TO_CONTENT
      transform = {}
      safeAreaMargin = [bh.get(), bw.get()]
      behavior = Behaviors.BoundToArea
      children = visibleChild
    }
  })
}

return {
  tooltipComp
  withTooltip
  tooltipDetach
}