from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { APP_ID } = require("app")
let userstat = require("userstat")
let DataBlock = require("DataBlock")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { dataToBlk } = require("%scripts/utils/datablockConverter.nut")
let { activeUnlocks, receiveRewards } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { userstatStats, refreshUserstatUnlocks, refreshUserstatStats } = require("%scripts/userstat/userstat.nut")
let { curLangShortName } = require("%scripts/langUtils/language.nut")

let allRegionalUnlocks = Computed(@() activeUnlocks.value
  .filter(@(u) u?.meta.langLimits != null))

let regionalPromos = Computed(@() allRegionalUnlocks.value
  .filter(@(u) u.meta.langLimits.split(";").contains(curLangShortName.value))
  .filter(@(u) (userstatStats.value.stats?[u.table].stats[$"val_{u.name}_activation"] ?? 0) == 0)
  .map(@(u, id) u.meta.popup.__merge({ id })).values().sort(@(a, b) a.id <=> b.id))

let acceptedUnlocks = Computed(@() allRegionalUnlocks.value
  .filter(@(u) (userstatStats.value.stats?[u.table].stats[$"val_{u.name}_activation"] ?? 0) == 1))

let unclaimedUnlocks = Computed(@() acceptedUnlocks.value.filter(@(u) u.hasReward))

let acceptedUnlocksBlk = Computed(@() acceptedUnlocks.value
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

let isRegionalUnlock = @(unlockId) unlockId in acceptedUnlocks.value
let isRegionalUnlockCompleted = @(unlockId) acceptedUnlocks.value?[unlockId].isCompleted ?? false
let isRegionalUnlockReadyToOpen = @(unlockId) unlockId in unclaimedUnlocks.value

let function getRegionalUnlockProgress(unlockId) {
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
  ::get_unlock_type(acceptedUnlocksBlk.value?[unlockId].type)

let function claimRegionalUnlockRewards() {
  let unlocks = unclaimedUnlocks.value.filter(@(u) !(u?.manualOpen ?? false))
  if (unlocks.len() == 0)
    return

  let handler = handlersManager.getActiveBaseHandler()
  let handlerClass = handler?.getclass()
  if (!handler?.isValid() || handlerClass != gui_handlers.MainMenu)
    return

  foreach (id, _ in unlocks) {
    let unlockId = id
    handler.doWhenActive(@() receiveRewards(unlockId))
    break
  }
}

let function acceptRegionalUnlock(unlockName, callback) {
  let userstatRequestData = {
    add_token = true
    headers = { appid = APP_ID, userId = ::my_user_id_int64 }
    action = "ClnChangeStats"
    data = {
      [$"val_{unlockName}_activation"] = { ["$set"] = 1 },
      ["$mode"] = "stats",
    }
  }
  userstat.request(userstatRequestData, function(result) {
    refreshUserstatUnlocks()
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