from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { APP_ID } = require("app")
let userstat = require("userstat")
let DataBlock = require("DataBlock")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { dataToBlk } = require("%scripts/utils/datablockConverter.nut")
let { activeUnlocks, receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { userstatStats, refreshUserstatStats } = require("%scripts/userstat/userstat.nut")
let { curLangShortName } = require("%scripts/langUtils/language.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { get_charserver_time_sec } = require("chard")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { resetTimeout } = require("dagor.workcycle")

let allRegionalUnlocks = Computed(@() activeUnlocks.value
  .filter(@(u) u?.meta.langLimits != null))

let unlockNameToEndTimestamp = Computed(@() allRegionalUnlocks.get()
  .map(function(u) {
    let mode = DataBlock()
    mode.loadFromText(u.meta.hostUnlockMode, u.meta.hostUnlockMode.len())
    let timeRangeCondition = (mode % "condition")
      .extend(mode % "hostCondition")
      .extend(mode % "visualCondition")
      .findvalue(@(c) c?.type == "timeRange" || c?.type == "char_time_range")

    if ("endDate" not in timeRangeCondition)
      return -1

    return getTimestampFromStringUtc(timeRangeCondition.endDate)
  })
  .filter(@(t) t != -1))

function getClosestExpTime() {
  let curTime = get_charserver_time_sec()
  local closestExpTime = -1
  foreach (timestamp in unlockNameToEndTimestamp.get()) {
    if (timestamp <= curTime)
      continue
    if (closestExpTime == -1 || (timestamp < closestExpTime))
      closestExpTime = timestamp
  }
  return closestExpTime
}

let closestExpirationTime = Watched(getClosestExpTime())

function updateClosestExpirationTime(...) {
  let closestExpTime = getClosestExpTime()
  closestExpirationTime.set(closestExpTime)
  if (closestExpTime != -1)
    resetTimeout((closestExpTime - get_charserver_time_sec()), updateClosestExpirationTime)
}

unlockNameToEndTimestamp.subscribe(updateClosestExpirationTime)

let regionalPromos = Computed(@() allRegionalUnlocks.get()
  .filter(@(u) (u.name not in unlockNameToEndTimestamp.get())
    || ((closestExpirationTime.get() != -1)
      && (closestExpirationTime.get() <= unlockNameToEndTimestamp.get()[u.name])))
  .filter(@(u) u.meta.langLimits.split(";").contains(curLangShortName.value))
  .filter(@(u) (userstatStats.value.stats?[u.table].stats[$"val_{u.name}_activation"] ?? 0) == 0)
  .map(@(u, id) u.meta.popup.__merge({ id })).values().sort(@(a, b) a.id <=> b.id))

let acceptedUnlocks = Computed(@() allRegionalUnlocks.get()
  .filter(@(u) (userstatStats.value.stats?[u.table].stats[$"val_{u.name}_activation"] ?? 0) == 1))

let unclaimedUnlocks = Computed(@() acceptedUnlocks.get().filter(@(u) u.hasReward))

let acceptedUnlocksBlk = Computed(@() acceptedUnlocks.get()
  .map(function(unlock) {
    let mode = DataBlock()
    mode.loadFromText(unlock.meta.hostUnlockMode, unlock.meta.hostUnlockMode.len())

    let unlockTable = unlock.meta.unlockView.__merge({
      id = unlock.name
      isRegional = true
      mode
    })
    if ((unlockTable?.type ?? "") == "")
      unlockTable.type <- "achievement"
    if ((unlockTable?.lockStyle ?? "") == "")
      unlockTable.lockStyle <- "lock"

    return dataToBlk(unlockTable)
  }))

let isRegionalUnlock = @(unlockId) unlockId in acceptedUnlocks.get()
let isRegionalUnlockCompleted = @(unlockId) acceptedUnlocks.get()?[unlockId].isCompleted ?? false
let isRegionalUnlockReadyToOpen = @(unlockId) unlockId in unclaimedUnlocks.get()

function getRegionalUnlockProgress(unlockId) {
  let res = {
    curVal = 0
    maxVal = 1
    curStage = -1
  }

  if (unlockId not in activeUnlocks.value)
    return res

  let { stages, isCompleted, current, stage } =  activeUnlocks.value[unlockId]
  res.maxVal =  stages.top().progress.tointeger()
  res.curVal = isCompleted ? res.maxVal : current
  res.curStage = stage - 1
  return res
}

let getRegionalUnlockTypeById = @(unlockId)
  get_unlock_type(acceptedUnlocksBlk.get()?[unlockId].type)

function claimRegionalUnlockRewards() {
  let unlocks = unclaimedUnlocks.get().filter(@(u) !(u?.manualOpen ?? false))
  if (unlocks.len() == 0)
    return

  let handler = handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (!handler?.isValid() || handlerClass != gui_handlers.MainMenu)
    return

  let unlockId = unlocks.findindex(@(_) true)
  if (unlockId != null)
    handler.doWhenActive(@() receiveRewards(unlockId))
}

function acceptRegionalUnlock(unlockName, callback) {
  let userstatRequestData = {
    add_token = true
    headers = { appid = APP_ID, userId = userIdInt64.get() }
    action = "ClnChangeStats"
    data = {
      [$"val_{unlockName}_activation"] = { ["$set"] = 1 },
      ["$mode"] = "stats",
    }
  }
  userstat.request(userstatRequestData, function(result) {
    refreshUserstatStats()
    callback(result)
  })
}

unclaimedUnlocks.subscribe(@(_) claimRegionalUnlockRewards())

return {
  regionalUnlocks = acceptedUnlocksBlk
  getRegionalUnlockProgress
  claimRegionalUnlockRewards
  getRegionalUnlockTypeById
  isRegionalUnlockCompleted
  isRegionalUnlockReadyToOpen
  isRegionalUnlock
  acceptRegionalUnlock
  regionalPromos
}