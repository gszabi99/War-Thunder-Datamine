import "%rGui/style/fontsState.nut" as fontsState
import "%sqstd/ecs.nut" as ecs
from "%rGui/shipState.nut" import fuseMode, isUseTorpedoSightSolution, canUseCourseCorrectionFromSight,
  hasAcousticTorpedo, hasTorpedoCourseCorrection
from "%sqstd/math.nut" import fabs
from "dasevents" import sendNetEvent, CmdSetMagneticFuseSensitivityPreset, CmdSetTorpedoDiveDepth, CmdSetTorpedoCourseProgram
from "mission" import get_local_mplayer
from "weaponUtils" import set_fuse_mode, set_use_torpedo_sight_solution, CONTACT_FUSE_MODE, NONE_FUSE_MODE,
  TORPEDO_COURSE_MODE_NONE, TORPEDO_COURSE_MODE_TRIANGULAR_ZIGZAG, TORPEDO_COURSE_MODE_SQUARE_ZIGZAG,
  TORPEDO_COURSE_MODE_CIRCLE, TORPEDO_GUIDANCE_MODE_NONE, TORPEDO_GUIDANCE_MODE_ACOUSTIC,
  TORPEDO_GUIDANCE_MODE_GYRO_PROGRAM
from "weaponryOptions" import get_option_torpedo_dive_depth_auto, get_option_torpedo_dive_depth_range
from "%rGui/globals/ui_library.nut" import *
import "%rGui/components/comboBox.nut" as comboBox

const textColor = 0xFFFFFFFF
const btnColor = 0xFF3A4450
const btnHoverColor = 0xFF4E5A68
const trackColor = 0xFF4A525C
const trackFillColor = 0xFFC0C0C0
const knobColor = 0xFFFFFFFF
const disabledOpacity = 0.4

const courseDistanceStep = 100
let courseModeChoices = [
  { mode = TORPEDO_COURSE_MODE_NONE, locId = "hud/torpedo_menu/course_mode/none" }
  { mode = TORPEDO_COURSE_MODE_TRIANGULAR_ZIGZAG, locId = "hud/torpedo_menu/course_mode/triangular_zigzag" }
  { mode = TORPEDO_COURSE_MODE_SQUARE_ZIGZAG, locId = "hud/torpedo_menu/course_mode/square_zigzag" }
  { mode = TORPEDO_COURSE_MODE_CIRCLE, locId = "hud/torpedo_menu/course_mode/circle" }
]

