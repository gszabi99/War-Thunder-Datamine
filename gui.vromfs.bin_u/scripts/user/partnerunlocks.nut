from "%scripts/dagui_library.nut" import *

let { CONFIG_VALIDATION } = require("%scripts/g_listener_priority.nut")
let { isEmpty, isDataBlock, isEqual } = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let time = require("%scripts/time.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { get_charserver_time_sec } = require("chard")
let { charRequestBlk } = require("%scripts/tasker.nut")

let partnerExectutedUnlocks = persist("partnerExectutedUnlocks", @() {})

let partnerUnlocksTimes = persist("partnerUnlocksTimes", @() {
  lastRequestTime = -9999999999
  lastUpdateTime = -9999999999
})

const REQUEST_TIMEOUT_MSEC = 45000
const UPDATE_TIMEOUT_MSEC = 60000


function applyNewPartnerUnlockData(result) {
  if (!isDataBlock(result))
    return false

  let newPartnerUnlocks = convertBlk(result)
  if (isEqual(partnerExectutedUnlocks, newPartnerUnlocks))
    return false

  partnerExectutedUnlocks.clear()
  partnerExectutedUnlocks.__update(newPartnerUnlocks)
  return true
}

function canRefreshData() {
  if (partnerUnlocksTimes.lastRequestTime > partnerUnlocksTimes.lastUpdateTime && partnerUnlocksTimes.lastRequestTime + REQUEST_TIMEOUT_MSEC > get_time_msec())
    return false
  if (partnerUnlocksTimes.lastUpdateTime + UPDATE_TIMEOUT_MSEC > get_time_msec())
    return false

  return true
}

function requestPartnerUnlocks() {
  if (!canRefreshData())
    return

  partnerUnlocksTimes.lastRequestTime = get_time_msec()
  let successCb = function(result) {
    partnerUnlocksTimes.lastUpdateTime = get_time_msec()
    if (!applyNewPartnerUnlockData(result))
      return

    broadcastEvent("PartnerUnlocksUpdated")
  }

  let requestBlk = DataBlock()
  charRequestBlk("cln_get_partner_executed_unlocks",
                            requestBlk,
                            { showErrorMessageBox = false },
                            successCb)
}

function getPartnerUnlockTime(unlockId) {
  if (isEmpty(unlockId))
    return null

  if (!(unlockId in partnerExectutedUnlocks)) {
    if (isUnlockOpened(unlockId))
      requestPartnerUnlocks()
    return null
  }

  return partnerExectutedUnlocks[unlockId]
}

function isPartnerUnlockAvailable(unlockId, durationMin = null) {
  if (!unlockId)
    return true
  let startSec = getPartnerUnlockTime(unlockId)
  if (!startSec)
    return false
  if (!durationMin)
    return true
  if (!is_numeric(durationMin))
    return false

  let durationSec = time.minutesToSeconds(durationMin)
  let endSec = startSec + durationSec
  return endSec > get_charserver_time_sec()
}

function resetCache() {
  partnerUnlocksTimes.lastRequestTime = -9999999999
  partnerUnlocksTimes.lastUpdateTime = -9999999999
  partnerExectutedUnlocks.clear()
}

addListenersWithoutEnv({
  SignOut = @(_) resetCache()
}, CONFIG_VALIDATION)

return {
  isPartnerUnlockAvailable
}
