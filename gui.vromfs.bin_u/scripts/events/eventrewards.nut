//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { addToText } = require("%scripts/unlocks/unlocksConditions.nut")
let DataBlock = require("DataBlock")

                                 //param name in tournament configs //param name in userlogs configs
let getRewardConditionId = @(rewardBlk) rewardBlk?.condition_type ?? rewardBlk?.awardType ?? ""

/**
 * Returns a pure value of reward condition
 */
let getConditionValue = @(rewardBlk) rewardBlk?.value ?? rewardBlk?.fieldValue ?? -1

let getConditionField = @(rewardBlk) rewardBlk?.fieldName ?? ""

let getConditionIcon = @(condition) condition?.icon ?? ""

let function getTournamentInfoBlk(eventEconomicName) {
  let blk = DataBlock()
  ::get_tournament_info_blk(eventEconomicName, blk)
  return blk
}

let function getLeaderboardConditionText(rewardBlk, progress = null) {
  let conditionId = getRewardConditionId(rewardBlk)
  let value = getConditionValue(rewardBlk)
  let valueMin = rewardBlk?.valueMin
  let txtValue = valueMin
    ? loc("conditions/position/from_to", { min = valueMin, max = value }) : value
  local res = loc("conditions/" + conditionId + "/" + rewardBlk.fieldName, { value = txtValue })
  let progressTxt = progress && valueMin
    ? $"{loc("ui/dot")} {loc("conditions/position/place")}{loc("ui/colon")} {progress}"
    : progress
      ? "".concat(" ",
        loc("ui/parentheses/space", { text = $"{progress}{loc("ui/slash")}{value}" }))
      : ""

  return $"{res}{progressTxt}"
}

let function getSequenceWinsText(rewardBlk, progress = null) {
  let value = getConditionValue(rewardBlk)
  local res = loc("conditions/sequence_wins", { value = value })

  if (progress)
    res += " (" + progress + "/" + value + ")"
  return res
 }

/**
 * Tournament rewards conditions
 */
