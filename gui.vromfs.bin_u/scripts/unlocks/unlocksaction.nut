from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { charSendBlk } = require("chard")
let { isString } = require("%sqStdLibs/helpers/u.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { addTask } = require("%scripts/tasker.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")
let { isRegionalUnlock } = require("%scripts/unlocks/regionalUnlocks.nut")
let { hangar_get_current_unit_name } = require("hangar")
let { addPopup } = require("%scripts/popups/popups.nut")

function openUnlockManually(unlockId, onSuccess = null) {
  if (isRegionalUnlock(unlockId)) {
    receiveRewards(unlockId) 
    return
  }

  let blk = DataBlock()
  blk.addStr("unlock", unlockId)
  let taskId = charSendBlk("cln_manual_reward_unlock", blk)
  addTask(taskId, { showProgressBox = true }, onSuccess)
}

function buyUnlockImpl(unlockId, unitName, cost, onSuccessCb = null, onErrorCb = null) {
  unitName = unitName ?? hangar_get_current_unit_name()
  let blk = DataBlock()
  blk.name = unlockId
  if (unitName != "")
    blk.unitName = unitName
  blk.wpCost = cost.wp
  blk.goldCost = cost.gold
  let taskId = charSendBlk("cln_buy_unlock", blk)
  addTask(taskId, {
      showProgressBox = true
      showErrorMessageBox = false
      progressBoxText = loc("charServer/purchase")
    },
    onSuccessCb,
    function(result) {
      addPopup("", colorize("activeTextColor", ::getErrorText(result)))
      onErrorCb?()
    }
  )
}

function buyUnlock(unlock, onSuccessCb = null, onAfterCheckCb = null) {
  let unlockBlk = isString(unlock) ? getUnlockById(unlock) : unlock
  let cost = getUnlockCost(unlockBlk.id)
  if (!checkBalanceMsgBox(cost, onAfterCheckCb))
    return

  buyUnlockImpl(unlockBlk.id, null, cost, onSuccessCb)
}

return {
  openUnlockManually
  buyUnlockImpl
  buyUnlock
}