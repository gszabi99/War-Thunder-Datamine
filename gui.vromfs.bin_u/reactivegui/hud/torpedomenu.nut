import "%rGui/style/fontsState.nut" as fontsState
import "%sqstd/ecs.nut" as ecs
from "%rGui/shipState.nut" import fuseMode, isUseTorpedoSightSolution, canUseCourseCorrectionFromSight,
  hasAcousticTorpedo, hasTorpedoCourseCorrection
from "%sqstd/math.nut" import fabs
from "dasevents" import sendNetEvent, CmdSetMagneticFuseSensitivityPreset, CmdSetTorpedoDiveDepth, CmdSetTorpedoCourseProgram
from "mission" import get_local_mplayer
from "weaponUtils" import set_fuse_mode, CONTACT_FUSE_MODE, NONE_FUSE_MODE
from "weaponryOptions" import get_option_torpedo_dive_depth_auto, get_option_torpedo_dive_depth_range
from "%rGui/globals/ui_library.nut" import *
from "%rGui/components/blurPanel.nut" import wndBlurPanel
import "%rGui/components/comboBox.nut" as comboBox
import "%rGui/components/button.nut" as button
import "%appGlobals/style/cssColors.nut" as cssColors
import "%rGui/components/slider.nut" as slider
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach

let { set_use_torpedo_sight_solution = @(_) null,
  TORPEDO_COURSE_MODE_NONE = 0, TORPEDO_COURSE_MODE_TRIANGULAR_ZIGZAG = 1, TORPEDO_COURSE_MODE_SQUARE_ZIGZAG = 2,
  TORPEDO_COURSE_MODE_CIRCLE = 3, TORPEDO_GUIDANCE_MODE_NONE = 0, TORPEDO_GUIDANCE_MODE_ACOUSTIC = 2,
  TORPEDO_GUIDANCE_MODE_GYRO_PROGRAM = 3 } = require("weaponUtils")

const textColor = 0xFFA0A0A0
const valueColor = 0xFFC0C0C0
const dividerColor = 0xFF373E46
const disabledOpacity = 0.3

const courseDistanceStep = 100
let courseModeChoices = [
  { mode = TORPEDO_COURSE_MODE_NONE, locId = "hud/torpedo_menu/course_mode/none" }
  { mode = TORPEDO_COURSE_MODE_TRIANGULAR_ZIGZAG, locId = "hud/torpedo_menu/course_mode/triangular_zigzag" }
  { mode = TORPEDO_COURSE_MODE_SQUARE_ZIGZAG, locId = "hud/torpedo_menu/course_mode/square_zigzag" }
  { mode = TORPEDO_COURSE_MODE_CIRCLE, locId = "hud/torpedo_menu/course_mode/circle" }
]

let menuWidth = hdpx(291)
let menuPadding = hdpx(4)
let sectionGap = hdpx(4)
let sliderSectionGap = hdpx(8)
let choiceTitleGap = hdpx(2)
let choiceGap = hdpx(10)
let choiceOuterPadding = hdpx(26)
let choiceInnerPadding = hdpx(35)
let controlsWidth = hdpx(271)
let sliderTitleGap = hdpx(6)
let sliderControlsGap = hdpx(14)
let sliderTrackWidth = hdpx(195)
let btnSize = hdpx(24)
let comboHeight = hdpx(36)
let trackHeight = hdpx(7)
let sliderHeight = trackHeight + 2 * cssConst("sliderIncHeight")
let thumbSize = [hdpx(11), hdpx(19)]
let radioSize = hdpx(22)
let fuseIconSize = hdpx(42)
let dividerWidth = hdpx(1)
let dividerHeight = hdpx(40)
let choiceWidth = (controlsWidth - dividerWidth) / 2
let font = fontsState.get("tiny")
let meterUnit = $" {loc("measureUnits/meters_alt")}"

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
let isSensitivityEnabled = Computed(@() magneticFuseSensitivity.get() != null && !isContactFuse.get())
let sensitivityRange = Computed(@() sensitivityPresets.get().len() > 0 ? [sensitivityPresets.get()[0], sensitivityPresets.get().top()] : [0.0, 0.0])
let isDiveDepthEnabled = Computed(@() diveDepth.get() != null)
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

let mkRadio = @(isSelected, isEnabled, stateFlags) @() {
  watch = stateFlags
  size = radioSize
  rendObj = ROBJ_IMAGE
  image = Picture(isSelected ? $"ui/gameuiskin#radiobutton_checked_.svg:{radioSize}:{radioSize}:P"
    : isEnabled && ((stateFlags.get() & S_HOVER) != 0) ? $"ui/gameuiskin#radiobutton_unchecked_hover.svg:{radioSize}:{radioSize}:P"
    : $"ui/gameuiskin#radiobutton_unchecked_.svg:{radioSize}:{radioSize}:P")
}

