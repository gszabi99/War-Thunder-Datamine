from "%rGui/globals/ui_library.nut" import *
from "math" import fabs

let { humanCurGunInfo, humanCurGunModeInfo } = require("%rGui/hud/state/human_gun_info_es.nut")
let { canSightChange } = require("%appGlobals/hud/humanPhysState.nut")
let { hud, transparent } = require("%rGui/style/colors.nut")
let { infantryHudInactiveColor, infantryHudActiveColor } = hud
let { measureUnitsCfg, DISTANCE_SHORT } = require("%rGui/options/measureUnits.nut")

let sightPresetsData = Computed(@()
  humanCurGunModeInfo.get()?.activeModWeapon?.sightPresetsData
  ?? humanCurGunInfo.get()?.sightPresetsData
  ?? [])
let currentPresetIdx = Computed(@()
  humanCurGunModeInfo.get()?.activeModWeapon?.currentSightPreset
  ?? humanCurGunInfo.get()?.currentSightPreset
  ?? 0)

let presetPadding = const [hdpxi(1), hdpxi(6)]
let lineHeight = hdpxi(16)
let presetGap = hdpxi(2)
let stepHeight = lineHeight + presetGap

let visibleCount = 3
let sideCount = (visibleCount / 2.0).tointeger()

let animViscosity = 0.1
let animInterval = 1.0 / 60
let animMult = 1.0 - clamp(animInterval / animViscosity, 0.0, 1.0)

let animOffset = Watched(0.0)
local prevPresetIdx = 0

let cachedLocName = {}
let cacheVersion = Watched(0)



let lastDistanceShortName = keepref(Computed(function() {
  measureUnitsCfg.get() 

  return DISTANCE_SHORT.getMeasureUnitsName()
}))
lastDistanceShortName.subscribe(function(_k) {
  cachedLocName.clear()
  cacheVersion.modify(@(v) v + 1)
})


function updateAnim() {
  let cur = animOffset.get()
  if (cur > -0.01 && cur < 0.01) {
    animOffset.set(0.0)
    gui_scene.clearTimer(updateAnim)
    return
  }

  animOffset.set(cur * animMult)
}

function onPresetChange(v) {
  let count = sightPresetsData.get().len()
  if (count <= 1)
    return

  let rawDelta = v - prevPresetIdx
  local delta = rawDelta
  let wrapFwd = rawDelta + count
  let wrapBwd = rawDelta - count
  if ((wrapFwd > 0 ? wrapFwd : -wrapFwd) < (delta > 0 ? delta : -delta))
    delta = wrapFwd
  if ((wrapBwd > 0 ? wrapBwd : -wrapBwd) < (delta > 0 ? delta : -delta))
    delta = wrapBwd

  prevPresetIdx = v
  animOffset.set(animOffset.get() + delta.tofloat())

  gui_scene.clearTimer(updateAnim)
  gui_scene.setInterval(animInterval, updateAnim)
}

let animEffect = {
  key = "sightPresetsAnimEffect"
  size = const [0, 0]
  onAttach = function() {
    prevPresetIdx = currentPresetIdx.get()
    currentPresetIdx.subscribe(onPresetChange)
  }
  onDetach = function() {
    currentPresetIdx.unsubscribe(onPresetChange)
    gui_scene.clearTimer(updateAnim)
    animOffset.set(0.0)
  }
}

function colorFromDist(distVal) {
  let dist = fabs(distVal)
  if (dist > (sideCount + 0.5))
    return transparent
  return (dist < 0.5) ? infantryHudActiveColor : infantryHudInactiveColor
}

function mkPresetLine(text, fractionalSlot) {
  return {
    size = [SIZE_TO_CONTENT, lineHeight]
    pos = [0, (fractionalSlot * stepHeight).tointeger() - lineHeight / 2]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = {
      rendObj = ROBJ_TEXT
      text
      color = colorFromDist(fractionalSlot)
      font = Fonts.very_tiny_text_hud
    }
  }
}

let selectionFrame = {
  size = [flex(), lineHeight]
  rendObj = ROBJ_BOX
  borderWidth = hdpxi(1)
  borderColor = infantryHudActiveColor
  vplace = ALIGN_CENTER
  padding = presetPadding
}

function getCachedDistanceLocName(sightData) {
  let { distance = 0, locId = "" } = sightData
  let locIdCheck = distance == 0 ? locId : distance
  if (locIdCheck in cachedLocName)
    return cachedLocName[locIdCheck]

  let locText = distance == 0 ? loc(locId) : DISTANCE_SHORT.getMeasureUnitsText(distance)
  cachedLocName[locIdCheck] <- locText
  return locText
}

function mkSightLines() {
  let sightPresetsDataVal = sightPresetsData.get()
  let count = sightPresetsDataVal.len()
  let lines = []

  let window = min(sideCount + 1, count / 2)
  for (local s = -window; s <= window; s++) {
    let idx = (currentPresetIdx.get() + s + count) % count
    lines.append(mkPresetLine(getCachedDistanceLocName(sightPresetsDataVal[idx]), s + animOffset.get()))
  }

  return {
    watch = [ sightPresetsData, currentPresetIdx, animOffset, cacheVersion ]
    size = [SIZE_TO_CONTENT, 0]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = lines
  }
}

return @() !canSightChange.get() || sightPresetsData.get().len() < 2
  ? { watch = [ canSightChange, sightPresetsData ] }
  : {
      watch = [ canSightChange, sightPresetsData ]
      size = [SIZE_TO_CONTENT, stepHeight * visibleCount]
      pos = [-shHud(12), 0]
      clipChildren = true
      halign = ALIGN_RIGHT
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children = [
        animEffect
        mkSightLines
        selectionFrame
      ]
    }