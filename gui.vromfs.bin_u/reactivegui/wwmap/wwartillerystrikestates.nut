import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%rGui/wwMap/wwArmyStates.nut" import selectedArmy, getArmyByName
from "%rGui/wwMap/wwArtilleryUtils.nut" import isSAM
from "worldwar" import wwGetArtilleryStrikes, wwGetCurrActionType, wwArtilleryGetAttackRadius
from "%rGui/globals/ui_library.nut" import *

let { actionType } = require("%rGui/wwMap/wwMapTypes.nut")

let artilleryStrikesInfo = Watched([])
let samStrikesInfo = Watched([])
let artilleryReadyToStrike = Watched(null)
let artilleryAttackRaduis = Watched(0)

function updateArtilleryStrikeStates() {
  let as = DataBlock()
  wwGetArtilleryStrikes(as)
  let strikesCount = as?.artilleryStrikes.blockCount() ?? 0
  if (strikesCount == 0) {
    artilleryStrikesInfo.set([])
    samStrikesInfo.set([])
    return
  }

  let artilleryStrikesData = []
  let samStrikesData = []

  array(strikesCount).each(function(_val, index) {
    let strikeBlk = as.artilleryStrikes.getBlock(index)
    let armyName = strikeBlk.getBlockName()
    let army = getArmyByName(armyName)

    let strikesData = {
      army
      strikePos = strikeBlk.pos
      radius = strikeBlk.radius
      nextStrikeTimeMillis = strikeBlk.nextStrikeTimeMillis
      strikesDone = strikeBlk.strikesDone
      forcedTargetArmyName = strikeBlk.forcedTargetArmyName
    }
    if (isSAM(army))
      samStrikesData.append(strikesData)
    else
      artilleryStrikesData.append(strikesData)
  })

  if (!isEqual(artilleryStrikesData, artilleryStrikesInfo.get()))
    artilleryStrikesInfo.set(artilleryStrikesData)
  if (!isEqual(samStrikesData, samStrikesInfo.get()))
    samStrikesInfo.set(samStrikesData)
}

function updateArtilleryAction() {
  if (wwGetCurrActionType() != actionType.AUT_ArtilleryFire) {
    artilleryReadyToStrike.set(null)
    return
  }
  artilleryAttackRaduis.set(wwArtilleryGetAttackRadius())
  artilleryReadyToStrike.set(getArmyByName(selectedArmy.get()))
}

return {
  artilleryStrikesInfo
  samStrikesInfo
  updateArtilleryStrikeStates
  artilleryReadyToStrike
  updateArtilleryAction
  artilleryAttackRaduis
}