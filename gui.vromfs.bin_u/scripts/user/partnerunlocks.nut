//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let time = require("%scripts/time.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_charserver_time_sec } = require("chard")
let { charRequestBlk } = require("%scripts/tasker.nut")

::g_partner_unlocks <- {
  [PERSISTENT_DATA_PARAMS] = ["partnerExectutedUnlocks", "lastUpdateTime", "lastRequestTime"]

  REQUEST_TIMEOUT_MSEC = 45000
  UPDATE_TIMEOUT_MSEC = 60000

  lastRequestTime = -9999999999
  lastUpdateTime = -9999999999
  partnerExectutedUnlocks = {}
}

::g_partner_unlocks.requestPartnerUnlocks <- function requestPartnerUnlocks() {
  if (!this.canRefreshData())
    return

  this.lastRequestTime = get_time_msec()
  let successCb = function(result) {
    ::g_partner_unlocks.lastUpdateTime = get_time_msec()
    if (!::g_partner_unlocks.applyNewPartnerUnlockData(result))
      return

    broadcastEvent("PartnerUnlocksUpdated")
  }

  let requestBlk = DataBlock()
  charRequestBlk("cln_get_partner_executed_unlocks",
                            requestBlk,
                            { showErrorMessageBox = false },
                            successCb)
}

::g_partner_unlocks.canRefreshData <- function canRefreshData() {
  if (this.lastRequestTime > this.lastUpdateTime && this.lastRequestTime + this.REQUEST_TIMEOUT_MSEC > get_time_msec())
    return false
  if (this.lastUpdateTime + this.UPDATE_TIMEOUT_MSEC > get_time_msec())
    return false

  return true
}

::g_partner_unlocks.getPartnerUnlockTime <- function getPartnerUnlockTime(unlockId) {
  if (u.isEmpty(unlockId))
    return null

  if (!(unlockId in this.partnerExectutedUnlocks)) {
    if (isUnlockOpened(unlockId))
      this.requestPartnerUnlocks()
    return null
  }

  return this.partnerExectutedUnlocks[unlockId]
}

::g_partner_unlocks.applyNewPartnerUnlockData <- function applyNewPartnerUnlockData(result) {
  if (!u.isDataBlock(result))
    return false

  let newPartnerUnlocks = convertBlk(result)
  if (u.isEqual(this.partnerExectutedUnlocks, newPartnerUnlocks))
    return false

  this.partnerExectutedUnlocks = newPartnerUnlocks
  return true
}

::g_partner_unlocks.isPartnerUnlockAvailable <- function isPartnerUnlockAvailable(unlockId, durationMin = null) {
  if (!unlockId)
    return true
  let startSec = this.getPartnerUnlockTime(unlockId)
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

::g_partner_unlocks.onEventSignOut <- function onEventSignOut(_p) {
  this.lastRequestTime = -9999999999
  this.lastUpdateTime = -9999999999
  this.partnerExectutedUnlocks = {}
}

registerPersistentDataFromRoot("g_partner_unlocks")
subscribe_handler(::g_partner_unlocks, ::g_listener_priority.CONFIG_VALIDATION)