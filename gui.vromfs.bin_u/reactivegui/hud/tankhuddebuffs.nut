from "%rGui/globals/ui_library.nut" import *

let { PI, cos, sin, roundToDigits } = require("%sqstd/math.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let { dmgIndicatorStates } = require("%rGui/hudState.nut")
let { userOptDamageIndicatorSize } = require("%rGui/options/options.nut")
let { isInitializedMeasureUnits, measureUnitsNames } = require("%rGui/options/optionsMeasureUnits.nut")
let { withTooltip, tooltipDetach } = require("%rGui/components/tooltip.nut")
let { rpm, cruiseControlValue, gear, speed, hasSpeedWarning,
  stabilizer, lws, ircm, firstStageAmmo, drivingDirectionMode } = require("%rGui/hud/tankState.nut")
let { tracksData, turretDriveData, gunData, engineData,
  engineOverheatState, fireState, reInitTankDebuffsStates } = require("%rGui/hud/tankHudDebuffsState.nut")
let { crewState, crewGunnerState, crewDriverState, distance, reInitHudCrewStates } = require("%rGui/hud/tankHudCrewState.nut")

const MIN_CREW_COUNT_FOR_WARNING = 2

let even = @(px) (px / 2.0).tointeger() * 2

let transferStates = ["takingPlace", "healing"]
let haveTooltipStates = ["dead", "takingPlace", "healing"]

let textShadowParams = {
  fontFxColor = 0xA0000000
  fontFxFactor = 24
  fontFx = FFT_SHADOW
  fontFxOffsX = 0
  fontFxOffsY = 0
}

let fontParams = {
  [-2] = { font = fontsState.get("tiny"), fontSize = shHud(1) },
  [-1] = { font = fontsState.get("tiny") },
  [0] = { font = fontsState.get("small") },
  [1] = { font = fontsState.get("small") },
  [2] = { font = fontsState.get("normal") },
  small = { font = fontsState.get("small") }
}

let fontParamsByScale = Computed(@() fontParams?[userOptDamageIndicatorSize.get()] ?? fontParams.small)
let compSize = Computed(@() even(dmgIndicatorStates.get().size[0] / 7))
let indicatorSize = Computed(@() dmgIndicatorStates.get().size[0])

let frameBorderColor = 0xFF3A434E
let frameBackgroundColor = 0xFF2D343C
let textCompColor = 0xFFC0C0C0

let stateColors = {
  ok = 0x500B0E10
  damaged = 0xFFFAB025
  bad = 0xFFDD1111
  dead = 0xFF000000
  overheat = 0xFFDD1111
  burns = 0xFFFF0000
  red = 0xFFFF0000
  white = 0xFFFFFFFF

  dmg = 0xFFDD1111
  on = 0xFFFFFFFF
  off = 0xB41A2025
}

let firstStageAmmoStateColors = {
  none = 0xFFFFFFFF
  dead = 0xFF586269
  dmg = 0xFFDD1111
}

let firstStageAmmoStateValueColors = {
  none = 0xFFC0C0C0
  dead = 0xFF586269
}

let speedStateValueColors = {
  ok = 0xFFC0C0C0
  bad = 0xFFDD1111
}

let crewStateColors = {
  ok = 0x500B0E10
  dead = 0xFF586269
  dmg = 0xFFD31111
  takingPlace = 0xFFD31111
  healing = 0xFFD31111
}

let drivingDirectionModeColorOn = 0xFF86D808
let drivingDirectionModeColorOff = 0xFF252E35


let tooltips = {
  horizontalDriveBroken = "hud_tank_turret_drive_h_broken"
  verticalDriveBroken   = "hud_tank_turret_drive_v_broken"
  barrelDamaged         = "hud_gun_barell_malfunction"
  breechDamaged         = "hud_gun_breech_malfunction"
  barrelBroken          = "hud_gun_barrel_exploded"
  breechBroken          = "hud_gun_breech_malfunction"
  transmissionBroken    = "hud_tank_transmission_damaged"
  engineBroken          = "hud_tank_engine_damaged"
  trackBroken           = "hud_tank_track_damaged"
}

let isTransferState = @(state) transferStates.contains(state)
let isHaveTooltipState = @(state) haveTooltipStates.contains(state)

function getDebuffColor(data) {
  foreach (key, value in data)
    if (value)
      return key.contains("Dead") ? stateColors.dead : stateColors.bad
  return stateColors.ok
}

function getTooltip(data) {
  let res = []
  foreach (debuffName, value in data) {
    if (value && debuffName in tooltips)
      res.append(tooltips[debuffName])
  }
  return res
}

let getCrewTooltip = @(key, data) isHaveTooltipState(data?.state) ? key : ""
let getCrewColor = @(data) crewStateColors?[data?.state] ?? crewStateColors.ok

let tracksStateColor = Computed(@() getDebuffColor(tracksData.get()))
let turretDriveStateColor = Computed(@() getDebuffColor(turretDriveData.get()))
let gunStateColor = Computed(@() getDebuffColor(gunData.get()))
let engineStateColor = Computed(@() engineOverheatState.get() ? stateColors.overheat : getDebuffColor(engineData.get()))

let crewStateTextValue = Computed(@() crewState.get().current.tostring())
let crewStateTextColor = Computed(@() crewState.get().current <= MIN_CREW_COUNT_FOR_WARNING
  && crewState.get().total > MIN_CREW_COUNT_FOR_WARNING ? 0xFFC71400 : textCompColor)
let crewStateVisible = Computed(@() crewState.get().total > 0)
let crewStateRegeneratingVisible = Computed(@() crewState.get().regenerating)

let gunnerStateVisible = Computed(@() "state" in crewGunnerState.get())
let gunnerStateColor = Computed(@() getCrewColor(crewGunnerState.get()))
let gunnerStateWink = keepref(Computed(@() isTransferState(crewGunnerState.get()?.state)))

let driverStateVisible = Computed(@() "state" in crewDriverState.get())
let driverStateColor = Computed(@() getCrewColor(crewDriverState.get()))
let driverStateWink = keepref(Computed(@() isTransferState(crewDriverState.get()?.state)))

let drivingDirectionModeColor = Computed(@() drivingDirectionMode.get() ? drivingDirectionModeColorOn : drivingDirectionModeColorOff)

let distanceColor = Computed(@() roundToDigits(distance.get().distance, 2) == 1 ? stateColors.ok : stateColors.bad)


let stabilizerVisible = Computed(@() stabilizer.get() != -1)
let stabilizerState = Computed(function() {
  let value = stabilizer.get()
  return value == 2 ? "dmg"
    : value == 0 ? "off"
    : "on"
})

let lwsVisible = Computed(@() lws.get() != -1)
let lwsState = Computed(function() {
  let value = lws.get()
  return value == 2 ? "dmg"
    : value == 0 ? "off"
    : "on"
})

let ircmVisible = Computed(@() ircm.get() != -1)
let ircmState = Computed(function() {
  let value = ircm.get()
  return value == 3 ? "off"
    : value == 2 ? "dmg"
    : "on"
})

function calcRotatedPoint(width, angle) {
  let radius = 0.42 * width
  angle = PI * angle / 180
  return {
    x = sin(angle) * radius + width / 2
    y = width / 2 - cos(angle) * radius
  }
}

let mkTooltipText = @(text, ovr = {}) {
  maxWidth = sw(33)
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  font = fontsState.get("small")
  text
}.__update(ovr)

let mkTooltipContentCtor = @(state) @() @() mkTooltipText(
  "\n\n".join(getTooltip(state.get()).map(@(t) loc(t))),
  { watch = state })

let mkCrewTooltipContentCtor = @(state, key) @() function() {
  let tooltipText = getCrewTooltip(key, state.get())
  return mkTooltipText(tooltipText != "" ? loc(tooltipText) : "", { watch = state })
}

function mkTooltipParams(ctorOrLocId) {
  if (ctorOrLocId == null)
    return {}

  let key = {}
  let stateFlag = Watched(0)
  return {
    key
    behavior = Behaviors.Button
    onElemState = withTooltip(stateFlag, key,
      function() {
        let content = type(ctorOrLocId) == "function" ? ctorOrLocId() : mkTooltipText(loc(ctorOrLocId))
        if (calc_comp_size(content)[0] == 0)
          return null

        return {
          key
          content
          flowOffset = 0
          bgOvr = {
            fillColor = frameBackgroundColor
            borderColor = frameBorderColor
            borderWidth = 1
            padding = hdpx(6)
          }
        }
      }
    )
    onDetach = tooltipDetach(stateFlag, key)
  }
}

function getCompPosition(parentSize, cmpSize, angle) {
  let point = calcRotatedPoint(parentSize, angle)
  let compSizeArr = (typeof(cmpSize) == "array") ? cmpSize : [cmpSize, cmpSize]
  return [point.x - compSizeArr[0] / 2, point.y - compSizeArr[1] / 2]
}

let mkIconicComp = @(colorWatch, tooltipCtor, icon, angle, ovr = {}) @() {
  watch = [colorWatch, indicatorSize, compSize]
  size = compSize.get()
  pos = getCompPosition(indicatorSize.get(), compSize.get(), angle)
  rendObj = ROBJ_IMAGE
  image = Picture($"{icon}:{compSize.get()}:{compSize.get()}:P")
  color = colorWatch.get()
}.__update(ovr, mkTooltipParams(tooltipCtor))

let tracksStateComp = mkIconicComp(tracksStateColor, mkTooltipContentCtor(tracksData), "ui/gameuiskin#track_state_indicator.svg", -90)
let turretDriveStateComp = mkIconicComp(turretDriveStateColor, mkTooltipContentCtor(turretDriveData), "ui/gameuiskin#turret_gear_state_indicator.svg", -67.5)
let gunStateComp = mkIconicComp(gunStateColor, mkTooltipContentCtor(gunData), "ui/gameuiskin#gun_state_indicator.svg", -45)
let engineStateComp = mkIconicComp(engineStateColor, mkTooltipContentCtor(engineData), "ui/gameuiskin#engine_state_indicator.svg", -22.5, {
    animations = [{ prop = AnimProp.opacity, from = 1, to = 0.4, duration = 1.5, loop = true, easing = CosineFull, trigger = "engineOverheat" }]
  }
)

engineOverheatState.subscribe(@(v) v ? anim_start("engineOverheat") : anim_request_stop("engineOverheat"))

let fireStateComp = @() !fireState.get()?.burns ? { watch = fireState }
  : {
    watch = [fireState, indicatorSize, compSize]
    size = compSize.get()
    pos = getCompPosition(indicatorSize.get(), compSize.get(), -170)
    rendObj = ROBJ_IMAGE
    image = Picture($"ui/gameuiskin#fire_indicator.svg:{compSize.get()}:{compSize.get()}:P")
    color = stateColors.red
  }

function firstStageAmmoStateComp() {
  let { state = 0, amount = 0 } = firstStageAmmo.get()
  if (state <= 0)
    return {
      watch = firstStageAmmo
    }

  let ammoState = state == 2 ? "dmg"
    : amount > 0 ? "none"
    : "dead"

  let firstStageAmmoValueColor = firstStageAmmoStateValueColors?[ammoState] ?? firstStageAmmoStateValueColors.none

  return {
    watch = [firstStageAmmo, indicatorSize, fontParamsByScale, compSize]
    size = compSize.get()
    pos = getCompPosition(indicatorSize.get(), compSize.get(), 80)
    rendObj = ROBJ_IMAGE
    image = Picture($"ui/gameuiskin#icon_weapons_relocation_in_progress.svg:{compSize.get()}:{compSize.get()}:P")
    color = firstStageAmmoStateColors?[ammoState] ?? firstStageAmmoStateColors.none
    children = {
      size = [compSize.get() / 2, flex()]
      children = {
        rendObj = ROBJ_TEXT
        text = amount.tostring()
        color = firstStageAmmoValueColor
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
      }.__update(fontParamsByScale.get())
    }
  }.__update(mkTooltipParams("first_stage_ammo"))
}

let mkTextValueComp = @(locText, angle, fontParam) {
  halign = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  text = loc(locText)
  transform = {
    rotate = angle
  }
}.__update(fontParam, textShadowParams)

let mkTextComp = @(compVisible, compState, locText, angle) function() {
  if (!compVisible.get())
    return { watch = compVisible }

  let textComp = mkTextValueComp(locText, angle, fontParamsByScale.get())
  let cmpSize = calc_comp_size(textComp)

  return textComp.__update({
    watch = [fontParamsByScale, compVisible, compState, indicatorSize]
    pos = getCompPosition(indicatorSize.get(), cmpSize, angle)
    color = stateColors?[compState.get()] ?? stateColors.ok
  })
}

let stabilizerComp = mkTextComp(stabilizerVisible, stabilizerState, "HUD/TXT_STABILIZER", 0)
let lwsComp = mkTextComp(lwsVisible, lwsState, "HUD/TXT_LWS", 22.5)
let ircmComp = mkTextComp(ircmVisible, ircmState, "HUD/TXT_IRCM", 45)

let gearComp = @() {
  watch = [fontParamsByScale, gear]
  rendObj = ROBJ_TEXT
  text = $"{loc("HUD/GEAR_SHORT")} {gear.get()}"
  color = textCompColor
}.__update(fontParamsByScale.get())


let rpmComp = @() {
  watch = [fontParamsByScale, rpm]
  rendObj = ROBJ_TEXT
  text = $"{loc("HUD/RPM_SHORT")} {rpm.get()}"
  color = textCompColor
}.__update(fontParamsByScale.get())

function cruiseControlComp() {
  if (cruiseControlValue.get() == "")
    return {
      watch = cruiseControlValue
    }

  return {
    watch = [fontParamsByScale, cruiseControlValue]
    rendObj = ROBJ_TEXT
    text = $"{loc("HUD/CRUISE_CONTROL_SHORT")} {cruiseControlValue.get()}"
    color = textCompColor
  }.__update(fontParamsByScale.get())
}

let speedComp = {
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      watch = fontParamsByScale
      rendObj = ROBJ_TEXT
      text = loc("HUD/REAL_SPEED_SHORT")
      color = textCompColor
    }.__update(fontParamsByScale.get()),
    @() {
      watch = [fontParamsByScale, speed, hasSpeedWarning, isInitializedMeasureUnits, measureUnitsNames]
      rendObj = ROBJ_TEXT
      text = $" {speed.get()} {isInitializedMeasureUnits.get() ? loc(measureUnitsNames.get().speed) : ""}"
      color = speedStateValueColors[hasSpeedWarning.get() ? "bad" : "ok"]
    }.__update(fontParamsByScale.get())

  ]
}