let menuWidth = hdpx(291)
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
let guidanceMode = Watched(TORPEDO_GUIDANCE_MODE_NONE)
let courseMode = Watched(TORPEDO_COURSE_MODE_NONE)
let courseStartSection = Watched(-1.0)
let coursePathSection = Watched(-1.0)
let courseModesMask = Watched(0)
let courseStartSectionMin = Watched(0.0)
let courseStartSectionMax = Watched(0.0)
let coursePathSectionMin = Watched(0.0)
let coursePathSectionMax = Watched(0.0)

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
      guidanceMode.set(comp.shell_program__torpedoGuidanceMode)
      courseMode.set(comp.shell_program__torpedoCourseMode)
      courseStartSection.set(comp.shell_program__torpedoCourseStartSection)
      coursePathSection.set(comp.shell_program__torpedoCoursePathSection)
      courseModesMask.set(comp.shell_program__torpedoCourseModesMask)
      courseStartSectionMin.set(comp.shell_program__torpedoCourseStartSectionMin)
      courseStartSectionMax.set(comp.shell_program__torpedoCourseStartSectionMax)
      coursePathSectionMin.set(comp.shell_program__torpedoCoursePathSectionMin)
      coursePathSectionMax.set(comp.shell_program__torpedoCoursePathSectionMax)
    }
    onDestroy = function(eid, _comp) {
      if (eid != shellProgramEid.get())
        return
      shellProgramEid.set(ecs.INVALID_ENTITY_ID)
      sensitivityPresets.set([])
      sensitivityPresetIdx.set(-1)
      diveDepth.set(null)
      guidanceMode.set(TORPEDO_GUIDANCE_MODE_NONE)
      courseMode.set(TORPEDO_COURSE_MODE_NONE)
      courseModesMask.set(0)
      courseStartSection.set(-1.0)
      coursePathSection.set(-1.0)
      courseStartSectionMin.set(0.0)
      courseStartSectionMax.set(0.0)
      coursePathSectionMin.set(0.0)
      coursePathSectionMax.set(0.0)
    }
  },
  {
    comps_track = [
      ["shell_program__magneticFuseSensitivityPreset", ecs.TYPE_INT],
      ["shell_program__magneticFuseSensitivityPresetValues", ecs.TYPE_FLOAT_LIST],
      ["shell_program__torpedoDiveDepth", ecs.TYPE_FLOAT],
      ["shell_program__torpedoGuidanceMode", ecs.TYPE_INT],
      ["shell_program__torpedoCourseMode", ecs.TYPE_INT],
      ["shell_program__torpedoCourseStartSection", ecs.TYPE_FLOAT],
      ["shell_program__torpedoCoursePathSection", ecs.TYPE_FLOAT],
      ["shell_program__torpedoCourseModesMask", ecs.TYPE_INT],
      ["shell_program__torpedoCourseStartSectionMin", ecs.TYPE_FLOAT],
      ["shell_program__torpedoCourseStartSectionMax", ecs.TYPE_FLOAT],
      ["shell_program__torpedoCoursePathSectionMin", ecs.TYPE_FLOAT],
      ["shell_program__torpedoCoursePathSectionMax", ecs.TYPE_FLOAT]
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

function sendCourseProgram(fields) {
  if (shellProgramEid.get() == ecs.INVALID_ENTITY_ID)
    return
  sendNetEvent(shellProgramEid.get(), CmdSetTorpedoCourseProgram({
    guidanceMode = guidanceMode.get()
    mode = courseMode.get()
    startSection = courseStartSection.get()
    pathSection = coursePathSection.get()
    ...fields
  }))
}

function setGuidanceMode(mode) {
  if (mode != guidanceMode.get())
    sendCourseProgram({ guidanceMode = mode })
}

function findNearestPresetIdx(presets, value) {
  local nearestIdx = 0
  foreach (idx, preset in presets)
    if (fabs(preset - value) < fabs(presets[nearestIdx] - value))
      nearestIdx = idx
  return nearestIdx
}

let isContactFuse = Computed(@() fuseMode.get() == CONTACT_FUSE_MODE)
let isNonContactFuse = Computed(@() !isContactFuse.get())
let isStraightRun = Computed(@() !isUseTorpedoSightSolution.get())
let isSensitivityDisabled = Computed(@() magneticFuseSensitivity.get() == null || isContactFuse.get())
let sensitivityRange = Computed(@() [0.0, sensitivityPresets.get().len() > 0 ? sensitivityPresets.get().top() : 0.0])
let isDiveDepthDisabled = Computed(@() diveDepth.get() == null)
let diveDepthRange = Computed(@() [diveDepthMin.get(), diveDepthMax.get()])
let allowedCourseModes = Computed(@() courseModeChoices.filter(@(choice) choice.mode == TORPEDO_COURSE_MODE_NONE ||
  choice.mode == courseMode.get() || (courseModesMask.get() & (1 << choice.mode)) != 0))
let hasCourseProgram = Computed(@() courseModesMask.get() != 0)
let isCourseModeSelected = Computed(@() courseMode.get() != TORPEDO_COURSE_MODE_NONE)
let isCourseCircle = Computed(@() courseMode.get() == TORPEDO_COURSE_MODE_CIRCLE)
let courseStartSectionValue = Computed(@() courseStartSection.get() < 0 ? null : courseStartSection.get())
let coursePathSectionValue = Computed(@() coursePathSection.get() < 0 ? null : coursePathSection.get())
let courseStartSectionRange = Computed(@() [courseStartSectionMin.get(), courseStartSectionMax.get()])
let coursePathSectionRange = Computed(@() [coursePathSectionMin.get(), coursePathSectionMax.get()])
let isRouteAvailable = Computed(@() hasCourseProgram.get() && hasTorpedoCourseCorrection.get())
let hasGuidanceChoice = Computed(@() hasAcousticTorpedo.get() || isRouteAvailable.get())
let isRouteSelected = Computed(@() guidanceMode.get() == TORPEDO_GUIDANCE_MODE_GYRO_PROGRAM && isRouteAvailable.get())
let isAcousticSelected = Computed(@() hasAcousticTorpedo.get() && !isRouteSelected.get())

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

let mkIconChoice = @(iconName, isSelected, isEnabled, onClick) @() {
  watch = [isSelected, isEnabled]
  size = FLEX_H
  behavior = (isSelected.get() || !(isEnabled?.get() ?? true)) ? null : Behaviors.Button
  onClick
  opacity = (isEnabled?.get() ?? true) ? 1.0 : disabledOpacity
  flow = FLOW_HORIZONTAL
  gap = rowGap
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    mkRadio(isSelected.get())
    {
      size = fuseIconSize
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#{iconName}.avif:{fuseIconSize}:{fuseIconSize}:P")
    }
  ]
}

let choiceDivider = {
  size = [dividerWidth, fuseIconSize]
  rendObj = ROBJ_SOLID
  color = trackColor
}

let mkChoiceSection = @(titleLocId, firstChoice, secondChoice) {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = fuseGap
  halign = ALIGN_CENTER
  children = [
    @() {
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = loc(titleLocId)
    }
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      children = [
        firstChoice
        choiceDivider
        secondChoice
      ]
    }
  ]
}

