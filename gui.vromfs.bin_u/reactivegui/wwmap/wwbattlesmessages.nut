from "%rGui/globals/ui_library.nut" import *

let { floor } = require("math")
let { getPlayerSideStr, isPlayerSideStr } = require("%rGui/wwMap/wwOperationStates.nut")
let { getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { battlesInfo, getBattleState } = require("%rGui/wwMap/wwBattlesStates.nut")
let { convertToRelativeMapCoords, activeAreaBounds, mapZoom } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { getArmyIcon } = require("%rGui/wwMap/wwArmyStates.nut")
let { getArmyGroupsInfo } = require("%rGui/wwMap/wwArmyGroups.nut")
let { wwGetOperationTimeMillisec } = require("worldwar")
let fontsState = require("%rGui/style/fontsState.nut")

let battleResults = {}

function setBattleMessagesHideTime(battleName) {
  if(battleResults?[battleName] == null)
    battleResults[battleName] <- wwGetOperationTimeMillisec() + getSettings("battleRemovalShowMs")
}

function getBattleMessagesHideTime(battleName) {
  return battleResults?[battleName]
}

function mkBattleResultArrow(boxSize, isDown = true) {
  let size = static [hdpx(12), hdpx(5)]
  let pos = [
    (boxSize[0] - size[0]) / 2,
    isDown ? boxSize[1] + hdpx(1) : -size[1] - hdpx(1)
  ]
  let image = getSettings("battleResultMessageArrow")
  return {
    rendObj = ROBJ_IMAGE
    pos
    size
    image = Picture($"{image}:{size[0]}:{size[1]}")
    transform = {
      pivot = [0.5, 0.5]
      rotate = isDown ? 0 : 180
    }
  }
}

function mkBattleResult(battleInfo, areaBounds) {
  let isPlayerWinner = getPlayerSideStr() == battleInfo.winner
  let text = getSettings(isPlayerWinner ? "battleMsgWin" : "battleMsgFail")
  let textColor = getMapColor(isPlayerWinner ? "battleMsgWinColor" : "battleMsgFailColor")

  let battleResultText = {
    rendObj = ROBJ_TEXT
    text = loc(text)
    color = textColor
    font = fontsState.get("medium")
  }

  let textPadding = hdpx(5)
  let textCompSize = calc_comp_size(battleResultText)
  let battleResultBoxSize = [floor(max(textCompSize[0] + textPadding, hdpx(150))), floor(textCompSize[1] + textPadding + hdpx(6))]
  let { areaWidth, areaHeight } = areaBounds
  let battlePos = convertToRelativeMapCoords(battleInfo.pos)
  let shift = hdpx(30)

  let battleResultBoxPos = [
    areaWidth * battlePos.x - battleResultBoxSize[0] / 2,
    areaHeight * battlePos.y - battleResultBoxSize[1] - shift
  ]

  let image = getSettings("battleResultMessageBackground")
  let hideDelay = (getBattleMessagesHideTime(battleInfo.name) - wwGetOperationTimeMillisec()) / 1000

  return {
    rendObj = ROBJ_9RECT
    pos = battleResultBoxPos
    size = battleResultBoxSize
    image = Picture($"{image}:{battleResultBoxSize[0]}:{battleResultBoxSize[1]}")
    screenOffs = [hdpx(3), hdpx(3), hdpx(3), hdpx(3)]
    texOffs = [3, 3, 3, 3]
    children = [
      battleResultText.__update({ vplace = ALIGN_CENTER hplace = ALIGN_CENTER }),
      mkBattleResultArrow(battleResultBoxSize)
    ]
    opacity = 0
    animations = [
      { prop = AnimProp.opacity, from = 1, to = 1, duration = hideDelay, play = true }
      { prop = AnimProp.opacity, from = 1, to = 0, duration = 1, delay = hideDelay, play = true }
    ]
  }
}

function mkBattleDetroyedArmy(battleInfo, areaBounds, mpZoom) {
  if(battleInfo.armiesAfterBattle.len() == 0)
    return null

  let armiesAfterBattle = battleInfo.armiesAfterBattle.map(function(army) {
    let { side, armyGroupIdx } = army
    let armyIcon = getArmyIcon(army)
    let armyIconSize = floor(armyIcon.iconSize * mpZoom)

    let armyColor = !isPlayerSideStr(side) ? "enemiesArmyColor"
    : getArmyGroupsInfo()[armyGroupIdx].side == side ? "ownedArmyColor"
    : "alliesArmyColor"

    return {
      flow = FLOW_HORIZONTAL
      children = [
        {
          rendObj = ROBJ_IMAGE
          keepAspect = true
          size = [armyIconSize, armyIconSize]
          image = Picture($"{armyIcon.iconName}:{armyIconSize}:{armyIconSize}")
          color = getMapColor(armyColor)
        },
        {
          rendObj = ROBJ_TEXT
          text = loc(getSettings("battleMsgArmyWasDestroyed"))
          vplace = ALIGN_CENTER
          color = Color(255, 255, 225, 255)
          font = fontsState.get("medium")
        }
      ]
    }
  })

  let armiesAfterBattleContent = {
    flow = FLOW_VERTICAL
    children = armiesAfterBattle
  }

  let textPadding = hdpx(5)
  let armiesCompSize = calc_comp_size(armiesAfterBattleContent)
  let battleResultBoxSize = [armiesCompSize[0] + textPadding, armiesCompSize[1] + textPadding]
  let { areaWidth, areaHeight } = areaBounds
  let battlePos = convertToRelativeMapCoords(battleInfo.pos)

  let shift = hdpx(30)

  let battleResultBoxPos = [
    areaWidth * battlePos.x - battleResultBoxSize[0] / 2,
    areaHeight * battlePos.y + shift
  ]

  let image = getSettings("battleResultMessageBackground")
  let hideDelay = (getBattleMessagesHideTime(battleInfo.name) - wwGetOperationTimeMillisec()) / 1000

  return {
    rendObj = ROBJ_9RECT
    pos = battleResultBoxPos
    size = battleResultBoxSize
    image = Picture($"{image}:{battleResultBoxSize[0]}:{battleResultBoxSize[1]}")
    screenOffs = [hdpx(3), hdpx(3), hdpx(3), hdpx(3)]
    texOffs = [3, 3, 3, 3]
    children = [
      armiesAfterBattleContent.__update({ vplace = ALIGN_CENTER, hplace = ALIGN_CENTER }),
      mkBattleResultArrow(battleResultBoxSize, false)
    ]
    opacity = 0
    animations = [
      { prop = AnimProp.opacity, from = 1, to = 1, duration = hideDelay, play = true }
      { prop = AnimProp.opacity, from = 1, to = 0, duration = 1, delay = hideDelay, play = true }
    ]
  }
}

function mkBattleMessages(battleInfo, areaBounds, mpZoom) {
  if(getBattleState(battleInfo) != "Ended")
    return null

  let time = getBattleMessagesHideTime(battleInfo.name)
  if(time != null && wwGetOperationTimeMillisec() > time)
    return  null

  setBattleMessagesHideTime(battleInfo.name)
  return {
    children = [mkBattleResult(battleInfo, areaBounds), mkBattleDetroyedArmy(battleInfo, areaBounds, mpZoom)]
  }
}

let mkBattlesMessages = function() {
  if (battlesInfo.get().len() == 0)
    return {
      watch = [battlesInfo, activeAreaBounds, mapZoom]
    }

  return {
    watch = [battlesInfo, activeAreaBounds, mapZoom]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = battlesInfo.get().map(@(battleInfo) mkBattleMessages(battleInfo, activeAreaBounds.get(), mapZoom.get()))
  }
}

return {
  mkBattlesMessages
}