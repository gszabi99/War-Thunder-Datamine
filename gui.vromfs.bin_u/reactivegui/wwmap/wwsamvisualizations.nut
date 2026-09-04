from "%rGui/wwMap/wwArtilleryStrikeStates.nut" import samStrikesInfo
from "%appGlobals/worldWar/wwSettings.nut" import getSettings
from "%rGui/wwMap/wwMapUtils.nut" import convertColor4
from "%rGui/wwMap/wwOperationConfiguration.nut" import convertToRelativeMapCoords, activeAreaBounds, mapZoom
from "%rGui/wwMap/wwArmyStates.nut" import movingArmiesPositions, getArmyByName
from "%rGui/globals/ui_library.nut" import *

local samLineColor = null
local samLineColor2 = null
local samLineWidthK = null

function mkSamVisualization(strikeInfo, areaBounds, mpZoom) {
  let { army, forcedTargetArmyName, radius } = strikeInfo
  let forcedTargetPosition = Computed(function() {
    local pos = movingArmiesPositions.get()?[forcedTargetArmyName]
    if (pos != null)
      return pos
    let forcedTarget = getArmyByName(forcedTargetArmyName)
    return convertToRelativeMapCoords(forcedTarget.pathTracker.pos)
  })

  return function() {
    let artilleryPosition = convertToRelativeMapCoords(army.pathTracker.pos)
    let artilleryStrikeSettings = getSettings("artilleryStrike")

    if (samLineColor == null)
      samLineColor = convertColor4(artilleryStrikeSettings.samLineColor)
    if (samLineColor2 == null)
      samLineColor2 = convertColor4(artilleryStrikeSettings.samLineColor2)
    if (samLineWidthK == null)
      samLineWidthK = artilleryStrikeSettings.samLineWidthK

    let circleBlinkPeriod = artilleryStrikeSettings.circleBlinkPeriod
    let strikeSize = radius * 2 * mpZoom
    let command = [VECTOR_LINE, 100 * artilleryPosition.x, 100 * artilleryPosition.y, 100 * forcedTargetPosition.get().x, 100 * forcedTargetPosition.get().y]

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      watch = forcedTargetPosition
      color = samLineColor
      size = areaBounds.size
      lineWidth = strikeSize * samLineWidthK
      commands = [command]
      animations = [{ prop = AnimProp.color, from = samLineColor, to = samLineColor2,
        duration = circleBlinkPeriod, loop = true, easing = CosineFull, play = true }]
    }
  }
}

let samVisualizations = @() {
    watch = [samStrikesInfo, activeAreaBounds, mapZoom]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = samStrikesInfo.get()
      .map(@(samStrikeInfo) mkSamVisualization(samStrikeInfo, activeAreaBounds.get(), mapZoom.get()))
  }

return {
  samVisualizations
}
