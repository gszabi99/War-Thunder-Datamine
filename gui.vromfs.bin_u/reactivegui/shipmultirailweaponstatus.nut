from "%rGui/globals/ui_library.nut" import *
from "%rGui/shipFireControlCommon.nut" import mkCircle, mkStatusCircleImage, weaponPalette
from "%rGui/weaponReserveAmmo.nut" import mkReserveBlock
from "%sqstd/math.nut" import lerpClamped
from "mission" import get_mission_time

const INNER_CIRCLE_FRAC = 0.7
const MAX_DISPLAYED_RAILS = 5

const railRingSize = hdpxi(30)
const rowIconSize = hdpxi(46)
const weaponGap = hdpx(6)
const stackGap = hdpx(2)

let ringSizeArr = [railRingSize, railRingSize]
let innerSize = (railRingSize * INNER_CIRCLE_FRAC).tointeger()
let mkRingImages = @() array(MAX_DISPLAYED_RAILS).map(@(_, i)
  Picture($"+ui/gameuiskin#torpedo_tube_{i + 1}.svg:{railRingSize}:{railRingSize}:P"))

let mkRailsRing = @(weaponState, innerCircleImg, ringImages) function() {
  let st = weaponState.get()
  let { tubeCount, loadedCount, startTime, endTime, isOperable } = st
  if (tubeCount <= 0)
    return { watch = weaponState }

  let count = min(tubeCount, MAX_DISPLAYED_RAILS)
  let loaded = clamp(loadedCount, 0, count)
  let palette = weaponPalette(st)
  let curTime = get_mission_time()
  let isReloading = isOperable && loaded < count
    && endTime > startTime && endTime > curTime

  return {
    watch = weaponState
    size = ringSizeArr
    children = [
      mkCircle(innerSize, palette.spent, innerCircleImg)
      {
        key = {}
        size = flex()
        rendObj = ROBJ_PROGRESS_CIRCULAR
        image = ringImages[count - 1]
        fgColor = palette.ready
        bgColor = palette.spent
        fValue = isReloading ? (loaded + 1.0) / count : loaded.tofloat() / count
        animations = !isReloading ? null : [{
          prop = AnimProp.fValue
          from = (loaded + lerpClamped(startTime, endTime, 0.0, 1.0, curTime)) / count
          duration = endTime - curTime
          play = true
        }]
      }
    ]
  }
}

function mkMultiRailWeaponStatus(weaponState, showReserveRow, innerCircleImg, ringImages) {
  return {
    flow = FLOW_VERTICAL
    gap = stackGap
    halign = ALIGN_CENTER
    children = [
      mkRailsRing(weaponState, innerCircleImg, ringImages)
      showReserveRow ? mkReserveBlock(weaponState) : null
    ]
  }
}

function mkMultiRailWeaponsStatus(statesArray, trigger, icon) {
  return function() {
    let count = statesArray.len()
    if (count <= 0)
      return { watch = trigger }

    let showReserveRow = statesArray.findvalue(@(v) v.get().reserveTotal > 0) != null
    let innerCircleImg = mkStatusCircleImage(innerSize)
    let ringImages = mkRingImages()

    let children = [
      {
        size = rowIconSize
        rendObj = ROBJ_IMAGE
        image = Picture($"{icon}:{rowIconSize}:{rowIconSize}")
      }
    ]

    for (local i = 0; i < count; ++i)
      children.append(mkMultiRailWeaponStatus(statesArray[i], showReserveRow, innerCircleImg, ringImages))

    return {
      watch = trigger
      gap = weaponGap
      flow = FLOW_HORIZONTAL
      valign = showReserveRow ? ALIGN_TOP : ALIGN_CENTER
      children
    }
  }
}

return freeze({
  mkMultiRailWeaponsStatus
})
