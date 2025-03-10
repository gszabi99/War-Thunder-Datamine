from "%scripts/dagui_library.nut" import *

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let {TrophyMultiAward, isPrizeMultiAward} = require("%scripts/items/trophyMultiAward.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { findItemById, getItemsSortComparator } = require("%scripts/items/itemsManager.nut")

let MAX_REWARDS_SHOW_IN_TROPHY = 5


let rewardTypes = [ "multiAwardsOnWorthGold", "modsForBoughtUnit",
                  "unit", "rentedUnit", "premium_in_hours",
                  "trophy", "item", "unlock", "unlockType", "resource", "resourceType",
                  "entitlement", "gold", "warpoints", "exp", "warbonds", "unlockAddProgress" ]
let iconsRequired = [ "trophy", "item", "unlock", "entitlement", "resource", "unlockAddProgress" ]

let specialPrizeParams = {
  rentedUnit = function(config, prize) {
    prize.timeHours <- getTblValue("timeHours", config)
    prize.numSpares <- getTblValue("numSpares", config)
  }
  unit = function(config, prize) {
    prize.numSpares <- config?.numSpares ?? 0
  }
  resource = function(config, prize) {
    prize.resourceType <- getTblValue("resourceType", config)
  }
}

let isRewardMultiAward = @(config) config?.multiAwardsOnWorthGold != null
  || config?.modsForBoughtUnit != null

function getTrophyRewardType(config) {
  if (isRewardMultiAward(config))
    return "multiAwardsOnWorthGold" in config ? "multiAwardsOnWorthGold" : "modsForBoughtUnit"

  if (config)
    foreach (param, _value in config)
      if (isInArray(param, rewardTypes))
        return param

  log("TROPHYREWARD GETTYPE received bad config")
  debugTableData(config)
  return ""
}

function rewardsSortComparator(a, b) {
  if (!a || !b)
    return b <=> a

  let typeA = getTrophyRewardType(a)
  let typeB = getTrophyRewardType(b)
  if (typeA != typeB)
    return typeA <=> typeB

  if (typeA == "item") {
    let itemA = findItemById(a.item)
    let itemB = findItemById(b.item)
    if (itemA && itemB)
      return getItemsSortComparator()(itemA, itemB)
  }

  return (a?[typeA] ?? "") <=> (b?[typeB] ?? "")
}

let isShowItemInTrophyReward = @(extItem) extItem?.itemdef.type == "item"
  && !extItem.itemdef?.tags.devItem
  && (extItem.itemdef?.tags.showWithFeature == null || hasFeature(extItem.itemdef.tags.showWithFeature))
  && !(extItem.itemdef?.tags.hiddenInRewardWnd ?? false)

function processTrophyRewardsUserlogData(configsArray = []) {
  if (configsArray.len() == 0)
    return []

  let tempBuffer = {}
  foreach (idx, config in configsArray) {
    let rType = getTrophyRewardType(config)
    let typeVal = config?[rType]
    let count = config?.count ?? 1

    local checkBuffer = type(typeVal) == "string" ? typeVal : $"{rType}_{typeVal}"
    if (rType == "resourceType" && getTypeByResourceType(typeVal))
      checkBuffer = $"{checkBuffer}_{idx}"
    else if (isPrizeMultiAward(config) && "parentTrophyRandId" in config)
      checkBuffer = $"{checkBuffer}_{config.parentTrophyRandId}"

    if (checkBuffer not in tempBuffer)
      tempBuffer[checkBuffer] <- {
        count = count
        arrayIdx = idx
      }
    else
      tempBuffer[checkBuffer].count += count

    if (rType == "unit")
      broadcastEvent("UnitBought", { unitName = typeVal, receivedFromTrophy = true })
    else if (rType == "rentedUnit")
      broadcastEvent("UnitRented", { unitName = typeVal, receivedFromTrophy = true })
    else if (rType == "resourceType" && typeVal == decoratorTypes.DECALS.resourceType)
      broadcastEvent("DecalReceived", { id = config?.resource })
    else if (rType == "resourceType" && typeVal == decoratorTypes.ATTACHABLES.resourceType)
      broadcastEvent("AttachableReceived", { id = config?.resource })
  }

  let res = []
  foreach (block in tempBuffer) {
    let result = clone configsArray[block.arrayIdx]
    result.count <- block.count

    res.append(result)
  }

  res.sort(rewardsSortComparator)
  return res
}

function getRestRewardsNumLayer(configsArray, maxNum) {
  let restRewards = configsArray.len() - maxNum
  if (restRewards <= 0)
    return ""

  let layer = LayersIcon.findLayerCfg("item_rest_rewards_text")
  if (!layer)
    return ""

  layer.text <- loc("trophy/moreRewards", { num = restRewards })
  return LayersIcon.getTextDataFromLayer(layer)
}

function isRewardItem(rewardType) {
  return isInArray(rewardType, ["item", "trophy"])
}

function showInResults(rewardType) {
  return rewardType != "unlockType" && rewardType != "resourceType"
}

function getRewardList(config) {
  if (isRewardMultiAward(config))
    return TrophyMultiAward(DataBlockAdapter(config)).getResultPrizesList()

  let prizes = []
  foreach (rewardType in rewardTypes)
    if (rewardType in config && showInResults(rewardType)) {
      let prize = {
        [rewardType] = config[rewardType]
        count = getTblValue("count", config)
      }
      if (!isInArray(rewardType, iconsRequired))
        prize.noIcon <- true
      if (rewardType in specialPrizeParams)
        specialPrizeParams[rewardType](config, prize)

      prizes.append(DataBlockAdapter(prize))
    }
  return prizes
}

return {
  MAX_REWARDS_SHOW_IN_TROPHY
  rewardsSortComparator
  getTrophyRewardType
  isShowItemInTrophyReward
  processTrophyRewardsUserlogData
  isRewardMultiAward
  isRewardItem
  getRestRewardsNumLayer
  getRewardList
}