let fuseSection = mkChoiceSection("hud/torpedo_menu/fuse",
  mkIconChoice("torpedo_contact_fuze", isContactFuse, null, @() set_fuse_mode(CONTACT_FUSE_MODE)),
  mkIconChoice("torpedo_magnetic_fuze", isNonContactFuse, null, @() set_fuse_mode(NONE_FUSE_MODE)))

let travelChoices = mkChoiceSection("hud/torpedo_menu/travel",
  mkIconChoice("torpedo_no_homing", isStraightRun, null, @() set_use_torpedo_sight_solution(false)),
  mkIconChoice("torpedo_homing", isUseTorpedoSightSolution, null, @() set_use_torpedo_sight_solution(true)))

let mkShowIf = @(isVisible, content) @() {
  watch = isVisible
  size = isVisible.get() ? FLEX_H : null
  children = isVisible.get() ? content : null
}

let travelSection = mkShowIf(canUseCourseCorrectionFromSight, travelChoices)

let guidanceChoices = mkChoiceSection("hud/torpedo_menu/guidance",
  mkIconChoice("torpedo_acoustic_homing", isAcousticSelected, hasAcousticTorpedo,
    @() setGuidanceMode(TORPEDO_GUIDANCE_MODE_ACOUSTIC)),
  mkIconChoice("torpedo_gyro_homing", isRouteSelected, isRouteAvailable, @() setGuidanceMode(TORPEDO_GUIDANCE_MODE_GYRO_PROGRAM)))

let guidanceSection = mkShowIf(hasGuidanceChoice, guidanceChoices)

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

let courseModeIdx = Computed(@() allowedCourseModes.get().findindex(@(choice) choice.mode == courseMode.get()) ?? 0)
let courseModeComboSize = [menuWidth - 2 * menuPadding, btnSize]
let isCourseModeComboEnabled = Computed(@() isRouteSelected.get() && courseStartSectionValue.get() != null &&
  coursePathSectionValue.get() != null)

let courseModeCombo = @() {
  watch = allowedCourseModes
  children = comboBox({ id = "torpedo_course_mode", options = allowedCourseModes.get().map(@(choice) { text = loc(choice.locId) }),
      isEnabled = isCourseModeComboEnabled },
    courseModeIdx, @(_id, idx) sendCourseProgram({ mode = allowedCourseModes.get()[idx].mode }), courseModeComboSize)
}

function mkCourseSlider(titleLocId, value, range, field) {
  let isDisabled = Computed(@() value.get() == null || !isRouteSelected.get())
  function setDistance(newValue) {
    let [minValue, maxValue] = range.get()
    let clamped = clamp(newValue, minValue, maxValue).tofloat()
    if (clamped != value.get())
      sendCourseProgram({ [field] = clamped })
  }
  return mkSliderSection(titleLocId, value, range, courseDistanceStep, isDisabled,
    @(dir) setDistance(value.get() + dir * courseDistanceStep), setDistance)
}

let courseStartSectionSlider = mkCourseSlider("hud/torpedo_menu/course_start_section",
  courseStartSectionValue, courseStartSectionRange, "startSection")
let coursePathSectionSlider = mkCourseSlider("hud/torpedo_menu/course_path_section", coursePathSectionValue, coursePathSectionRange, "pathSection")
let courseRadiusSlider = mkCourseSlider("hud/torpedo_menu/course_radius", coursePathSectionValue, coursePathSectionRange, "pathSection")

let courseParams = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = rowGap
  children = [
    courseStartSectionSlider
    @() {
      watch = isCourseCircle
      size = FLEX_H
      children = isCourseCircle.get() ? courseRadiusSlider : coursePathSectionSlider
    }
  ]
}

let courseProgramSection = @() {
  watch = [isRouteAvailable, isCourseModeSelected]
  size = isRouteAvailable.get() ? FLEX_H : null
  flow = FLOW_VERTICAL
  gap = rowGap
  children = !isRouteAvailable.get() ? null : [
    courseModeCombo
    isCourseModeSelected.get() ? courseParams : null
  ]
}

let torpedoMenu = {
  size = [menuWidth, hdpx(504)]
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  gap = rowGap
  padding = menuPadding
  children = [
    fuseSection
    sensitivitySection
    travelSection
    guidanceSection
    courseProgramSection
    diveDepthSection
  ]
}

return {
  torpedoMenu
}
