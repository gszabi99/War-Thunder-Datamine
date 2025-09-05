from "%rGui/globals/ui_library.nut" import *
let { addModalWindow, removeModalWindow } = require("%rGui/components/modalWindowsMngr.nut")
let JB = require("%rGui/control/gui_buttons.nut")
let { safeAreaSizeMenu } = require("%rGui/style/screenState.nut")

let POPUP_PARAMS = {
  uid = null 
  popupFlow = FLOW_VERTICAL 
  popupOffset = 0 
  popupHalign = ALIGN_CENTER
  popupValign = ALIGN_CENTER
  rendObj = ROBJ_BOX
  fillColor = 0xF211141A
  borderWidth = hdpx(1)
  borderColor = 0xB220262C
  stopMouse = true
  children = null
  hotkeys = null
  popupBg = {}
}

let remove = @(uid) removeModalWindow(uid)

function calcOffsets(rectOrPos, popupFlow, popupOffset, popupHalign, popupValign) {
  let isArray = type(rectOrPos) == "array"
  assert(isArray || (("l" in rectOrPos) && ("b" in rectOrPos)))
  let res = {
    pos = isArray ? rectOrPos : [rectOrPos.l, rectOrPos.t]
    halign = popupHalign
    valign = popupValign
  }

  let size = isArray ? [0, 0] : [rectOrPos.r - rectOrPos.l, rectOrPos.b - rectOrPos.t]

  if (popupFlow == FLOW_VERTICAL) {
    if (res.valign == ALIGN_CENTER)
      res.valign = (res.pos[1] > sh(100) - res.pos[1] - size[1]) ? ALIGN_BOTTOM : ALIGN_TOP
    res.pos[1] += res.valign == ALIGN_BOTTOM ? -popupOffset : popupOffset + size[1]

    res.pos[0] += res.halign == ALIGN_CENTER ? size[0] / 2
      : res.halign == ALIGN_RIGHT ? size[0]
      : 0
  }
  else {
    if (res.halign == ALIGN_CENTER)
      res.halign = (res.pos[0] > sw(100) - res.pos[0] - size[0]) ? ALIGN_RIGHT : ALIGN_LEFT
    res.pos[0] += res.halign == ALIGN_RIGHT ? -popupOffset : popupOffset + size[0]

    res.pos[1] += res.valign == ALIGN_CENTER ? size[1] / 2
      : res.valign == ALIGN_BOTTOM ? size[1]
      : 0
  }

  return res
}

local lastPopupIdx = 0
function add(rectOrPos, popup, safeAreaSizeWatch = safeAreaSizeMenu) {
  popup = POPUP_PARAMS.__merge(popup)
  popup.uid = popup?.uid ?? $"modal_popup_{lastPopupIdx++}"
  popup.hotkeys = popup.hotkeys ?? [[JB.B, { action = @() remove(popup.uid) }]]

  let offsets = calcOffsets(rectOrPos, popup.popupFlow, popup.popupOffset, popup.popupHalign, popup.popupValign)
  addModalWindow(popup.popupBg.__merge({
    key = popup.uid
    children = {
      size = 0
      pos = offsets.pos
      halign = offsets.halign
      valign = offsets.valign

      children = @() {
        watch = safeAreaSizeWatch
        size = SIZE_TO_CONTENT
        safeAreaMargin = safeAreaSizeWatch.get().borders
        behavior = Behaviors.BoundToArea
        children = @() popup
      }
    }
  }))
  return popup.uid
}

return {
  add
  remove
  POPUP_PARAMS
}