let movementStateComp = {
  margin = [0, 0, shHud(0.3), shHud(0.6)]
  size = flex()
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  children = [
    gearComp
    rpmComp
    cruiseControlComp
    speedComp
  ]
}


function regenerationComp() {
  if (!crewStateRegeneratingVisible.get())
    return { watch = crewStateRegeneratingVisible }

  let regenCompSize = even(compSize.get() / 2)
  return {
    watch = [crewStateRegeneratingVisible, compSize]
    size = regenCompSize
    pos = [compSize.get() * 0.55, -regenCompSize / 2]
    rendObj = ROBJ_IMAGE
    image = Picture($"!ui/gameuiskin#healing.svg:{regenCompSize}:{regenCompSize}:P")
    color = stateColors.white
  }
}

function crewStateComp() {
  if (!crewStateVisible.get())
    return { watch = crewStateVisible }

  return {
    watch = [crewStateVisible, indicatorSize, fontParamsByScale, compSize]
    size = compSize.get()
    pos = [0, even(indicatorSize.get() * 0.64 - compSize.get() / 2)]
    rendObj = ROBJ_IMAGE
    image = Picture($"!ui/gameuiskin#crew.svg:{compSize.get()}:{compSize.get()}:P")
    color = stateColors.white

    children = [{
      size = compSize.get()
      pos = [compSize.get(), 0]
      children = @() {
        watch = [crewStateTextValue, crewStateTextColor]
        rendObj = ROBJ_TEXT
        text = crewStateTextValue.get()
        color = crewStateTextColor.get()
        hplace = ALIGN_LEFT
        vplace = ALIGN_BOTTOM
      }.__update(fontParamsByScale.get())
    }, regenerationComp]
  }.__update(mkTooltipParams("hud_tank_crew_members_count"))
}

