import "%rGui/style/fontsState.nut" as fontsState
import "%sqstd/ecs.nut" as ecs
from "%rGui/shipState.nut" import fuseMode
from "%sqstd/math.nut" import fabs
from "dasevents" import sendNetEvent, CmdSetMagneticFuseSensitivityPreset, CmdSetTorpedoDiveDepth
from "mission" import get_local_mplayer
from "weaponUtils" import set_fuse_mode, CONTACT_FUSE_MODE, NONE_FUSE_MODE
from "weaponryOptions" import get_option_torpedo_dive_depth_auto, get_option_torpedo_dive_depth_range
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

let shellProgramEid = Watched(ecs.INVALID_ENTITY_ID)
let sensitivityPresets = Watched([])
let sensitivityPresetIdx = Watched(-1)
let magneticFuseSensitivity = Computed(@() sensitivityPresetIdx.get() < 0 ? null : sensitivityPresets.get()?[sensitivityPresetIdx.get()])
let diveDepth = Watched(null)
let isDiveDepthAuto = Watched(true)
let diveDepthMin = Watched(0)
let diveDepthMax = Watched(0)

ecs.register_es("torpedo_menu_shell_program_ui_es",
  {
    [["onInit", "onChange"]] = function(eid, comp) {
      if (comp.base_player_id != get_local_mplayer()?.id)
        return
      shellProgramEid.set(eid)
      sensitivityPresets.set(comp.shell_program__magneticFuseSensitivityPresetValues.getAll())
      sensitivityPresetIdx.set(comp.shell_program__magneticFuseSensitivityPreset)
      diveDepth.set(comp.shell_program__torpedoDiveDepth < 0 ? null : comp.shell_program__torpedoDiveDepth)
      let [depthMin, depthMax] = get_option_torpedo_dive_depth_range()
      isDiveDepthAuto.set(get_option_torpedo_dive_depth_auto())
      diveDepthMin.set(depthMin)
      diveDepthMax.set(depthMax)
    }
    onDestroy = function(eid, _comp) {
      if (eid != shellProgramEid.get())
        return
      shellProgramEid.set(ecs.INVALID_ENTITY_ID)
      sensitivityPresets.set([])
      sensitivityPresetIdx.set(-1)
      diveDepth.set(null)
    }
  },
  {
    comps_track = [
      ["shell_program__magneticFuseSensitivityPreset", ecs.TYPE_INT],
      ["shell_program__magneticFuseSensitivityPresetValues", ecs.TYPE_FLOAT_LIST],
      ["shell_program__torpedoDiveDepth", ecs.TYPE_FLOAT]
    ]
    comps_ro = [["base_player_id", ecs.TYPE_INT]]
  },
  { tags = "gameClient" }
)

function setSensitivityPresetIdx(presetIdx) {
  if (presetIdx < 0 || presetIdx >= sensitivityPresets.get().len() || presetIdx == sensitivityPresetIdx.get()
      || shellProgramEid.get() == ecs.INVALID_ENTITY_ID)
    return
  sendNetEvent(shellProgramEid.get(), CmdSetMagneticFuseSensitivityPreset({ presetIdx }))
}

function setDiveDepth(depth) {
  let value = clamp(depth, diveDepthMin.get(), diveDepthMax.get()).tofloat()
  if (value == diveDepth.get() || shellProgramEid.get() == ecs.INVALID_ENTITY_ID)
    return
  sendNetEvent(shellProgramEid.get(), CmdSetTorpedoDiveDepth({ depth = value }))
}

function findNearestPresetIdx(presets, value) {
  local nearestIdx = 0
  foreach (idx, preset in presets)
    if (fabs(preset - value) < fabs(presets[nearestIdx] - value))
      nearestIdx = idx
  return nearestIdx
}

