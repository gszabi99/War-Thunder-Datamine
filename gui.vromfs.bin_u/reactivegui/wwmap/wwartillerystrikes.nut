from "%rGui/globals/ui_library.nut" import *

let { artilleryStrikesInfo } = require("%rGui/wwMap/wwArtilleryStrikeStates.nut")
let { getSettings } = require("%rGui/wwMap/wwSettings.nut")
let { convertColor4 } = require("%rGui/wwMap/wwMapUtils.nut")
let { convertToRelativeMapCoords, activeAreaBounds, mapZoom } = require("%rGui/wwMap/wwOperationConfiguration.nut")

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
  let crossSize = hdpx(48)
  let crossColor = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor : artilleryStrikeSettings.crossFireingColor)
  let crossColor2 = convertColor4(strikesDone == 0 ? artilleryStrikeSettings.crossColor2 : artilleryStrikeSettings.crossFireingColor2)

  if (circleColor == null)
    circleColor = convertColor4(getSettings("artilleryStrike").circleColor)
  if (circleColor2 == null)
    circleColor2 = convertColor4(getSettings("artilleryStrike").circleColor2)

  let circleBlinkPeriod = artilleryStrikeSettings.circleBlinkPeriod

  let strikeSize = radius * 2 * mpZoom

  let size = [strikeSize, strikeSize]
  let pos = [areaWidth * armyPos.x - size[0] / 2, areaHeight * armyPos.y - size[1] / 2]

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
      size = [crossSize, crossSize]
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      keepAspect = true
      image = Picture($"{crossTexture}:{crossSize}:{crossSize}")
      animations = [{ prop = AnimProp.color, from = crossColor, to = crossColor2,
         duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]
    }
  }
}

let artilleryStrikes = @() {
    watch = [artilleryStrikesInfo, activeAreaBounds, mapZoom]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = artilleryStrikesInfo.get().map(
        @(strikeInfo) mkArtilleryStrike(strikeInfo, activeAreaBounds.get(), mapZoom.get())
      )
  }

return {
  artilleryStrikes
}