function mkIconChoice(iconName, isSelected, isEnabled, onClick, isFirst = true) {
  let stateFlags = Watched(0)
  let onElemState = withHint(stateFlags, iconName, @() loc($"hud/torpedo_menu/{iconName}/desc"))
  let onDetach = tooltipDetach(stateFlags, iconName)
  return @() {
    key = iconName
    watch = [isSelected, isEnabled]
    size = [choiceWidth, fuseIconSize]
    padding = isFirst ? [0, choiceInnerPadding, 0, choiceOuterPadding]
      : [0, choiceOuterPadding, 0, choiceInnerPadding]
    behavior = Behaviors.Button
    onClick = (isSelected.get() || !(isEnabled?.get() ?? true)) ? null : onClick
    onElemState
    onDetach
    opacity = (isEnabled?.get() ?? true) ? 1.0 : disabledOpacity
    flow = FLOW_HORIZONTAL
    gap = choiceGap
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      mkRadio(isSelected.get(), isEnabled?.get() ?? true, stateFlags)
      {
        size = fuseIconSize
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/gameuiskin#{iconName}.avif:{fuseIconSize}:{fuseIconSize}:P")
      }
    ]
  }
}

let choiceDivider = {
  size = [dividerWidth, dividerHeight]
  rendObj = ROBJ_SOLID
  color = dividerColor
}

let mkChoiceSection = @(titleLocId, firstChoice, secondChoice) {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = choiceTitleGap
  halign = ALIGN_CENTER
  children = [
    @() {
      rendObj = ROBJ_TEXT
      font
      color = textColor
      text = $"{loc(titleLocId)}:"
    }
    {
      size = [controlsWidth, fuseIconSize]
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
  mkIconChoice("torpedo_magnetic_fuze", isNonContactFuse, null, @() set_fuse_mode(NONE_FUSE_MODE), false))

let travelChoices = mkChoiceSection("hud/torpedo_menu/travel",
  mkIconChoice("torpedo_no_homing", isStraightRun, null, @() set_use_torpedo_sight_solution(false)),
  mkIconChoice("torpedo_homing", isUseTorpedoSightSolution, null, @() set_use_torpedo_sight_solution(true), false))

let mkShowIf = @(isVisible, content) @() {
  watch = isVisible
  size = isVisible.get() ? FLEX_H : null
  children = isVisible.get() ? content : null
}

let travelSection = mkShowIf(canUseCourseCorrectionFromSight, travelChoices)

let guidanceChoices = mkChoiceSection("hud/torpedo_menu/guidance",
  mkIconChoice("torpedo_acoustic_homing", isAcousticSelected, hasAcousticTorpedo,
    @() setGuidanceMode(TORPEDO_GUIDANCE_MODE_ACOUSTIC)),
  mkIconChoice("torpedo_gyro_homing", isRouteSelected, isRouteAvailable,
    @() setGuidanceMode(TORPEDO_GUIDANCE_MODE_GYRO_PROGRAM), false))

let guidanceSection = mkShowIf(hasGuidanceChoice, guidanceChoices)

let mkSliderHeader = @(titleLocId, value, valueSuffix, isEnabled) @() {
  watch = isEnabled
  size = [controlsWidth, SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  opacity = isEnabled.get() ? 1.0 : disabledOpacity
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
      color = valueColor
      text = value.get() == null ? "" : $"{value.get().tointeger()}{valueSuffix}"
    }
  ]
}

let mkStepBtn = @(id, text, isEnabled, onClick) button({
  id
  text
  size = [btnSize, btnSize]
  minWidth = btnSize
  margin = 0
  isEnabled
  skipDirPadNav = true
}, onClick)

function mkSliderTrack(value, range, step, isEnabled, onChange) {
  let sliderValue = Computed(@() value.get() ?? range.get()[0])
  return function() {
    let [minValue, maxValue] = range.get()
    return {
      watch = range
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children = slider(
        { minVal = minValue, maxVal = maxValue, step, hasThumb = true,
          thumbSize, isEnabled, ignoreWheel = true },
        sliderValue, @(_, v) onChange(v), [sliderTrackWidth, sliderHeight])
    }
  }
}

function mkSliderSection(titleLocId, value, range, step, isEnabled, onStep, onChange, valueSuffix = "") {
  let header = mkSliderHeader(titleLocId, value, valueSuffix, isEnabled)
  let controls = {
    size = [controlsWidth, btnSize]
    flow = FLOW_HORIZONTAL
    gap = sliderControlsGap
    valign = ALIGN_CENTER
    children = [
      mkStepBtn($"{titleLocId}_dec", "-", isEnabled, @() onStep(-1))
      mkSliderTrack(value, range, step, isEnabled, onChange)
      mkStepBtn($"{titleLocId}_inc", "+", isEnabled, @() onStep(1))
    ]
  }
  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = sliderTitleGap
    halign = ALIGN_CENTER
    children = [header, controls]
  }
}

