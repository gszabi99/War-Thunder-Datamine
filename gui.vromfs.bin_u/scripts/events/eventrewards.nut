from "%scripts/dagui_natives.nut" import get_tournament_info_blk, get_tournaments_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import GAME_EVENT_TYPE

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { addToText } = require("%scripts/unlocks/unlocksConditions.nut")
let DataBlock = require("DataBlock")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getLbCategoryTypeByField } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { requestRewardProgress } = require("%scripts/events/rewardProgressManager.nut")

                                 
let getRewardConditionId = @(rewardBlk) rewardBlk?.condition_type ?? rewardBlk?.awardType ?? ""




let getConditionValue = @(rewardBlk) rewardBlk?.value ?? rewardBlk?.fieldValue ?? -1

let getConditionField = @(rewardBlk) rewardBlk?.fieldName ?? ""

let getConditionIcon = @(condition) condition?.icon ?? ""

function getTournamentInfoBlk(eventEconomicName) {
  let blk = DataBlock()
  get_tournament_info_blk(eventEconomicName, blk)
  return blk
}

function getLeaderboardConditionText(rewardBlk, progress = null) {
  let conditionId = getRewardConditionId(rewardBlk)
  let value = getConditionValue(rewardBlk)
  let valueMin = rewardBlk?.valueMin
  let txtValue = valueMin
    ? loc("conditions/position/from_to", { min = valueMin, max = value }) : value
  local res = loc($"conditions/{conditionId}/{rewardBlk.fieldName}", { value = txtValue })
  let progressTxt = progress && valueMin
    ? $"{loc("ui/dot")} {loc("conditions/position/place")}{loc("ui/colon")} {progress}"
    : progress
      ? "".concat(" ",
        loc("ui/parentheses/space", { text = $"{progress}{loc("ui/slash")}{value}" }))
      : ""

  return $"{res}{progressTxt}"
}

function getSequenceWinsText(rewardBlk, progress = null) {
  let value = getConditionValue(rewardBlk)
  local res = loc("conditions/sequence_wins", { value = value })

  if (progress)
    res = $"{res} ({progress}/{value})"
  return res
 }




let rewardConditionsList = {
  



  reach_value = {
    id = "reach_value"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      let cb = Callback(callback, context)
      requestRewardProgress(event, eventEconomicName, reward_blk.fieldName,
        function (value) {
          local progress = "0"
          if (value != null) {
            let { lbDataType } = getLbCategoryTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })
    }
    getText = getLeaderboardConditionText
  }

  



  field_number = {
    id = "field_number"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      local cb = Callback(callback, context)
      requestRewardProgress(event, eventEconomicName, reward_blk.fieldName,
        function (value) {
          local progress = "0"
          if (value != null) {
            value = value % getConditionValue(reward_blk)
            let { lbDataType } = getLbCategoryTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })
    }
    getText = getLeaderboardConditionText
  }

  


  position = {
    id = "position"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      let request = events.getMainLbRequest(event)
      request.economicName = eventEconomicName
      if (request.forClans)
        request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL
      request.lbField  <- reward_blk.fieldName
      let cb = Callback(callback, context)
      events.requestSelfRow(request, function(self_row) {
        let progress = self_row?[0].pos
        cb(progress != null ? progress + 1 : null)
      })
    }
    getText = getLeaderboardConditionText
  }

  



  percent = {
    id = "percent"
    updateProgress = @(...) null
  }

  sequence_wins = {
    id = "sequence_wins"
    function updateProgress(_rewardBlk, _event, eventEconomicName, callback, context) {
      let progress = getTournamentInfoBlk(eventEconomicName)?.sequenceWinCount ?? 0
      Callback(callback, context)(progress.tostring())
    }
    getText = getSequenceWinsText
  }
}

let getRewardConditionById = @(conditionId) rewardConditionsList?[conditionId]

let getRewardCondition = @(rewardBlk) getRewardConditionById(getRewardConditionId(rewardBlk))

let rewardsConfig = [ 
  
  
  
  
  
  { id = "money"
    locId = ""
    getValue = function(blk) {
      let cost = Cost().setFromTbl(blk)
      return (cost > zero_money) ? cost : null
    }
    getIconStyle = function(value, _blk) {
      let img = (value.gold > 0) ? "#ui/gameuiskin#items_eagles" : "#ui/gameuiskin#items_warpoints"
      return LayersIcon.getIconData(null, img)
    }
    getRowIcon = function(_value, _blk) {
      return ""
    }
    getTooltipId = function (_value) {
      return null
    }
  }
  {
    id = "trophy"
    locId = ""
    getValue = function(blk) {
      if ("trophyName" in blk) {
        let trophy = findItemById(blk.trophyName)
        if (trophy)
          return {
            trophy = trophy
            count = getTblValue("trophyCount", blk, 1)
          }
      }
      return null
    }
    getIconStyle = function(value, _blk) {
      return value ? value.trophy.getIcon() : ""
    }
    getRowIcon = function(value, _blk) {
      return value ? value.trophy.getSmallIconName() : ""
    }
    valueText = function(value) {
      return $"{value.count}x {value.trophy.getName()}"
    }
    getTooltipId = function (value) {
      return value ? getTooltipType("ITEM").getTooltipId(value.trophy.id) : null
    }
  }
  {
    id = "item"
    locId = ""
    getValue = function(blk) {
      if ("itemsName" in blk) {
        let item = findItemById(blk.itemsName)
        if (item)
          return {
            item = item
            count = getTblValue("itemsCount", blk, 1)
          }
      }
      return null
    }
    getIconStyle = function(value, _blk) {
      return value ? value.item.getIcon(false) : ""
    }
    getRowIcon = function(value, _blk) {
      return value ? value.item.getSmallIconName() : ""
    }
    valueText = function(value) {
      return $"{value.count}x {value.item.getName()}"
    }
    getTooltipId = function (value) {
      return value ? getTooltipType("ITEM").getTooltipId(value.item.id) : null
    }
  }
]