let mkTimeBarComp = @(crewMemberState) function() {
  let timeBarVisible = isTransferState(crewMemberState.get()?.state)
  if (!timeBarVisible)
    return { watch = crewMemberState }

  let { totalTakePlaceTime = 0, timeToTakePlace = 0 } = crewMemberState.get()
  let from = (totalTakePlaceTime - timeToTakePlace) / totalTakePlaceTime

  return {
    watch = [crewMemberState, compSize]
    size = flex()
    children = {
      rendObj = ROBJ_PROGRESS_CIRCULAR
      image = Picture($"!ui/gameuiskin#timebar.svg:{compSize.get()}:{compSize.get()}:P")
      size = flex()
      bgColor = 0x0
      fgColor = stateColors.white
      animations = [{ prop = AnimProp.fValue, from, to = 1.0, duration = timeToTakePlace, play = true }]
    }
  }
}

function gunnerStateComp() {
  if (!gunnerStateVisible.get())
    return { watch = gunnerStateVisible }

  return {
    watch = [gunnerStateVisible, indicatorSize, compSize]
    size = compSize.get()
    pos = getCompPosition(indicatorSize.get(), compSize.get(), 105)
    children = [@() {
      watch = gunnerStateColor
      size = flex()
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#crew_gunner_indicator.svg:{compSize.get()}:{compSize.get()}:P")
      color = gunnerStateColor.get()
      animations = [{ prop = AnimProp.opacity, from = 1, to = 0.4, duration = 1.5, loop = true, easing = CosineFull, trigger = "gunnerStateWink" }]
    }, mkTimeBarComp(crewGunnerState)]
  }.__update(mkTooltipParams(mkCrewTooltipContentCtor(crewGunnerState, "hud_tank_crew_gunner_out_of_action")))
}