let sensitivitySection = mkSliderSection("hud/torpedo_menu/magnetic_fuse_sensitivity",
  magneticFuseSensitivity, sensitivityRange, 1, isSensitivityEnabled,
  @(dir) setSensitivityPresetIdx(sensitivityPresetIdx.get() + dir),
  @(newValue) setSensitivityPresetIdx(findNearestPresetIdx(sensitivityPresets.get(), newValue)))

let diveDepthSlider = mkSliderSection("bullet_properties/diveDepth",
  diveDepth, diveDepthRange, 1, isDiveDepthEnabled,
  @(dir) setDiveDepth((diveDepth.get() ?? diveDepthMin.get()) + dir),
  setDiveDepth, meterUnit)

let diveDepthSection = @() {
  watch = isDiveDepthAuto
  size = isDiveDepthAuto.get() ? null : FLEX_H
  margin = isDiveDepthAuto.get() ? null : [0, 0, sectionGap, 0]
  children = isDiveDepthAuto.get() ? null : diveDepthSlider
}

let courseModeIdx = Computed(@() allowedCourseModes.get().findindex(@(choice) choice.mode == courseMode.get()) ?? 0)
let courseModeComboSize = [controlsWidth, comboHeight]
let isCourseModeComboEnabled = Computed(@() isRouteSelected.get() && courseStartSectionValue.get() != null &&
  coursePathSectionValue.get() != null)

let courseModeCombo = @() {
  watch = allowedCourseModes
  children = comboBox({ id = "torpedo_course_mode", options = allowedCourseModes.get().map(@(choice) { text = loc(choice.locId) }),
      isEnabled = isCourseModeComboEnabled },
    courseModeIdx, @(_id, idx) sendCourseProgram({ mode = allowedCourseModes.get()[idx].mode }), courseModeComboSize)
}

function mkCourseSlider(titleLocId, value, range, field) {
  let isEnabled = Computed(@() value.get() != null && isRouteSelected.get())
  function setDistance(newValue) {
    let [minValue, maxValue] = range.get()
    let clamped = clamp(newValue, minValue, maxValue).tofloat()
    if (clamped != value.get())
      sendCourseProgram({ [field] = clamped })
  }
  return mkSliderSection(titleLocId, value, range, courseDistanceStep, isEnabled,
    @(dir) setDistance(value.get() + dir * courseDistanceStep), setDistance, meterUnit)
}

let courseStartSectionSlider = mkCourseSlider("hud/torpedo_menu/course_start_section",
  courseStartSectionValue, courseStartSectionRange, "startSection")
let coursePathSectionSlider = mkCourseSlider("hud/torpedo_menu/course_path_section", coursePathSectionValue, coursePathSectionRange, "pathSection")
let courseRadiusSlider = mkCourseSlider("hud/torpedo_menu/course_radius", coursePathSectionValue, coursePathSectionRange, "pathSection")

let courseParams = {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = sliderSectionGap
  halign = ALIGN_CENTER
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
  gap = sliderSectionGap
  halign = ALIGN_CENTER
  children = !isRouteAvailable.get() ? null : [
    courseModeCombo
    isCourseModeSelected.get() ? courseParams : null
  ]
}

let sectionsDivider = {
  size = [controlsWidth, dividerWidth + 2 * sectionGap]
  valign = ALIGN_CENTER
  children = {
    size = [flex(), dividerWidth]
    rendObj = ROBJ_SOLID
    color = dividerColor
  }
}

let mkSectionBlock = @(children) {
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = sectionGap
  halign = ALIGN_CENTER
  children
}

let torpedoMenu = {
  size = [menuWidth, SIZE_TO_CONTENT]
  rendObj = ROBJ_SOLID
  color = cssColors.frameDarkTransparentBgColor
  children = [
    wndBlurPanel
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap = sectionsDivider
      padding = menuPadding
      children = [
        travelSection
        mkSectionBlock([guidanceSection, diveDepthSection, courseProgramSection])
        mkSectionBlock([fuseSection, sensitivitySection])
      ]
    }
  ]
}

return {
  torpedoMenu
}
