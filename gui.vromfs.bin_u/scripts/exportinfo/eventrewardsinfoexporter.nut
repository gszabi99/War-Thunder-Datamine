from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath

from "%scripts/dagui_natives.nut" import get_unlock_type

let DataBlock  = require("DataBlock")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockImageConfig, buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")

let { web_rpc } = require("%scripts/webRPC.nut")
let { register_command } = require("console")

let { saveJson } = require("%sqstd/json.nut")

let { findItemById } = require("%scripts/items/itemsManagerModule.nut")

let unlockTypesToShow = [
  UNLOCKABLE_TROPHY
]

let resourceTypes = [
  "decal", "attachable"
]

let excludedChapters = [
  "history_pages"
]

function isSuitable(unlock) {
  if (excludedChapters.contains(unlock?.chapter))
    return false
  let unlockTypeId = get_unlock_type(unlock?.type ?? "")
  if (!unlockTypesToShow.contains(unlockTypeId))
    return false
  if (unlock?.isRevenueShare || !isUnlockVisible(unlock) || isBattleTask(unlock))
    return false

  let mode = unlock?.mode
  if(mode != null) {
    if((mode % "condition").findindex(@(v) v?.type == "battlepassSeason") != null)
      return false
    if((mode % "hostCondition").findindex(@(v) v?.type == "battlepassSeason") != null)
      return false
  }
  return true
}

function genRewardsInfoData(path) {
  let fullPath = $"{path}/eventRewardsInfo.blk"
  log($"Gen game event rewards info to {fullPath}")

  let res = DataBlock()
  let unlocks = getAllUnlocksWithBlkOrder()
  foreach (unlockBlk in unlocks) {
    if (!isSuitable(unlockBlk))
      continue

    let id = unlockBlk.id

    let event = DataBlock()
    event.id = id
    event.category = unlockBlk?.chapter ?? ""
    event.group = unlockBlk?.group ?? ""
    event.iconReward = unlockBlk?.icon ?? ""

    if (event.iconReward != "") {
      res[id] = event
      continue
    }

    let trophy = findItemById(unlockBlk?.userLogId ?? "")
    if (trophy) {
      let content = trophy.getContent().filter(@(c) resourceTypes.contains(c?.resourceType ?? ""))
      foreach (c in content) {
        let {resourceType = null, resource = null} = c
        if (resource != null && resourceType != null)
          event.iconReward = $"{resourceType}/{resource}"
      }
    }

    if (event.iconReward == "") {
      let itemData = buildConditionsConfig(unlockBlk)
      let cfg = getUnlockImageConfig(itemData)
      event.iconReward = cfg.image
    }

    res[id] = event
  }

  mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

function makeRewardsInfo(path, exportFileName) {
  let status = {}
  try {
    genRewardsInfoData(path)
    status.success <- true
  } catch (e) {
    logerr($"Failed to get events info: {e}")
    status.success <- false
  }

  saveJson($"{path}/{exportFileName}", status)
  let result = status.success
  log($"Gen game event rewards finished with status: {result}")
}

function exportEventRewardsList(params) {
  makeRewardsInfo(params.path, params.fileName)
  return "ok"
}

web_rpc.register_handler("exportEventRewardsList", exportEventRewardsList)
register_command(@(pathFolder) exportEventRewardsList({path = pathFolder}), "debug.print_rewards_list")