gunnerStateWink.subscribe(@(v) v ? anim_start("gunnerStateWink") : anim_request_stop("gunnerStateWink"))

function drivingDirectionModeComp() {
  let ddmCompSize = even(0.17 * compSize.get())
  return {
    watch = [drivingDirectionModeColor, compSize]
    size = ddmCompSize
    pos = [compSize.get() - ddmCompSize, 0]
    rendObj = ROBJ_IMAGE
    image = Picture($"!ui/gameuiskin#squad_status.svg:{ddmCompSize}:{ddmCompSize}:P")
    color = drivingDirectionModeColor.get()
  }.__update(mkTooltipParams("hotkeys/ID_ENABLE_GM_DIRECTION_DRIVING"))
}

function driverStateComp() {
  if (!driverStateVisible.get())
    return { watch = driverStateVisible }

  return {
    watch = [driverStateVisible, indicatorSize, compSize]
    size = compSize.get()
    pos = getCompPosition(indicatorSize.get(), compSize.get(), 135)
    children = [@() {
      watch = driverStateColor
      size = flex()
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#crew_driver_indicator.svg:{compSize.get()}:{compSize.get()}:P")
      color = driverStateColor.get()
      animations = [{ prop = AnimProp.opacity, from = 1, to = 0.4, duration = 1.5, loop = true, easing = CosineFull, trigger = "driverStateWink" }]
    }, mkTimeBarComp(crewDriverState), drivingDirectionModeComp]
  }.__update(mkTooltipParams(mkCrewTooltipContentCtor(crewDriverState, "hud_tank_crew_driver_out_of_action")))
}

