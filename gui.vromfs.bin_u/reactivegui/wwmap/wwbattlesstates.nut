from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { fabs } = require("math")
let { wwGetBattlesInfo } = require("worldwar")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { sendToDagui, getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { getMapAspectRatio, convertToRelativeMapCoords } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { getSettings } = require("%rGui/wwMap/wwSettings.nut")
let { getPlayerSideStr } = require("%rGui/wwMap/wwOperationStates.nut")
let { getArtilleryUnits, getInfantryUnits } = require("%rGui/wwMap/wwConfigurableValues.nut")
let { battleStates } = require("%rGui/wwMap/wwMapTypes.nut")

let battlesInfo = Watched([])
let hoveredBattle = Watched("")

function updateBattlesStates() {
  let bi = DataBlock()
  wwGetBattlesInfo(bi)

  let count = bi?.battles.blockCount() ?? 0
  let battlesData = []
  for (local i = 0; i < count; i++) {
    let battle = bi.battles.getBlock(i)
    let teamsCount = battle.teams.blockCount()
    let teams = {}
    local winner = "NONE"

    for (local t = 0; t < teamsCount; t++) {
      let team = battle.teams.getBlock(t)
      let unitsRemainCount = team.unitsRemain.blockCount()
      let unitsRemain = []
      for (local u = 0; u < unitsRemainCount; u++) {
        let unit = team.unitsRemain.getBlock(u)
        unitsRemain.append({
          name = unit.getBlockName()
          count = unit.count
        })
      }
      teams[team.side] <- {
        players = team.players
        maxPlayers = team.maxPlayers
        unitsRemain
      }
      if(team.isWinner)
        winner = team.side
    }

    let armiesAfterBattle = []
    let armiesAfterBattleBlk = battle.desc.armiesAfterBattle
    let armiesAfterBattleCount = armiesAfterBattleBlk.blockCount()
    for (local aab = 0; aab < armiesAfterBattleCount; aab++) {
      let army = armiesAfterBattleBlk.getBlock(aab)
      if(army.state != "EASAB_DEAD")
        continue
      let armyAfterBattle = {
        unitType = army.unitType
        iconOverride = army.iconOverride
        side = army.owner.side
        armyGroupIdx = army.owner.armyGroupIdx
      }
      armiesAfterBattle.append(armyAfterBattle)
    }

    battlesData.append({
      name = battle.getBlockName()
      status = battle.status
      pos = battle.pos
      iconSize = 0
      teams
      armiesAfterBattle
      winner
    })
  }

  if (isEqual(battlesData, battlesInfo.get()))
    return

  battlesInfo.set(battlesData)
}

let getBattleIconData = memoize(@(battleState) {
  color = getMapColor($"battleColor{battleState}")
  colorHovered = getMapColor($"hoveredBattleColor{battleState}")
  icon = $"{getSettings($"battleTex{battleState}")}.svg"
  iconHovered = $"{getSettings($"battleTexHovered{battleState}")}.svg"
  iconSize = getSettings($"battleIconSize{battleState}") * 0.5
})

function isBattleOutOfPlayerSlots(battleInfo) {
  let team = battleInfo.teams[getPlayerSideStr()]
  let numPlayers = team.players
  let maxPlayers = team.maxPlayers
  return numPlayers >= maxPlayers
}

function isBattleOutOfAvailableUnits(battleInfo) {
  let team = battleInfo.teams[getPlayerSideStr()]
  let units = team.unitsRemain

  let infantryUnits = getInfantryUnits()
  let artilleryUnits = getArtilleryUnits()

  for(local i = 0; i < units.len(); i++) {
    if (units[i].name in infantryUnits || units[i].name in artilleryUnits)
      continue
    if (units[i].count > 0)
      return false
  }
  return true
}

function getBattleState(battleInfo) {
  if (battleInfo.status == "EBS_ACTIVE_STARTING" || battleInfo.status == "EBS_ACTIVE_MATCHING")
    return battleStates.ACTIVE
  else if (battleInfo.status == "EBS_ACTIVE_FAKE" || battleInfo.status == "EBS_ACTIVE_AUTO")
    return battleStates.FAKE
  else if (battleInfo.status == "EBS_ACTIVE_CONFIRMED")
    return battleStates.STARTED

  if (isBattleOutOfPlayerSlots(battleInfo) || isBattleOutOfAvailableUnits(battleInfo))
      return battleStates.FULL
  else if (battleInfo.status == "EBS_FINISHED_APPLIED")
    return battleStates.ENDED

  return battleStates.INACTIVE
}

function getBattleByPoint(point) {
  let aspectRatio = getMapAspectRatio()
  let battlesData = battlesInfo.get()

  return battlesData
    .findvalue(function(battleData) {
      let battlePos = convertToRelativeMapCoords(battleData.pos)

      let battleStatus = getBattleState(battleData)
      let iconData = getBattleIconData(battleStatus)
      let battleRadius = iconData.iconSize / 2

      return battleData.status != "EBS_FINISHED_APPLIED" &&
        (fabs(battlePos.x - point.x) < battleRadius) && (fabs(battlePos.y - point.y) * aspectRatio < battleRadius)
    })
}

function updateSelectedBattle(battle) {
  sendToDagui("ww.selectBattle", { battleName = battle?.name ?? "" })
}

function updateHoveredBattle(battle) {
  let battleName = battle?.name
  if(hoveredBattle.get() == battleName)
    return
  hoveredBattle.set(battleName)
  if(battleName != null)
    sendToDagui("ww.hoverBattle", { battleName })
}

return {
  battlesInfo
  updateBattlesStates
  updateHoveredBattle
  updateSelectedBattle
  hoveredBattle
  getBattleIconData
  getBattleState
  getBattleByPoint
}