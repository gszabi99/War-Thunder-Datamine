//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

let TrophyMultiAward = require("%scripts/items/trophyMultiAward.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/types.nut")

function rewardsSortComparator(a, b) {
  if (!a || !b)
    return b <=> a

  let typeA = ::trophyReward.getType(a)
  let typeB = ::trophyReward.getType(b)
  if (typeA != typeB)
    return typeA <=> typeB

  if (typeA == "item") {
    let itemA = ::ItemsManager.findItemById(a.item)
    let itemB = ::ItemsManager.findItemById(b.item)
    if (itemA && itemB)
      return ::ItemsManager.getItemsSortComparator()(itemA, itemB)
  }

  return (a?[typeA] ?? "") <=> (b?[typeB] ?? "")
}

::trophyReward <- {
  maxRewardsShow = 5

  //!!FIX ME: need to convert reward type by enum_utils
  rewardTypes = [ "multiAwardsOnWorthGold", "modsForBoughtUnit",
                  "unit", "rentedUnit", "premium_in_hours",
                  "trophy", "item", "unlock", "unlockType", "resource", "resourceType",
                  "entitlement", "gold", "warpoints", "exp", "warbonds", "unlockAddProgress" ]
  iconsRequired = [ "trophy", "item", "unlock", "entitlement", "resource", "unlockAddProgress" ]
  specialPrizeParams = {
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

  wpIcons = [
    { value = 1000, icon = "battle_trophy1k" },
    { value = 5000, icon = "battle_trophy5k" },
    { value = 10000, icon = "battle_trophy10k" },
    { value = 50000, icon = "battle_trophy50k" },
    { value = 100000, icon = "battle_trophy100k" },
    { value = 1000000, icon = "battle_trophy1kk" },
  ]

  isShowItemInTrophyReward = @(extItem) extItem?.itemdef.type == "item"
    && !extItem.itemdef?.tags.devItem
    && (extItem.itemdef?.tags.showWithFeature == null || hasFeature(extItem.itemdef.tags.showWithFeature))
    && !(extItem.itemdef?.tags.hiddenInRewardWnd ?? false)
}

::trophyReward.processUserlogData <- function processUserlogData(configsArray = []) {
  if (configsArray.len() == 0)
    return []

  let tempBuffer = {}
  foreach (idx, config in configsArray) {
    let rType = ::trophyReward.getType(config)
    let typeVal = config?[rType]
    let count = config?.count ?? 1

    local checkBuffer = type(typeVal) == "string" ? typeVal : $"{rType}_{typeVal}"
    if (rType == "resourceType" && getTypeByResourceType(typeVal))
      checkBuffer = $"{checkBuffer}_{idx}"
    else if (::PrizesView.isPrizeMultiAward(config) && "parentTrophyRandId" in config)
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

::trophyReward.getImageByConfig <- function getImageByConfig(config = null, onlyImage = true, layerCfgName = "item_place_single", imageAsItem = false) {
  local image = ""
  let rewardType = ::trophyReward.getType(config)
  if (rewardType == "" || config == null)
    return ""

  let rewardValue = config[rewardType]
  local style = "reward_" + rewardType

  if (rewardType == "multiAwardsOnWorthGold" || rewardType == "modsForBoughtUnit") {
    let trophyMultiAward = TrophyMultiAward(DataBlockAdapter(config))
    image = onlyImage ? trophyMultiAward.getOnlyRewardImage() : trophyMultiAward.getRewardImage()
  }
  else if (::trophyReward.isRewardItem(rewardType)) {
    let item = ::ItemsManager.findItemById(rewardValue)
    if (item?.isHiddenItem() ?? true)
      return ""

    if (onlyImage)
      return item.getIcon()
    let { hideCount = false } = config
    image = handyman.renderCached(("%gui/items/item.tpl"), {
      items = item.getViewData({
            enableBackground = config?.enableBackground ?? false,
            showAction = false,
            showPrice = false,
            contentIcon = false,
            shouldHideAdditionalAmmount = true,
            hasCraftTimer = false,
            count = hideCount ? 0 : config?.count ?? 0
          })
      })
    return image
  }
  else if (rewardType == "unit" || rewardType == "rentedUnit")
    style += "_" + ::getUnitTypeText(getEsUnitType(getAircraftByName(rewardValue))).tolower()
  else if (rewardType == "resource" || rewardType == "resourceType") {
    if (config.resourceType) {
      let visCfg = this.getDecoratorVisualConfig(config)
      style = visCfg.style
      image = visCfg.image
    }
  }
  else if (rewardType == "unlockType") {
    style = "reward_" + rewardValue
    if (!LayersIcon.findStyleCfg(style))
      style = "reward_unlock"
  }
  else if (rewardType == "warpoints")
    image = this.getFullWPIcon(rewardValue)
  else if (rewardType == "warbonds")
    image = this.getFullWarbondsIcon()
  else if (rewardType == "unlock") {
    local unlock = null
    let rewardConfig = getUnlockById(rewardValue)
    if (rewardConfig != null) {
      let unlockConditions = ::build_conditions_config(rewardConfig)
      unlock = ::build_log_unlock_data(unlockConditions)
    }
    image = LayersIcon.getIconData(unlock?.iconStyle ?? "", unlock?.descrImage ?? "")
  }
  else if (rewardType == "unlockAddProgress") {
    image = LayersIcon.getIconData("", ::PrizesView.getPrizeTypeIcon(config))
  }
  else if (rewardType == "premium_in_hours")
    style = "reward_entitlement"

  if (image == "")
    image = LayersIcon.getIconData(style)

  if (!this.isRewardMultiAward(config) && !onlyImage)
    image += this.getMoneyLayer(config)

  let resultImage = LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg(layerCfgName), image)
  if (!imageAsItem)
    return resultImage

  let tooltipConfig = ::PrizesView.getPrizeTooltipConfig(config)
  return handyman.renderCached(("%gui/items/reward_item.tpl"), { items = [tooltipConfig.__update({
    layered_image = resultImage,
    hasFocusBorder = true })] })
}

::trophyReward.getDecoratorVisualConfig <- function getDecoratorVisualConfig(config) {
  let res = {
    style = ""
    image = ""
  }

  let decoratorType = getTypeByResourceType(config.resourceType)
  if (decoratorType) {
    let decorator = getDecorator(config?.resource, decoratorType)
    let cfg = clone LayersIcon.findLayerCfg("item_decal")
    cfg.img <- decoratorType.getImage(decorator)
    if (cfg.img != "")
      res.image = LayersIcon.genDataFromLayer(cfg)
  }

  if (res.image == "") {
    res.style = "reward_" + config.resourceType
    if (!LayersIcon.findStyleCfg(res.style))
      res.style = "reward_unlock"
  }

  return res
}

::trophyReward.getMoneyLayer <- function getMoneyLayer(config) {
  let currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
  if (!currencyCfg)
    return  ""

  let layerCfg = LayersIcon.findLayerCfg("roulette_money_text")
  if (!layerCfg)
    return ""

  layerCfg.text <- currencyCfg.printFunc(currencyCfg.val)
  return LayersIcon.getTextDataFromLayer(layerCfg)
}

::trophyReward.getWPIcon <- function getWPIcon(wp) {
  local icon = ""
  foreach (v in this.wpIcons)
    if (wp >= v.value || icon == "")
      icon = v.icon
  return icon
}

::trophyReward.getFullWPIcon <- function getFullWPIcon(wp) {
  return LayersIcon.getIconData(this.getWPIcon(wp), null, null, "reward_warpoints")
}

::trophyReward.getFullWarbondsIcon <- function getFullWarbondsIcon() {
  return LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("item_warbonds"))
}

::trophyReward.getRestRewardsNumLayer <- function getRestRewardsNumLayer(configsArray, maxNum) {
  let restRewards = configsArray.len() - maxNum
  if (restRewards <= 0)
    return ""

  let layer = LayersIcon.findLayerCfg("item_rest_rewards_text")
  if (!layer)
    return ""

  layer.text <- loc("trophy/moreRewards", { num = restRewards })
  return LayersIcon.getTextDataFromLayer(layer)
}

::trophyReward.getReward <- function getReward(configsArray = []) {
  if (configsArray.len() == 1)
    return ::trophyReward.getRewardText(configsArray[0])

  return ::trophyReward.getCommonRewardText(configsArray)
}

::trophyReward.isRewardItem <- function isRewardItem(rewardType) {
  return isInArray(rewardType, ["item", "trophy"])
}

::trophyReward.getType <- function getType(config) {
  if (this.isRewardMultiAward(config))
    return "multiAwardsOnWorthGold" in config ? "multiAwardsOnWorthGold" : "modsForBoughtUnit"

  if (config)
    foreach (param, _value in config)
      if (isInArray(param, this.rewardTypes))
        return param

  log("TROPHYREWARD::GETTYPE received bad config")
  debugTableData(config)
  return ""
}

::trophyReward.getName <- function getName(config) {
  let rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ""

  let item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getName()

  return ""
}

::trophyReward.getRewardText <- function getRewardText(config, isFull = false, color = "") {
  return ::PrizesView.getPrizeText(DataBlockAdapter(config), true, false, true, isFull, color)
}

::trophyReward.getCommonRewardText <- function getCommonRewardText(configsArray) {
  let result = {}
  local currencies = {}

  foreach (config in configsArray) {
    let currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
    if (currencyCfg) {
      if (!(currencyCfg.type in currencies))
        currencies[currencyCfg.type] <- currencyCfg
      else
        currencies[currencyCfg.type].val += currencyCfg.val
      continue
    }

    local rewType = ::trophyReward.getType(config)
    let rewData = {
      type = rewType
      subType = null
      num = 0
    }
    if (rewType == "item") {
      let item = ::ItemsManager.findItemById(config[rewType])
      if (item) {
        rewData.subType <- item.iType
        rewData.item <- item
        rewType = rewType + "_" + item.iType
      }
    }
    else
      rewData.config <- config

    if (!getTblValue(rewType, result))
      result[rewType] <- rewData

    result[rewType].num++;
  }

  currencies = u.values(currencies)
  currencies.sort(@(a, b) a.type <=> b.type)
  currencies = currencies.map(@(c) c.printFunc(c.val))
  currencies = loc("ui/comma").join(currencies, true)

  local returnData = [ currencies ]

  foreach (data in result) {
    if (data.type == "item") {
      let item = getTblValue("item", data)
      if (item)
        returnData.append(item.getTypeName() + loc("ui/colon") + data.num)
    }
    else {
      local text = ::trophyReward.getRewardText(data.config)
      if (data.num > 1)
        text += loc("ui/colon") + data.num
      returnData.append(text)
    }
  }
  returnData = ", ".join(returnData, true)
  return colorize("activeTextColor", returnData)
}

::trophyReward.isRewardMultiAward <- function isRewardMultiAward(config) {
  return getTblValue("multiAwardsOnWorthGold", config) != null
         || getTblValue("modsForBoughtUnit", config) != null
}

::trophyReward.showInResults <- function showInResults(rewardType) {
  return rewardType != "unlockType" && rewardType != "resourceType"
}

::trophyReward.getRewardList <- function getRewardList(config) {
  if (this.isRewardMultiAward(config))
    return TrophyMultiAward(DataBlockAdapter(config)).getResultPrizesList()

  let prizes = []
  foreach (rewardType in this.rewardTypes)
    if (rewardType in config && this.showInResults(rewardType)) {
      let prize = {
        [rewardType] = config[rewardType]
        count = getTblValue("count", config)
      }
      if (!isInArray(rewardType, this.iconsRequired))
        prize.noIcon <- true
      if (rewardType in this.specialPrizeParams)
        this.specialPrizeParams[rewardType](config, prize)

      prizes.append(DataBlockAdapter(prize))
    }
  return prizes
}

::trophyReward.getRewardsListViewData <- function getRewardsListViewData(config, params = {}) {
  local rewardsList = []
  local singleReward = config
  if (type(config) != "array")
    rewardsList = this.getRewardList(config)
  else {
    singleReward = (config.len() == 1) ? config[0] : null
    foreach (cfg in config)
      rewardsList.extend(this.getRewardList(cfg))
  }

  if (singleReward != null && getTblValue("multiAwardHeader", params)
      && this.isRewardMultiAward(singleReward))
    params.header <- TrophyMultiAward(DataBlockAdapter(singleReward)).getName()

  params.receivedPrizes <- true

  return ::PrizesView.getPrizesListView(rewardsList, params)
}

::trophyReward.getRewardType <- function getRewardType(prize) {
  foreach (rewardType in this.rewardTypes)
    if (rewardType in prize)
      return rewardType
  return ""
}

::trophyReward.getFullDescriptonView <- function getFullDescriptonView(prizeConfig = {}) {
  let view = {
    textTitle = this.getRewardText(prizeConfig, false)
    prizeImg = this.getImageByConfig(prizeConfig, true)
    textDesc = ::PrizesView.getDescriptonView(prizeConfig).textDesc
    markupDesc = ::PrizesView.getDescriptonView(prizeConfig).markupDesc
  }

  return handyman.renderCached("%gui/items/trophyRewardDesc.tpl", view)
}

return {
  rewardsSortComparator
}