driverStateWink.subscribe(@(v) v ? anim_start("driverStateWink") : anim_request_stop("driverStateWink"))

let distanceBarComp = @() {
  watch = [distance, compSize]
  size = flex()
  rendObj = ROBJ_PROGRESS_CIRCULAR
  image = Picture($"!ui/gameuiskin#timebar.svg:{compSize.get()}:{compSize.get()}:P")
  bgColor = 0x0
  fgColor = stateColors.white
  fValue = distance.get().distance < 1 ? roundToDigits(distance.get().distance, 2) : 0
}

let mkDistanceTooltipContentCtor = @(state, key)
  @() @() mkTooltipText(state.get().distance < 1 ? loc(key, { distance = state.get().distance * 100 }) : "", { watch = state })

function distanceComp() {
  return {
    watch = [indicatorSize, compSize]
    size = compSize.get()
    pos = getCompPosition(indicatorSize.get(), compSize.get(), 165)
    children = [@() {
      watch = distanceColor
      size = flex()
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#overview_icon.svg:{compSize.get()}:{compSize.get()}:P")
      color = distanceColor.get()
    },
    distanceBarComp,
    {
      rendObj = ROBJ_IMAGE
      image = Picture($"!ui/gameuiskin#timebar.svg:{compSize.get()}:{compSize.get()}:P")
      size = flex()
      color = crewStateColors.ok
    }]
  }.__update(mkTooltipParams(mkDistanceTooltipContentCtor(distance, "hud_tank_crew_distance")))
}

let tankDebuffs = @() {
  watch = dmgIndicatorStates
  size = dmgIndicatorStates.get().size
  onAttach = function(_) {
    reInitTankDebuffsStates()
    reInitHudCrewStates()
  }
  children = [
    tracksStateComp
    turretDriveStateComp
    gunStateComp
    engineStateComp
    fireStateComp
    firstStageAmmoStateComp
    stabilizerComp
    lwsComp
    ircmComp
    movementStateComp
    crewStateComp
    gunnerStateComp
    driverStateComp
    distanceComp
  ]
}

return {
  tankDebuffs
}
