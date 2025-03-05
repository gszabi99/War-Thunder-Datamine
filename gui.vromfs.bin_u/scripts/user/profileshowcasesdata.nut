from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { isDataBlock, convertBlk } = require("%sqstd/datablock.nut")
let { get_time_msec } = require("dagor.time")
let { eventbus_subscribe } = require("eventbus")
let { isArray } = require("%sqstd/underscore.nut")

enum allShowcasesEventName {
  UPDATED = "AllShowcasesDataUpdated"
}

let MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC = 300000
let MIN_TIME_BETWEEN_FREQUENT_REQUESTS_MSEC = 5000

local allShowcasesData = null
local hasRequest = false
local lastRequestTime = 0

function onProfileShowcaseResponce(responce) {
  hasRequest = false
  if (!isDataBlock(responce))
    return
  allShowcasesData = convertBlk(responce)
  if (allShowcasesData?.unit_collector.units && !isArray(allShowcasesData.unit_collector.units))
    allShowcasesData.unit_collector.units = [allShowcasesData.unit_collector.units]

  broadcastEvent(allShowcasesEventName.UPDATED, allShowcasesData)
}

function onProfileShowcaseError(_err) {
  hasRequest = false
  logerr("Error: failed request all showcase info")
}

function requestShowcases() {
  if (hasRequest)
    return
  hasRequest = true
  lastRequestTime = get_time_msec()
  charRequestBlk("cln_get_showcases", DataBlock(),
    {showErrorMessageBox = false }, onProfileShowcaseResponce, onProfileShowcaseError
  )
}

function generateShowcaseInfo(name, frequentRequest = false) {
  if ((get_time_msec() - lastRequestTime) > (frequentRequest ? MIN_TIME_BETWEEN_FREQUENT_REQUESTS_MSEC : MIN_TIME_BETWEEN_SAME_REQUESTS_MSEC)
    || allShowcasesData == null)
    requestShowcases()

  if (allShowcasesData == null)
    return null

  if ((name ?? "") == "")
    name = allShowcasesData?.current ?? ""
  return {
    schType = name,
    showcase = allShowcasesData?[name] ?? {}
  }
}

function updateShowcaseDataInCache(name, data) {
  if (!allShowcasesData?[name])
    return
  let showcase = allShowcasesData[name]
  foreach (key, value in data)
    if (showcase?[key] != data[key])
      showcase[key] <- value
}

function setCurrentShowcase(name) {
  if (allShowcasesData == null)
    return
  allShowcasesData.current <- name
}

function onSignOut(_) {
  allShowcasesData = null
  lastRequestTime = 0
}

eventbus_subscribe("on_sign_out", onSignOut)

return {
  allShowcasesEventName
  generateShowcaseInfo
  setCurrentShowcase
  updateShowcaseDataInCache
}