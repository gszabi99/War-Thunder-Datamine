let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
::condition_text_functions <- {
  leaderboardCondition = function (rewardBlk, progress = null)
  {
    let conditionId = ::EventRewards.getRewardConditionId(rewardBlk)
    let value = ::EventRewards.getConditionValue(rewardBlk)
    local res = ::loc("conditions/" + conditionId + "/" + rewardBlk.fieldName, {value = value})

    if (progress != null)
      res += " (" + progress + "/" + value + ")"
    return res
  }

  sequenceWins = function (rewardBlk, progress = null)
  {
    let value = ::EventRewards.getConditionValue(rewardBlk)
    local res = ::loc("conditions/sequence_wins", {value = value})

    if (progress)
      res += " (" + progress + "/" + value + ")"
    return res
  }
}

/**
 * Tournament rewards conditions
 */
::reward_conditions_list <- [
  /**
   * Main condition for some value in leaderboards. For eaxample 10 wins or
   * 500 raiting.
   */
  {
    id = "reach_value"
    updateProgress = function (reward_blk, event, callback, context = null)
    {
      let cb = ::Callback(callback, context)
      ::g_reward_progress_manager.requestProgress(event, reward_blk.fieldName,
        (@(reward_blk, cb) function (value) {
          local progress = "0"
          if (value != null)
          {
            let { lbDataType } = ::g_lb_category.getTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })(reward_blk, cb), this)
    }
    getText = ::condition_text_functions.leaderboardCondition
  }

  /**
   * Same as reach_value condition, but reward with this condition can be
   * recieved multiple times. For exapmle for each 10 wictories
   */
  {
    id = "field_number"
    updateProgress = function (reward_blk, event, callback, context = null)
    {
      local cb = ::Callback(callback, context)
      ::g_reward_progress_manager.requestProgress(event, reward_blk.fieldName,
        (@(reward_blk, cb) function (value) {
          local progress = "0"
          if (value != null)
          {
            value = value % ::EventRewards.getConditionValue(reward_blk)
            let { lbDataType } = ::g_lb_category.getTypeByField(reward_blk.fieldName)
            progress = lbDataType.getShortTextByValue(value)
          }
          cb(progress)
        })(reward_blk, cb), this)
    }
    getText = ::condition_text_functions.leaderboardCondition
  }

  /**
   * Condition based on players position in leaderboards.
   */
  {
    id = "position"
    updateProgress = function (reward_blk, event, callback, context = null)
    {
      let request = ::events.getMainLbRequest(event)
      if (request.forClans)
        request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL
      request.lbField  <- reward_blk.fieldName
      let cb = ::Callback(callback, context)
      ::events.requestSelfRow(request, (@(cb) function (self_row) {
          let progress = self_row.len() ? ::getTblValue("pos", self_row[0]) : null
          cb(progress)
        })(cb))
    }
    getText = ::condition_text_functions.leaderboardCondition
  }

  /**
   * Simmilar to position condition, but reward recieved when player in best
   * 50% of all tournaments competitors.
   */
  {
    id = "percent"
    updateProgress = function (...)
    {}
  }

  {
    id = "sequence_wins"
    updateProgress = function (rewardBlk, event, callback, context = null)
    {
      let progress = ::EventRewards.getTournamentInfoBlk(::events.getEventEconomicName(event))
        ?.sequenceWinCount ?? 0
      ::Callback(callback, context)(progress.tostring())
    }
    getText = ::condition_text_functions.sequenceWins
  }
]

::EventRewards <- {
  _rewardsConfig = [ //first in list have higher priority to show icon or to generate text.
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
      getIconStyle = function(value, blk) {
        let img = (value.gold > 0) ? "#ui/gameuiskin#items_eagles.png" : "#ui/gameuiskin#items_warpoints.png"
        return ::LayersIcon.getIconData(null, img)
      }
      getRowIcon = function(value, blk) {
        return ""
      }
      getTooltipId = function (value) {
        return null
      }
    }
    {
      id = "trophy"
      locId = ""
      getValue = function(blk) {
        if ("trophyName" in blk)
        {
          let trophy = ::ItemsManager.findItemById(blk.trophyName)
          if (trophy)
            return {
              trophy = trophy
              count = ::getTblValue("trophyCount", blk, 1)
            }
        }
        return null
      }
      getIconStyle = function(value, blk) {
        return value ? value.trophy.getIcon() : ""
      }
      getRowIcon = function(value, blk) {
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
        if ("itemsName" in blk)
        {
          let item = ::ItemsManager.findItemById(blk.itemsName)
          if (item)
            return {
              item = item
              count = ::getTblValue("itemsCount", blk, 1)
            }
        }
        return null
      }
      getIconStyle = function(value, blk) {
        return value ? value.item.getIcon(false) : ""
      }
      getRowIcon = function(value, blk) {
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
}

EventRewards.initConfigs <- function initConfigs()
{
  foreach(cfg in _rewardsConfig)
  {
    let id = cfg.id
    if (!("locId" in cfg))
      cfg.locId = "reward/" + id
    if (!("getValue" in cfg))
      cfg.getValue = (@(id) function(blk) { return blk?[id] })(id)
    if (!("getIconStyle" in cfg))
      cfg.getIconStyle = (@(id) function(value, blk) { return ::LayersIcon.getIconData("reward_" + id) })(id)
  }
}
::EventRewards.initConfigs()

EventRewards.getRewardsBlk <- function getRewardsBlk(event)
{
  return get_blk_value_by_path(::get_tournaments_blk(), ::events.getEventEconomicName(event) + "/awards")
}

EventRewards.getTournamentInfoBlk <- function getTournamentInfoBlk(eventEconomicName) {
  let blk = ::DataBlock()
  ::get_tournament_info_blk(eventEconomicName, blk)
  return blk
}

EventRewards.haveRewards <- function haveRewards(event)
{
  let blk = getRewardsBlk(event)
  return blk != null && blk.blockCount() > 0
}

EventRewards.getConditionsList <- function getConditionsList()
{
  return ::reward_conditions_list
}

EventRewards.getCondition <- function getCondition(condition_id)
{
  foreach (condition in ::reward_conditions_list)
    if (condition.id == condition_id)
      return condition
  return null
}

EventRewards.getRewardConditionId <- function getRewardConditionId(rewardBlk)
{
                      //param name in tournament configs            //param name in userlogs configs
  let conditionId = ::getTblValue("condition_type", rewardBlk) || ::getTblValue("awardType", rewardBlk)

  foreach(cond in ::reward_conditions_list)
  {
    if (cond.id == conditionId)
      return cond.id
  }
  return null
}

EventRewards.getRewardCondition <- function getRewardCondition(reward_blk)
{
  foreach(cond in ::reward_conditions_list)
    if (cond.id == reward_blk?.condition_type)
      return cond
  return null
}

EventRewards.getBaseVictoryReward <- function getBaseVictoryReward(event)
{
  let rewardsBlk = get_blk_value_by_path(::get_tournaments_blk(), ::events.getEventEconomicName(event))
  if (!rewardsBlk)
    return null

  let wp = rewardsBlk?.baseWpAward ?? 0
  let gold = rewardsBlk?.baseGoldAward ?? 0
  return (wp || gold) ? ::Cost(wp, gold) : null
}

EventRewards.getSortedRewardsByConditions <- function getSortedRewardsByConditions(event, awardsBlk  = null)
{
  let res = {}
  let rBlk = awardsBlk ?? getRewardsBlk(event)
  if (!rBlk)
    return res

  foreach(blk in (rBlk % "pr"))
  {
    let condName = getRewardConditionId(blk)

    if (!condName)
      continue

    if (!(condName in res))
      res[condName] <- []

    res[condName].append(blk)
  }

  //sort rewards
  foreach(condName, typeData in res)
    typeData.sort((@(condName) function(a, b) {
        let aValue = ::EventRewards.getConditionValue(a)
        let bValue = ::EventRewards.getConditionValue(b)
        if (aValue != bValue)
          return (aValue > bValue) ? 1 : -1
        if (a?[condName] != b?[condName])
          return ((a?[condName] ?? "") > (b?[condName] ?? "")) ? 1 : -1
        return 0
      })(condName))

  return res
}

EventRewards.getRewardIcon <- function getRewardIcon(rewardBlk)
{
  foreach(cfg in _rewardsConfig)
  {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getIconStyle(value, rewardBlk)
  }
  return ""
}

EventRewards.getRewardRowIcon <- function getRewardRowIcon(rewardBlk)
{
  foreach(cfg in _rewardsConfig)
  {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    return cfg.getRowIcon(value, rewardBlk)
  }
  return ""
}

EventRewards.getRewardDescText <- function getRewardDescText(rewardBlk)
{
  local text = ""
  foreach(cfg in _rewardsConfig)
  {
    let value = cfg.getValue(rewardBlk)
    if (value == null)
      continue

    let valueText = ("valueText" in cfg) ? cfg.valueText(value) : value.tostring()
    let locText = cfg.locId.len() ? ::loc(cfg.locId) : ""
    text = ::UnlockConditions.addToText(text, locText, valueText, "activeTextColor")
  }
  return text
}

EventRewards.getRewardTooltipId <- function getRewardTooltipId(reward_blk)
{
  foreach(cfg in _rewardsConfig)
  {
    let value = cfg.getValue(reward_blk)
    if (value != null)
      return cfg.getTooltipId(value)
  }
  return null
}

EventRewards.getTotalRewardDescText <- function getTotalRewardDescText(rewardsBlksArray)
{
  local text = ""
  local money = ::Cost()
  foreach(rewardBlk in rewardsBlksArray)
    foreach(cfg in _rewardsConfig)
    {
      let value = cfg.getValue(rewardBlk)
      if (value == null)
        continue

      if (cfg.id == "money")
        money += value
      else
      {
        let val = ("valueText" in cfg)? cfg.valueText(value) : value
        text = ::UnlockConditions.addToText(text, "", val, "activeTextColor")
      }
    }

  if (money > ::zero_money)
    text = ::UnlockConditions.addToText(text, "", money.tostring(), "activeTextColor")
  return text
}

EventRewards.getConditionText <- function getConditionText(rewardBlk, progress = null)
{
  let conditionId = getRewardConditionId(rewardBlk)
  let condition = getCondition(conditionId)
  if (!condition)
    return ""

  return condition.getText(rewardBlk, progress)
}

/**
 * Returns a pure value of reward condition
 */
EventRewards.getConditionValue <- function getConditionValue(reward_blk)
{
  return ::getTblValue("value", reward_blk, ::getTblValue("fieldValue", reward_blk, -1))
}

EventRewards.getConditionField <- function getConditionField(reward_blk)
{
  return ::getTblValue("fieldName", reward_blk, "")
}

EventRewards.getConditionIcon <- function getConditionIcon(condition)
{
  return ::getTblValue("icon", condition, "")
}

EventRewards.getConditionHeader <- function getConditionHeader(condition)
{
  return ::loc("conditions/" + condition.id)
}

EventRewards.getConditionLbField <- function getConditionLbField(condition)
{
  return ::getTblValue("lbField", condition, condition.id)
}

EventRewards.isRewardReceived <- function isRewardReceived(reward_blk, eventEconomicName)
{
  let infoBlk = ::EventRewards.getTournamentInfoBlk(eventEconomicName)
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

  for(local i = 0; i < infoBlk.awards.blockCount(); i++)
  {
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
EventRewards.getNext <- function getNext(rewardBlk, event)
{
  if (!event || !haveRewards(event))
    return null

  let conditionId = getRewardConditionId(rewardBlk)
  let allRewards = getSortedRewardsByConditions(event)

  if (!(conditionId in allRewards))
    return null

  foreach (nextPretendetn in allRewards[conditionId])
  {
    if (!::getTblValue(conditionId, nextPretendetn))
      continue
    if (nextPretendetn[conditionId] > rewardBlk[conditionId])
      return nextPretendetn
  }
  return null
}
