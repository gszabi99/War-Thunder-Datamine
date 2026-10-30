



import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/style/cssColor.nut" as cssColor
from "sound_wt" import playSound
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px

let boxSize = [hdpx(20), hdpx(20)]
const checkboxGap = hdpx(5)
const checkboxPadding = hdpx(2)

let formBoxSize = cssConst("checkboxImgSize")
let formRowH = px("30@sf/@pf")
let formBoxMargin = [0, (formRowH - formBoxSize) / 2]
let formGap = px("4@sf/@pf")
let formBorder = cssConst("dp")
let formDisabledCheckColor = cssColor("checkboxCheckDisabledColor")

let checkboxBoxColor = {
  active = {
    fillColor =   cssColor("checkboxPushedBgColor")
    borderColor = cssColor("checkboxPushedBorderColor")
  }
  hover = {
    fillColor =   cssColor("checkboxHoveredBgColor")
    borderColor = cssColor("checkboxHoveredBorderColor")
  }
  normal = {
    fillColor =   cssColor("checkboxBgColor")
    borderColor = cssColor("checkboxBorderColor")
  }
  disabled = {
    fillColor =   cssColor("checkboxDisabledBgColor")
    borderColor = cssColor("checkboxDisabledBorderColor")
  }
}

let calcTextColor = @(sf) sf & S_ACTIVE ? 0xFFC0C0C0
  : sf & S_HOVER ? 0xFFFFFFFF
  : 0xFFA0A0A0

let calcBoxColor = @(sf) sf & S_ACTIVE ? checkboxBoxColor.active
  : sf & S_HOVER ? checkboxBoxColor.hover
  : checkboxBoxColor.normal

function calcCheckColor(sf, isCheck) {
  if (!isCheck) {
    if (sf & S_HOVER)
      return cssColor("checkboxCheckHoveredUncheckedColor")
    return 0
  }
  return sf & S_ACTIVE ? cssColor("checkboxCheckPushedColor")
    : sf & S_HOVER ? cssColor("checkboxCheckHoveredColor")
    : cssColor("checkboxCheckColor")
}

let mkBackground = @(stateFlags) @() {
  watch = stateFlags
  size = FLEX
  rendObj = ROBJ_SOLID
  color = stateFlags.get() & S_HOVER ? 0xFF3A474F
   : 0
}

let mkCheckComp = @(stateFlags, state) @() {
  watch = [stateFlags, state]
  size = boxSize
  rendObj = ROBJ_IMAGE
  image =  Picture($"ui/gameuiskin#check.svg:{boxSize[0]}:{boxSize[1]}:P")
  color = calcCheckColor(stateFlags.get(), state.get())
}

let mkBox = @(stateFlags, state) @() {
  watch = stateFlags
  size = boxSize
  rendObj = ROBJ_BOX
  borderWidth = hdpx(1)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkCheckComp(stateFlags, state)
}.__update(calcBoxColor(stateFlags.get()))

function mkLabel(stateFlags, params) {
  return @() {
    watch = stateFlags
    rendObj = ROBJ_TEXT
    color = calcTextColor(stateFlags.get())
    font = fontsState.get("normal")
    behavior = Behaviors.Marquee
    speed = hdpx(40)
    delay = 0.3
    scrollOnHover = true
  }.__update(params)
}

function mkImage(stateFlags, image) {
  return @() {
    watch = stateFlags
    size = boxSize
    rendObj = ROBJ_IMAGE
    color = calcTextColor(stateFlags.get())
    image = image == "" ? null : image
  }
}

function mkCheckbox(state, labelTextParams = {}, params = {}) {
  let stateFlags = Watched(0)
  let { setValue = @(v) state.set(v), image = null } = params
  function onClick(){
    setValue(!state.get())
    playSound(state.get() ? "check" : "uncheck")
  }
  return {
    behavior = Behaviors.Button
    onElemState = @(sf) stateFlags.set(sf)
    onClick
    children = [
      mkBackground(stateFlags)
      {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = checkboxGap
        padding = checkboxPadding
        children = [
          image != null ? mkImage(stateFlags, image) : null
          mkLabel(stateFlags, labelTextParams)
          mkBox(stateFlags, state)
        ]
      }
    ]
  }.__update(params?.override ?? {})
}

function mkFormCheckbox(p, state, onChange) {
  let { id, text, isEnabled = null } = p
  let textW = type(text) == "string" ? null : text
  let stateFlags = Watched(0)
  let checkPic = Picture($"ui/gameuiskin#check.svg:{formBoxSize}:{formBoxSize}:K")
  let font = fontsState.get("small")
  return function() {
    let enabled = isEnabled?.get() ?? true
    let isChecked = state.get()
    let markColor = enabled ? calcCheckColor(stateFlags.get(), isChecked)
      : isChecked ? formDisabledCheckColor
      : 0
    return {
      watch = [stateFlags, state, isEnabled, textW]
      key = id
      size = [flex(), formRowH]
      flow = FLOW_HORIZONTAL
      gap = formGap
      valign = ALIGN_CENTER
      behavior = enabled ? Behaviors.Button : null
      onElemState = @(s) stateFlags.set(s)
      function onClick() {
        playSound(isChecked ? "uncheck" : "check")
        onChange(id, !isChecked)
      }
      children = [
        {
          size = formBoxSize
          margin = formBoxMargin
          rendObj = ROBJ_BOX
          borderWidth = formBorder
          children = markColor == 0 ? null
            : { size = flex(), rendObj = ROBJ_IMAGE, image = checkPic, keepAspect = KEEP_ASPECT_FIT, color = markColor }
        }.__update(enabled ? calcBoxColor(stateFlags.get()) : checkboxBoxColor.disabled)
        {
          size = FLEX_H
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          font
          color = cssColor(enabled ? "commonTextColor" : "minorTextColor")
          text = textW?.get() ?? text
        }
      ]
    }
  }
}

return freeze({
  mkCheckbox
  mkFormCheckbox
})
