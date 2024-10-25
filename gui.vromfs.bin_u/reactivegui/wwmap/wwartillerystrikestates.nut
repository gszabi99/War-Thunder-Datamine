from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { wwGetArtilleryStrikes, wwGetCurrActionType, wwArtilleryGetAttackRadius } = require("worldwar")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { actionType } = require("%rGui/wwMap/wwMapTypes.nut")
let { selectedArmy, getArmyByName } = require("%rGui/wwMap/wwArmyStates.nut")

let artilleryStrikesInfo = Watched([])
let artilleryReadyToStrike = Watched(null)
let artilleryAttackRaduis = Watched(0)

function updateArtilleryStrikeStates() {
  let as = DataBlock()
  wwGetArtilleryStrikes(as)
  let strikesCount = as?.artilleryStrikes.blockCount() ?? 0
  if (strikesCount == 0) {
    artilleryStrikesInfo.set([])
    return
  }

  let strikesData = array(strikesCount).map(function(_val, index) {
    let strikeBlk = as.artilleryStrikes.getBlock(index)
    return {
      army = strikeBlk.getBlockName()
      strikePos = strikeBlk.pos
      radius = strikeBlk.radius
      nextStrikeTimeMillis = strikeBlk.nextStrikeTimeMillis
      strikesDone = strikeBlk.strikesDone
    }
  })

  if (isEqual(strikesData, artilleryStrikesInfo.get()))
    return

  artilleryStrikesInfo.set(strikesData)
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
  updateArtilleryStrikeStates
  artilleryReadyToStrike
  updateArtilleryAction
  artilleryAttackRaduis
}