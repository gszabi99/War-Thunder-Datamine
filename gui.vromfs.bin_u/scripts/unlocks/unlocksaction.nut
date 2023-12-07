from "%scripts/dagui_library.nut" import *

let { shopBuyUnlock } = require("unlocks")
let DataBlock = require("DataBlock")
let { charSendBlk } = require("chard")
let { isString } = require("%sqStdLibs/helpers/u.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { addTask } = require("%scripts/tasker.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")
let { isRegionalUnlock } = require("%scripts/unlocks/regionalUnlocks.nut")

let function openUnlockManually(unlockId, onSuccess = null) {
  if (isRegionalUnlock(unlockId)) {
    receiveRewards(unlockId) // todo onSuccess
    return
  }

  let blk = DataBlock()
  blk.addStr("unlock", unlockId)
  let taskId = charSendBlk("cln_manual_reward_unlock", blk)
  addTask(taskId, { showProgressBox = true }, onSuccess)
}

let function buyUnlock(unlock, onSuccessCb = null, onAfterCheckCb = null) {
  let unlockBlk = isString(unlock) ? getUnlockById(unlock) : unlock
  if (!checkBalanceMsgBox(getUnlockCost(unlockBlk.id), onAfterCheckCb))
    return

  let taskId = shopBuyUnlock(unlockBlk.id)
  addTask(taskId, {
      showProgressBox = true
      showErrorMessageBox = false
      progressBoxText = loc("charServer/purchase")
    },
    onSuccessCb,
    @(result) ::g_popups.add(::getErrorText(result), "")
  )
}

return {
  openUnlockManually
  buyUnlock
}