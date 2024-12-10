from "%rGui/globals/ui_library.nut" import *

let { floor } = require("math")
let { artilleryStrikesInfo, samStrikesInfo } = require("%rGui/wwMap/wwArtilleryStrikeStates.nut")
let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { convertColor4 } = require("%rGui/wwMap/wwMapUtils.nut")
let { convertToRelativeMapCoords, activeAreaBounds, mapZoom } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { movingArmiesPositions, getArmyByName } = require("%rGui/wwMap/wwArmyStates.nut")

local circleColor = null
local circleColor2 = null

let function mkArtilleryStrike(strikeInfo, areaBounds, mpZoom) {
  let { strikePos, radius, strikesDone } = strikeInfo

  if (strikesDone < 0)
    return null

  let { areaWidth, areaHeight } = areaBounds
  let armyPos = convertToRelativeMapCoords(strikePos)

  let artilleryStrikeSettings = getSettings("artilleryStrike")
  let crossTexture = artilleryStrikeSettings.crossTexture
  let crossColor = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor : artilleryStrikeSettings.crossFireingColor)
  let crossColor2 = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor2 : artilleryStrikeSettings.crossFireingColor2)

  if (circleColor == null)
    circleColor = convertColor4(artilleryStrikeSettings.circleColor)
  if (circleColor2 == null)
    circleColor2 = convertColor4(artilleryStrikeSettings.circleColor2)

  let circleBlinkPeriod = artilleryStrikeSettings.circleBlinkPeriod
  let strikeSize = radius * 2 * mpZoom
  let size = [strikeSize, strikeSize]
  let pos = [areaWidth * armyPos.x - strikeSize / 2, areaHeight * armyPos.y - strikeSize / 2]

  return {
    rendObj = ROBJ_BOX
    pos
    size
    borderWidth = hdpx(2)
    borderRadius = strikeSize / 2
    animations = [{ prop = AnimProp.borderColor, from = circleColor, to = circleColor2,
      duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]

    children = {
      rendObj = ROBJ_IMAGE
      key = {}
      opacity = strikesDone > 0 ? 1 : 0
      size
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      keepAspect = true
      image = Picture($"{crossTexture}:{floor(strikeSize)}:{floor(strikeSize)}")
      animations = [{ prop = AnimProp.color, from = crossColor, to = crossColor2,
         duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]
    }
  }
}

function mkSAMStrike(strikeInfo, areaBounds, mpZoom) {
  let { forcedTargetArmyName, radius, strikesDone } = strikeInfo
  let forcedTargetPosition = Computed(function() {
    local pos = movingArmiesPositions.get()?[forcedTargetArmyName]
    if (pos != null)
      return pos
    let forcedTarget = getArmyByName(forcedTargetArmyName)
    return convertToRelativeMapCoords(forcedTarget.pathTracker.pos)
  })

  return function() {
    let { areaWidth, areaHeight } = areaBounds

    let artilleryStrikeSettings = getSettings("artilleryStrike")
    let crossTexture = artilleryStrikeSettings.crossTexture
    let crossColor = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor : artilleryStrikeSettings.crossFireingColor)
    let crossColor2 = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor2 : artilleryStrikeSettings.crossFireingColor2)

    if (circleColor == null)
      circleColor = convertColor4(artilleryStrikeSettings.circleColor)
    if (circleColor2 == null)
      circleColor2 = convertColor4(artilleryStrikeSettings.circleColor2)

    let circleBlinkPeriod = artilleryStrikeSettings.circleBlinkPeriod
    let strikeSize = radius * 2 * mpZoom
    let size = [strikeSize, strikeSize]
    let pos = [areaWidth * forcedTargetPosition.get().x - strikeSize / 2, areaHeight * forcedTargetPosition.get().y - strikeSize / 2]

    return {
      rendObj = ROBJ_BOX
      watch = forcedTargetPosition
      pos
      size
      borderWidth = hdpx(2)
      borderRadius = strikeSize / 2
      animations = [{ prop = AnimProp.borderColor, from = circleColor, to = circleColor2,
        duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]

      children = {
        rendObj = ROBJ_IMAGE
        key = {}
        opacity = strikesDone > 0 ? 1 : 0
        size
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        keepAspect = true
        image = Picture($"{crossTexture}:{floor(strikeSize)}:{floor(strikeSize)}")
        animations = [{ prop = AnimProp.color, from = crossColor, to = crossColor2,
          duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]
      }
    }
  }
}

let artilleryStrikes = @() {
    watch = [artilleryStrikesInfo, samStrikesInfo, activeAreaBounds, mapZoom]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = artilleryStrikesInfo.get()
      .map(@(strikeInfo) mkArtilleryStrike(strikeInfo, activeAreaBounds.get(), mapZoom.get()))
      .extend(samStrikesInfo.get()
        .map(@(samStrikeInfo) mkSAMStrike(samStrikeInfo, activeAreaBounds.get(), mapZoom.get()))
      )
  }

return {
  artilleryStrikes
}