import "%rGui/style/fontsState.nut" as fontsState
from "%rGui/shipState.nut" import magneticFuseSensitivity, fuseMode
from "%sqstd/math.nut" import fabs
from "weaponUtils" import set_fuse_mode, set_magnetic_fuse_sensitivity, get_magnetic_fuse_sensitivity_presets,
  CONTACT_FUSE_MODE, NONE_FUSE_MODE
from "%rGui/globals/ui_library.nut" import *

const textColor = 0xFFFFFFFF
const btnColor = 0xFF3A4450
const btnHoverColor = 0xFF4E5A68
const trackColor = 0xFF4A525C
const trackFillColor = 0xFFC0C0C0
const knobColor = 0xFFFFFFFF
const disabledOpacity = 0.4

let menuPadding = hdpx(14)
let rowGap = hdpx(8)
let fuseGap = hdpx(4)
let btnSize = hdpx(32)
let trackHeight = hdpx(4)
let knobSize = [hdpx(8), hdpx(18)]
let radioSize = hdpx(20)
let radioDotSize = hdpx(8)
let radioBorderWidth = hdpx(2)
let fuseIconSize = hdpx(40)
let dividerWidth = hdpx(1)
let font = fontsState.get("small")

let sensitivityPresets = Watched([])
let isContactFuse = Computed(@() fuseMode.get() == CONTACT_FUSE_MODE)
let isSensitivityDisabled = Computed(@() isContactFuse.get() || sensitivityPresets.get().len() == 0)

let mkRadio = @(isSelected) {
  size = radioSize
  rendObj = ROBJ_BOX
  fillColor = btnColor
  borderColor = trackColor
  borderWidth = radioBorderWidth
  borderRadius = radioSize / 2
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = isSelected
    ? {
        size = radioDotSize
        rendObj = ROBJ_BOX
        fillColor = knobColor
        borderRadius = radioDotSize / 2
      }
    : null
}

let mkFuseChoice = @(iconName, isContact) @() {
  watch = isContactFuse
  size = FLEX_H
  behavior = isContactFuse.get() == isContact ? null : Behaviors.Button
  onClick = @() set_fuse_mode(isContact ? CONTACT_FUSE_MODE : NONE_FUSE_MODE)
  flow = FLOW_HORIZONTAL
  gap = rowGap
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    mkRadio(isContactFuse.get() == isContact)
    {
      size = fuseIconSize
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#{iconName}.avif:{fuseIconSize}:{fuseIconSize}:P")
    }
  ]
}

let fuseDivider = {
  size = [dividerWidth, fuseIconSize]
  rendObj = ROBJ_SOLID
  color = trackColor
}

let fuseSection = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = fuseGap
  halign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = loc("hud/torpedo_menu/fuse")
    }
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = [
        mkFuseChoice("explosion_middle", true)
        fuseDivider
        mkFuseChoice("torpedo_active_sonar", false)
      ]
    }
  ]
}

function stepSensitivity(dir) {
  let value = magneticFuseSensitivity.get()
  let presets = sensitivityPresets.get()
  let preset = dir > 0
    ? presets.findvalue(@(p) p > value)
    : presets.reduce(@(res, p) p < value ? p : res, null)
  if (preset != null)
    set_magnetic_fuse_sensitivity(preset)
}

let sensitivityHeader = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    {
      size = FLEX_H
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = loc("hud/torpedo_menu/magnetic_fuse_sensitivity")
    }
    @() {
      watch = magneticFuseSensitivity
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = magneticFuseSensitivity.get().tointeger().tostring()
    }
  ]
}

let mkSensitivityBtn = @(text, dir) watchElemState(@(sf) {
  watch = isSensitivityDisabled
  size = btnSize
  rendObj = ROBJ_SOLID
  color = (sf & S_HOVER) ? btnHoverColor : btnColor
  behavior = isSensitivityDisabled.get() ? null : Behaviors.Button
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  onClick = @() stepSensitivity(dir)
  children = {
    rendObj = ROBJ_TEXT
    font
    color = textColor
    text
  }
})

let sensitivityTrackBg = {
  size = [FLEX, trackHeight]
  rendObj = ROBJ_SOLID
  color = trackColor
}

let sensitivityKnob = {
  size = knobSize
  rendObj = ROBJ_SOLID
  color = knobColor
}

function sensitivityTrack() {
  let presets = sensitivityPresets.get()
  let maxValue = presets.len() > 0 ? presets.top() : 0.0
  let value = clamp(magneticFuseSensitivity.get(), 0.0, maxValue)
  return {
    watch = [magneticFuseSensitivity, sensitivityPresets, isSensitivityDisabled]
    size = [FLEX, btnSize]
    behavior = isSensitivityDisabled.get() ? null : Behaviors.Slider
    min = 0
    max = maxValue
    unit = 0
    ignoreWheel = true
    fValue = value
    knob = sensitivityKnob
    onChange = @(newValue) set_magnetic_fuse_sensitivity(
      presets.reduce(@(res, p) fabs(p - newValue) < fabs(res - newValue) ? p : res))
    valign = ALIGN_CENTER
    children = [
      sensitivityTrackBg
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = [
          {
            size = [flex(value), trackHeight]
            rendObj = ROBJ_SOLID
            color = trackFillColor
          }
          sensitivityKnob
          { size = [flex(maxValue - value), trackHeight] }
        ]
      }
    ]
  }
}

let sensitivitySlider = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  gap = rowGap
  valign = ALIGN_CENTER
  children = [
    mkSensitivityBtn("-", -1)
    sensitivityTrack
    mkSensitivityBtn("+", 1)
  ]
}

let sensitivitySection = @() {
  watch = isSensitivityDisabled
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = rowGap
  opacity = isSensitivityDisabled.get() ? disabledOpacity : 1.0
  children = [
    sensitivityHeader
    sensitivitySlider
  ]
}

let torpedoMenu = {
  size = [hdpx(291), hdpx(504)]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  gap = rowGap
  padding = menuPadding
  onAttach = @() sensitivityPresets.set(get_magnetic_fuse_sensitivity_presets())
  children = [
    fuseSection
    sensitivitySection
  ]
}

return {
  torpedoMenu
}