function initConfigs() {
  foreach (cfg in rewardsConfig) {
    let id = cfg.id
    if (!("locId" in cfg))
      cfg.locId = $"reward/{id}"
    if (!("getValue" in cfg))
      cfg.getValue = @(blk) blk?[id]
    if (!("getIconStyle" in cfg))
      cfg.getIconStyle = @(_value, _blk) LayersIcon.getIconData($"reward_{id}")
  }
}
initConfigs()

function getRewardsBlk(event) {
  return getBlkValueByPath(get_tournaments_blk(), $"{getEventEconomicName(event)}/awards")
}

function haveRewards(event) {
  let blk = getRewardsBlk(event)
  return blk != null && blk.blockCount() > 0
}

function getBaseVictoryReward(event) {
  let rewardsBlk = getBlkValueByPath(get_tournaments_blk(), getEventEconomicName(event))
  if (!rewardsBlk)
    return null

  let wp = rewardsBlk?.baseWpAward ?? 0
  let gold = rewardsBlk?.baseGoldAward ?? 0
  return (wp || gold) ? Cost(wp, gold) : null
}

function getSortedRewardsByConditions(event, awardsBlk  = null) {
  let res = {}
  let rBlk = awardsBlk ?? getRewardsBlk(event)
  if (!rBlk)
    return res

  foreach (blk in (rBlk % "pr")) {
    let condName = getRewardConditionId(blk)
    if (condName == "")
      continue

    if (!(condName in res))
      res[condName] <- []

    res[condName].append(blk)
  }

  
  foreach (condName, typeData in res)
    typeData.sort(function(a, b) {
        let aValue = getConditionValue(a)
        let bValue = getConditionValue(b)
        if (aValue != bValue)
          return (aValue > bValue) ? 1 : -1
        if (a?[condName] != b?[condName])
          return ((a?[condName] ?? "") > (b?[condName] ?? "")) ? 1 : -1
        return 0
      })

  return res
}

function getRewardIcon(rewardBlk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getIconStyle(value, rewardBlk)
  }
  return ""
}

function getRewardRowIcon(rewardBlk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getRowIcon(value, rewardBlk)
  }
  return ""
}

function getRewardDescText(rewardBlk) {
  local text = ""
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    let valueText = ("valueText" in cfg) ? cfg.valueText(value) : value.tostring()
    let locText = cfg.locId.len() ? loc(cfg.locId) : ""
    text = addToText(text, locText, valueText, "activeTextColor")
  }
  return text
}

function getRewardTooltipId(reward_blk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(reward_blk)
    if (value != null)
      return cfg.getTooltipId(value)
  }
  return null
}

function getTotalRewardDescText(rewardsBlksArray) {
  local text = ""
  local money = Cost()
  foreach (rewardBlk in rewardsBlksArray)
    foreach (cfg in rewardsConfig) {
      let value = cfg.getValue(rewardBlk)
      if (value == null)
        continue

      if (cfg.id == "money")
        money += value
      else {
        let val = ("valueText" in cfg) ? cfg.valueText(value) : value
        text = addToText(text, "", val, "activeTextColor")
      }
    }

  if (money > zero_money)
    text = addToText(text, "", money.tostring(), "activeTextColor")
  return text
}

function getConditionText(rewardBlk, progress = null) {
  let condition = getRewardCondition(rewardBlk)
  if (!condition)
    return ""

  return condition.getText(rewardBlk, progress)
}

function isRewardReceived(reward_blk, eventEconomicName) {
  let infoBlk = getTournamentInfoBlk(eventEconomicName)
  if (!infoBlk?.awards)
    return false

  let conditionId = getRewardConditionId(reward_blk)
  local ending = ""

  
  if (conditionId != "field_number")
    ending = $"{ending}{conditionId}_"

  
  ending = $"{ending}{reward_blk.fieldName}_"

  
  if ("valueMin" in reward_blk)
    ending = $"{ending}{reward_blk.valueMin}-"

  
  ending = $"{ending}{reward_blk.value}"

  for (local i = 0; i < infoBlk.awards.blockCount(); i++) {
    let blk = infoBlk.awards.getBlock(i)
    let name = blk.getBlockName()

    if (name && name.len() > ending.len() && name.slice(name.len() - ending.len()) == ending)
      return true
  }
  return false
}




function getNextReward(rewardBlk, event) {
  if (!event || !haveRewards(event))
    return null

  let conditionId = getRewardConditionId(rewardBlk)
  let allRewards = getSortedRewardsByConditions(event)

  if (!(conditionId in allRewards))
    return null

  foreach (nextPretendetn in allRewards[conditionId]) {
    if (!getTblValue(conditionId, nextPretendetn))
      continue
    if (nextPretendetn[conditionId] > rewardBlk[conditionId])
      return nextPretendetn
  }
  return null
}

return {
  getRewardConditionId
  getRewardCondition
  getRewardConditionById
  getNextReward
  getConditionValue
  getConditionField
  getConditionIcon
  getTournamentInfoBlk
  haveRewards
  getBaseVictoryReward
  getSortedRewardsByConditions
  getRewardIcon
  getRewardRowIcon
  getRewardDescText
  getRewardTooltipId
  getTotalRewardDescText
  getConditionText
  isRewardReceived
}
