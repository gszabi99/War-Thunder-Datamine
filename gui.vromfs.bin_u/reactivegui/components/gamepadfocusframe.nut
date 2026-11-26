

from "%rGui/globals/ui_library.nut" import *
from "dagor.time" import get_time_msec
from "math" import abs
from "%sqstd/math.nut" import lerp
from "%rGui/dagui/units.nut" import cssConst, roundPx
from "%rGui/components/commonBg.nut" import commonBg
import "%rGui/style/cssColor.nut" as cssColor

const ANIM_MSEC = 200
const MIN_MOVE_PX = 10
const START_OPACITY = 30.0 / 255

let offsetMin = cssConst("focusFrameAnimOffsetMin")
let offsetMax = cssConst("focusFrameAnimOffsetMax")

let animState = Watched(null)
local lastBox = null
local layerPos = null

function animOffset(prev, box) {
  if (prev == null)
    return offsetMax
  let minDist = 0.2 * sh(100)
  let dist = clamp(max(abs(prev[0] - box[0]), abs(prev[1] - box[1])), minDist, sh(100))
  return lerp(minDist, sh(100), offsetMin, offsetMax, dist)
}

function playFocusAnim(elem, layers, target) {
  let box = [elem.getScreenPosX(), elem.getScreenPosY(), elem.getWidth(), elem.getHeight()]
  let prev = lastBox
  if (layerPos == null || (prev != null && box.findindex(@(v, i) abs(v - prev[i]) > MIN_MOVE_PX) == null)) {
    target.hideUntil = 0
    return
  }
  lastBox = box
  animState.set({ box, layers, target, offset = animOffset(prev, box) })
}


function mkFocusFrame(position = "8, 10, 8, 8") {
  let layers = commonBg({ image = "#ui/gameuiskin#item_selection", repeat = "expand", position,
    bgcolor = cssColor("gamepadFocusFrameColor") })
  let target = { hideUntil = null }
  return {
    size = flex()
    children = layers
    opacity = 0.0
    behavior = Behaviors.RtPropUpdate
    update = @() { opacity = target.hideUntil != null && get_time_msec() >= target.hideUntil ? 1.0 : 0.0 }
    onAttach = @(elem) playFocusAnim(elem, layers, target)
    function onDetach() {
      target.hideUntil = null
      
      if (animState.get()?.target == target)
        animState.set(null)
    }
  }
}

function animProps(anim, sizeT, alphaT) {
  let { box, offset } = anim
  let [x, y, w, h] = box
  let grow = offset * (1.0 - sizeT * sizeT)
  let size = [(w + 2 * grow).tointeger(), (h + 2 * grow).tointeger()]
  return {
    size
    pos = [x - layerPos[0] + roundPx((w - size[0]) / 2.0), y - layerPos[1] + roundPx((h - size[1]) / 2.0)]
    opacity = alphaT == null ? 0.0 : START_OPACITY + (1.0 - START_OPACITY) * (1.0 - (1.0 - alphaT) * (1.0 - alphaT))
  }
}

let animTime = @(start, now) start == null ? 0.0 : min((now - start).tofloat() / ANIM_MSEC, 1.0)


function mkAnimFrame(anim) {
  let state = { firstFrame = null, sizeStart = null, alphaStart = null, isDone = false }
  function update() {
    if (state.isDone)
      return null
    let now = get_time_msec()
    let frame = gui_scene.updateCounter.get()
    if (state.firstFrame == null) {
      state.firstFrame = frame
      anim.target.hideUntil = now + ANIM_MSEC
    }
    if (frame - state.firstFrame >= 1)
      state.sizeStart = state.sizeStart ?? now
    if (frame - state.firstFrame >= 2)
      state.alphaStart = state.alphaStart ?? now
    if (state.sizeStart == null)
      return null
    let sizeT = animTime(state.sizeStart, now)
    state.isDone = sizeT >= 1.0
    return animProps(anim, sizeT, state.isDone ? null : animTime(state.alphaStart, now))
  }
  return {
    children = anim.layers
    behavior = Behaviors.RtPropUpdate
    rtRecalcLayout = true
    update
  }.__update(animProps(anim, 0.0, null))
}

let focusFrameAnimLayer = @() {
  watch = animState
  size = flex()
  
  zOrder = Layers.Tooltip
  function onAttach(elem) {
    layerPos = [elem.getScreenPosX(), elem.getScreenPosY()]
  }
  function onDetach() {
    animState.set(null)
    lastBox = null
    layerPos = null
  }
  children = animState.get() == null ? null : mkAnimFrame(animState.get())
}

return freeze({ mkFocusFrame, focusFrameAnimLayer })
