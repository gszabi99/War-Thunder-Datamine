from "%rGui/globals/ui_library.nut" import *
let { playSound } = require("sound_wt")
let fontsState = require("%rGui/style/fontsState.nut")

let boxSize = [hdpx(20), hdpx(20)]
let checkboxGap = hdpx(5)
let checkboxPadding = hdpx(2)

let checkboxBoxColor = {
  active = {
    fillcolor =   0xFF435158
    borderColor = 0xFF999B8C
  }
  hover = {
    fillcolor =   0xFF0D1116
    borderColor = 0xFF6D7974
  }
  normal = {
    fillcolor =   0xFF0D1116
    borderColor = 0xFF3E4B52
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
      return 0x40404040
    return 0
  }
  return sf & S_ACTIVE ? 0x80808080
    : sf & S_HOVER ? 0xC0C0C0C0
    : 0xFFFFFFFF
}

let mkBackground = @(stateFlags) @() {
  watch = stateFlags
  size = flex()
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
    speed = [hdpx(40),hdpx(40)]
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

return {
  mkCheckbox
}