let isContactFuse = Computed(@() fuseMode.get() == CONTACT_FUSE_MODE)
let isSensitivityDisabled = Computed(@() magneticFuseSensitivity.get() == null || isContactFuse.get())
let sensitivityRange = Computed(@() [0.0, sensitivityPresets.get().len() > 0 ? sensitivityPresets.get().top() : 0.0])
let isDiveDepthDisabled = Computed(@() diveDepth.get() == null)
let diveDepthRange = Computed(@() [diveDepthMin.get(), diveDepthMax.get()])

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
    @() {
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

let mkSliderHeader = @(titleLocId, value) {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      size = FLEX_H
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = loc(titleLocId)
    }
    @() {
      watch = value
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = value.get()?.tointeger()?.tostring() ?? ""
    }
  ]
}

let mkStepBtn = @(text, isDisabled, onClick) watchElemState(@(sf) {
  watch = isDisabled
  size = btnSize
  rendObj = ROBJ_SOLID
  color = (sf & S_HOVER) ? btnHoverColor : btnColor
  behavior = isDisabled.get() ? null : Behaviors.Button
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  onClick
  children = {
    rendObj = ROBJ_TEXT
    font
    color = textColor
    text
  }
})

let sliderTrackBg = {
  size = [FLEX, trackHeight]
  rendObj = ROBJ_SOLID
  color = trackColor
}

let sliderKnob = {
  size = knobSize
  rendObj = ROBJ_SOLID
  color = knobColor
}

let mkSliderTrack = @(value, range, unit, isDisabled, onChange) function() {
  let [minValue, maxValue] = range.get()
  let curValue = value.get()
  let clampedValue = clamp(curValue ?? minValue, minValue, maxValue)
  return {
    watch = [value, range, isDisabled]
    size = [FLEX, btnSize]
    behavior = isDisabled.get() ? null : Behaviors.Slider
    min = minValue
    max = maxValue
    unit
    ignoreWheel = true
    fValue = clampedValue
    knob = sliderKnob
    onChange
    valign = ALIGN_CENTER
    children = [
      sliderTrackBg
      curValue == null ? null : {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = [
          {
            size = [flex(clampedValue - minValue), trackHeight]
            rendObj = ROBJ_SOLID
            color = trackFillColor
          }
          sliderKnob
          { size = [flex(maxValue - clampedValue), trackHeight] }
        ]
      }
    ]
  }
}

function mkSliderSection(titleLocId, value, range, unit, isDisabled, onStep, onChange) {
  let header = mkSliderHeader(titleLocId, value)
  let controls = {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = rowGap
    valign = ALIGN_CENTER
    children = [
      mkStepBtn("-", isDisabled, @() onStep(-1))
      mkSliderTrack(value, range, unit, isDisabled, onChange)
      mkStepBtn("+", isDisabled, @() onStep(1))
    ]
  }
  return @() {
    watch = isDisabled
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = rowGap
    opacity = isDisabled.get() ? disabledOpacity : 1.0
    children = [header, controls]
  }
}

let sensitivitySection = mkSliderSection("hud/torpedo_menu/magnetic_fuse_sensitivity",
  magneticFuseSensitivity, sensitivityRange, 0, isSensitivityDisabled,
  @(dir) setSensitivityPresetIdx(sensitivityPresetIdx.get() + dir),
  @(newValue) setSensitivityPresetIdx(findNearestPresetIdx(sensitivityPresets.get(), newValue)))

let diveDepthSlider = mkSliderSection("options/torpedo_dive_depth",
  diveDepth, diveDepthRange, 1, isDiveDepthDisabled,
  @(dir) setDiveDepth((diveDepth.get() ?? diveDepthMin.get()) + dir),
  setDiveDepth)

let diveDepthSection = @() {
  watch = isDiveDepthAuto
  size = isDiveDepthAuto.get() ? null : FLEX_H
  children = isDiveDepthAuto.get() ? null : diveDepthSlider
}

let torpedoMenu = {
  size = [hdpx(291), hdpx(504)]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  gap = rowGap
  padding = menuPadding
  children = [
    fuseSection
    sensitivitySection
    diveDepthSection
  ]
}

return {
  torpedoMenu
}