let rewardConditionsList = {
  /**
   * Main condition for some value in leaderboards. For eaxample 10 wins or
   * 500 raiting.
   */
  reach_value = {
    id = "reach_value"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      let cb = Callback(callback, context)
      ::g_reward_progress_manager.requestProgress(event, eventEconomicName, reward_blk.fieldName,
        function (value) {
          local progress = "0"
          if (value != null) {
            let { lbDataType } = ::g_lb_category.getTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })
    }
    getText = getLeaderboardConditionText
  }

  /**
   * Same as reach_value condition, but reward with this condition can be
   * recieved multiple times. For exapmle for each 10 wictories
   */
  field_number = {
    id = "field_number"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      local cb = Callback(callback, context)
      ::g_reward_progress_manager.requestProgress(event, eventEconomicName, reward_blk.fieldName,
        function (value) {
          local progress = "0"
          if (value != null) {
            value = value % getConditionValue(reward_blk)
            let { lbDataType } = ::g_lb_category.getTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })
    }
    getText = getLeaderboardConditionText
  }

  /**
   * Condition based on players position in leaderboards.
   */
  position = {
    id = "position"
    function updateProgress(reward_blk, event, eventEconomicName, callback, context) {
      let request = ::events.getMainLbRequest(event)
      request.economicName = eventEconomicName
      if (request.forClans)
        request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL
      request.lbField  <- reward_blk.fieldName
      let cb = Callback(callback, context)
      ::events.requestSelfRow(request, function(self_row) {
        let progress = self_row?[0].pos
        cb(progress != null ? progress + 1 : null)
      })
    }
    getText = getLeaderboardConditionText
  }

  /**
   * Simmilar to position condition, but reward recieved when player in best
   * 50% of all tournaments competitors.
   */
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

let rewardsConfig = [ //first in list have higher priority to show icon or to generate text.
  //id            - (string) id to genenerate condition name, take value from blk, geneate icon
  //locId         - (string) id to show in description
  //getValue      - function to getValue from rewardBlk.  return null when no value in blk.
  //                when not set work as return blk[id]
  //getIconStyle  - return style for icon when it a primary reward
  { id = "money"
    locId = ""
    getValue = function(blk) {
      let cost = ::Cost().setFromTbl(blk)
      return (cost > ::zero_money) ? cost : null
    }
    getIconStyle = function(value, _blk) {
      let img = (value.gold > 0) ? "#ui/gameuiskin#items_eagles" : "#ui/gameuiskin#items_warpoints"
      return ::LayersIcon.getIconData(null, img)
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
        let trophy = ::ItemsManager.findItemById(blk.trophyName)
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
      return value.count + "x " + value.trophy.getName()
    }
    getTooltipId = function (value) {
      return value ? ::g_tooltip.getIdItem(value.trophy.id) : null
    }
  }
  {
    id = "item"
    locId = ""
    getValue = function(blk) {
      if ("itemsName" in blk) {
        let item = ::ItemsManager.findItemById(blk.itemsName)
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
      return value.count + "x " + value.item.getName()
    }
    getTooltipId = function (value) {
      return value ? ::g_tooltip.getIdItem(value.item.id) : null
    }
  }
]

let function initConfigs() {
  foreach (cfg in rewardsConfig) {
    let id = cfg.id
    if (!("locId" in cfg))
      cfg.locId = "reward/" + id
    if (!("getValue" in cfg))
      cfg.getValue = (@(id) function(blk) { return blk?[id] })(id)
    if (!("getIconStyle" in cfg))
      cfg.getIconStyle = (@(id) function(_value, _blk) { return ::LayersIcon.getIconData("reward_" + id) })(id)
  }
}
initConfigs()

let function getRewardsBlk(event) {
  return get_blk_value_by_path(::get_tournaments_blk(), ::events.getEventEconomicName(event) + "/awards")
}

let function haveRewards(event) {
  let blk = getRewardsBlk(event)
  return blk != null && blk.blockCount() > 0
}

let function getBaseVictoryReward(event) {
  let rewardsBlk = get_blk_value_by_path(::get_tournaments_blk(), ::events.getEventEconomicName(event))
  if (!rewardsBlk)
    return null

  let wp = rewardsBlk?.baseWpAward ?? 0
  let gold = rewardsBlk?.baseGoldAward ?? 0
  return (wp || gold) ? ::Cost(wp, gold) : null
}

let function getSortedRewardsByConditions(event, awardsBlk  = null) {
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

  //sort rewards
  foreach (condName, typeData in res)
    typeData.sort((@(condName) function(a, b) {
        let aValue = getConditionValue(a)
        let bValue = getConditionValue(b)
        if (aValue != bValue)
          return (aValue > bValue) ? 1 : -1
        if (a?[condName] != b?[condName])
          return ((a?[condName] ?? "") > (b?[condName] ?? "")) ? 1 : -1
        return 0
      })(condName))

  return res
}

let function getRewardIcon(rewardBlk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getIconStyle(value, rewardBlk)
  }
  return ""
}

let function getRewardRowIcon(rewardBlk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getRowIcon(value, rewardBlk)
  }
  return ""
}

let function getRewardDescText(rewardBlk) {
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

let function getRewardTooltipId(reward_blk) {
  foreach (cfg in rewardsConfig) {
    let value = cfg.getValue(reward_blk)
    if (value != null)
      return cfg.getTooltipId(value)
  }
  return null
}

let function getTotalRewardDescText(rewardsBlksArray) {
  local text = ""
  local money = ::Cost()
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

  if (money > ::zero_money)
    text = addToText(text, "", money.tostring(), "activeTextColor")
  return text
}

let function getConditionText(rewardBlk, progress = null) {
  let condition = getRewardCondition(rewardBlk)
  if (!condition)
    return ""

  return condition.getText(rewardBlk, progress)
}

let function isRewardReceived(reward_blk, eventEconomicName) {
  let infoBlk = getTournamentInfoBlk(eventEconomicName)
  if (!infoBlk?.awards)
    return false

  let conditionId = getRewardConditionId(reward_blk)
  local ending = ""

  //field_number rewards does not contain condition name
  if (conditionId != "field_number")
    ending += conditionId + "_"

  //every reward has field number
  ending += reward_blk.fieldName + "_"

  //handlind rewards with range
  if ("valueMin" in reward_blk)
    ending += reward_blk.valueMin + "-"

  //and every raward has value
  ending += reward_blk.value

  for (local i = 0; i < infoBlk.awards.blockCount(); i++) {
    let blk = infoBlk.awards.getBlock(i)
    let name = blk.getBlockName()

    if (name && name.len() > ending.len() && name.slice(name.len() - ending.len()) == ending)
      return true
  }
  return false
}

/**
 * Retures next reward for specified
 */
let function getNextReward(rewardBlk, event) {
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
