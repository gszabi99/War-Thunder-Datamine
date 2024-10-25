from "%rGui/globals/ui_library.nut" import *

let { floor } = require("math")
let { battlesInfo, hoveredBattle, getBattleIconData, getBattleState } = require("%rGui/wwMap/wwBattlesStates.nut")
let { convertToRelativeMapCoords, activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")

let function mkBattleIcon(battleInfo, areaBounds) {
  return function() {
    let battleStatus = getBattleState(battleInfo)
    if(battleStatus == "Ended")
      return null

    let isBattleHovered = Computed(@() hoveredBattle.get() == battleInfo.name)
    let { areaWidth, areaHeight } = areaBounds
    let iconData = getBattleIconData(battleStatus)
    let battlePos = convertToRelativeMapCoords(battleInfo.pos)
    let battleIconSize = floor(areaWidth * iconData.iconSize)
    let battleIconPos = [areaWidth * battlePos.x - battleIconSize / 2, areaHeight * battlePos.y - battleIconSize / 2]

    let icon = isBattleHovered.get() ? iconData.iconHovered : iconData.icon
    let color = isBattleHovered.get() ? iconData.colorHovered : iconData.color

    return {
      watch = isBattleHovered
      rendObj = ROBJ_IMAGE
      keepAspect = true
      pos = battleIconPos
      size = [battleIconSize, battleIconSize]
      image = Picture($"{icon}:{battleIconSize}:{battleIconSize}")
      color
    }
  }
}

function battles() {
  if (battlesInfo.get().len() == 0)
    return {
      watch = [battlesInfo, activeAreaBounds]
    }

  return {
    watch = [battlesInfo, activeAreaBounds]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = battlesInfo.get().map(@(battleInfo) mkBattleIcon(battleInfo, activeAreaBounds.get()))
  }
}

return {
  battles
}