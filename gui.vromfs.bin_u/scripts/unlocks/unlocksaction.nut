import "DataBlock" as DataBlock
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/userstat/userstatItemsRewards.nut" import receiveRewards
from "%scripts/tasker.nut" import addTask
from "%scripts/user/balanceFeatures.nut" import checkBalanceMsgBox
from "%scripts/unlocks/unlocksModule.nut" import getUnlockCost
from "%scripts/unlocks/regionalUnlocks.nut" import isRegionalUnlock
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/hud/serverMessages.nut" import getErrorText
from "%sqStdLibs/helpers/u.nut" import isString
from "chard" import charSendBlk
from "hangar" import hangar_get_current_unit_name
from "%scripts/dagui_library.nut" import *

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
      addPopup("", colorize("activeTextColor", getErrorText(result)))
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

return freeze({
  openUnlockManually
  buyUnlockImpl
  buyUnlock
})