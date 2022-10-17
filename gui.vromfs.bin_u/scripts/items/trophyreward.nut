let TrophyMultiAward = require("%scripts/items/trophyMultiAward.nut")

::trophyReward <- {
  maxRewardsShow = 5

  //!!FIX ME: need to convert reward type by enum_utils
  rewardTypes = [ "multiAwardsOnWorthGold", "modsForBoughtUnit",
                  "unit", "rentedUnit",
                  "trophy", "item", "unlock", "unlockType", "resource", "resourceType",
                  "entitlement", "gold", "warpoints", "exp", "warbonds", "unlockAddProgress" ]
  iconsRequired = [ "trophy", "item", "unlock", "entitlement", "resource", "unlockAddProgress" ]
  specialPrizeParams = {
    rentedUnit = function(config, prize) {
      prize.timeHours <- ::getTblValue("timeHours", config)
      prize.numSpares <- ::getTblValue("numSpares", config)
    }
    resource = function(config, prize) {
      prize.resourceType <- ::getTblValue("resourceType", config)
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
    && (extItem.itemdef?.tags.showWithFeature == null || ::has_feature(extItem.itemdef.tags.showWithFeature))
    && !(extItem.itemdef?.tags.hiddenInRewardWnd ?? false)
}

trophyReward.processUserlogData <- function processUserlogData(configsArray = [])
{
  if (configsArray.len() == 0)
    return []

  let tempBuffer = {}
  foreach(idx, config in configsArray)
  {
    let rType = ::trophyReward.getType(config)
    let typeVal = config?[rType]
    let count = config?.count ?? 1

    local checkBuffer = typeVal
    if (typeof typeVal != "string")
      checkBuffer = rType + "_" + typeVal

    if (rType == "resourceType" && ::g_decorator_type.getTypeByResourceType(typeVal))
      checkBuffer = checkBuffer + "_" + idx

    if (!::getTblValue(checkBuffer, tempBuffer))
    {
      tempBuffer[checkBuffer] <- {
          count = count
          arrayIdx = idx
        }
    }
    else
      tempBuffer[checkBuffer].count += count

    if (rType == "unit")
      ::broadcastEvent("UnitBought", { unitName = typeVal, receivedFromTrophy = true })
    else if (rType == "rentedUnit")
      ::broadcastEvent("UnitRented", { unitName = typeVal, receivedFromTrophy = true })
    else if (rType == "resourceType" && typeVal == g_decorator_type.DECALS.resourceType)
      ::broadcastEvent("DecalReceived", { id = config?.resource })
    else if (rType == "resourceType" && typeVal == g_decorator_type.ATTACHABLES.resourceType)
      ::broadcastEvent("AttachableReceived", { id = config?.resource })
  }

  let res = []
  foreach(block in tempBuffer)
  {
    let result = clone configsArray[block.arrayIdx]
    result.count <- block.count

    res.append(result)
  }

  res.sort(rewardsSortComparator)
  return res
}

trophyReward.rewardsSortComparator <- function rewardsSortComparator(a, b)
{
  if (!a || !b)
    return b <=> a

  let typeA = ::trophyReward.getType(a)
  let typeB = ::trophyReward.getType(b)
  if (typeA != typeB)
    return typeA <=> typeB

  if (typeA == "item")
  {
    let itemA = ::ItemsManager.findItemById(a.item)
    let itemB = ::ItemsManager.findItemById(b.item)
    if (itemA && itemB)
      return ::ItemsManager.getItemsSortComparator()(itemA, itemB)
  }

  return (a?[typeA] ?? "") <=> (b?[typeB] ?? "")
}

trophyReward.getImageByConfig <- function getImageByConfig(config = null, onlyImage = true, layerCfgName = "item_place_single", imageAsItem = false)
{
  local image = ""
  let rewardType = ::trophyReward.getType(config)
  if (rewardType == "")
    return ""

  let rewardValue = config[rewardType] // warning disable: -access-potentially-nulled
  local style = "reward_" + rewardType

  if (rewardType == "multiAwardsOnWorthGold" || rewardType == "modsForBoughtUnit"){
    let trophyMultiAward = TrophyMultiAward(::DataBlockAdapter(config))
    image = onlyImage ? trophyMultiAward.getOnlyRewardImage() : trophyMultiAward.getRewardImage()
  }
  else if (::trophyReward.isRewardItem(rewardType))
  {
    let item = ::ItemsManager.findItemById(rewardValue)
    if (item?.isHiddenItem() ?? true)
      return ""

    if (onlyImage)
      return item.getIcon()

    image = ::handyman.renderCached(("%gui/items/item"), {
      items = item.getViewData({
            enableBackground = config?.enableBackground ?? false,
            showAction = false,
            showPrice = false,
            contentIcon = false,
            shouldHideAdditionalAmmount = true,
            hasCraftTimer = false,
            count = ::getTblValue("count", config, 0)
          })
      })
    return image
  }
  else if (rewardType == "unit" || rewardType == "rentedUnit")
    style += "_" + ::getUnitTypeText(::get_es_unit_type(::getAircraftByName(rewardValue))).tolower()
  else if (rewardType == "resource" || rewardType == "resourceType")
  {
    if (config.resourceType)
    {
      let visCfg = getDecoratorVisualConfig(config)
      style = visCfg.style
      image = visCfg.image
    }
  }
  else if (rewardType == "unlockType")
  {
    style = "reward_" + rewardValue
    if (!::LayersIcon.findStyleCfg(style))
      style = "reward_unlock"
  }
  else if (rewardType == "warpoints")
    image = getFullWPIcon(rewardValue)
  else if (rewardType == "warbonds")
    image = getFullWarbondsIcon()

  if (image == "")
    image = ::LayersIcon.getIconData(style)

  if (!isRewardMultiAward(config) && !onlyImage)
    image += getMoneyLayer(config)

  let resultImage = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg(layerCfgName), image)
  if (!imageAsItem)
    return resultImage

  let tooltipConfig = ::PrizesView.getPrizeTooltipConfig(config)
  return ::handyman.renderCached(("%gui/items/item"), {items = [tooltipConfig.__update({
    layered_image = resultImage,
    hasFocusBorder = true })]})
}

trophyReward.getDecoratorVisualConfig <- function getDecoratorVisualConfig(config)
{
  let res = {
    style = ""
    image = ""
  }

  let decoratorType = ::g_decorator_type.getTypeByResourceType(config.resourceType)
  if (decoratorType)
  {
    let decorator = ::g_decorator.getDecorator(config?.resource, decoratorType)
    let cfg = clone ::LayersIcon.findLayerCfg("item_decal")
    cfg.img <- decoratorType.getImage(decorator)
    if (cfg.img != "")
      res.image = ::LayersIcon.genDataFromLayer(cfg)
  }

  if (res.image == "")
  {
    res.style = "reward_" + config.resourceType
    if (!::LayersIcon.findStyleCfg(res.style))
      res.style = "reward_unlock"
  }

  return res
}

trophyReward.getMoneyLayer <- function getMoneyLayer(config)
{
  let currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
  if (!currencyCfg)
    return  ""

  let layerCfg = ::LayersIcon.findLayerCfg("roulette_money_text")
  if (!layerCfg)
    return ""

  layerCfg.text <- currencyCfg.printFunc(currencyCfg.val)
  return ::LayersIcon.getTextDataFromLayer(layerCfg)
}

trophyReward.getWPIcon <- function getWPIcon(wp)
{
  local icon = ""
  foreach (v in wpIcons)
    if (wp >= v.value || icon == "")
      icon = v.icon
  return icon
}

trophyReward.getFullWPIcon <- function getFullWPIcon(wp)
{
  return ::LayersIcon.getIconData(getWPIcon(wp), null, null, "reward_warpoints")
}

trophyReward.getFullWarbondsIcon <- function getFullWarbondsIcon()
{
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("item_warbonds"))
}

trophyReward.getRestRewardsNumLayer <- function getRestRewardsNumLayer(configsArray, maxNum)
{
  let restRewards = configsArray.len() - maxNum
  if (restRewards <= 0)
    return ""

  let layer = ::LayersIcon.findLayerCfg("item_rest_rewards_text")
  if (!layer)
    return ""

  layer.text <- ::loc("trophy/moreRewards", {num = restRewards})
  return ::LayersIcon.getTextDataFromLayer(layer)
}

trophyReward.getReward <- function getReward(configsArray = [])
{
  if (configsArray.len() == 1)
    return ::trophyReward.getRewardText(configsArray[0])

  return ::trophyReward.getCommonRewardText(configsArray)
}

trophyReward.isRewardItem <- function isRewardItem(rewardType)
{
  return ::isInArray(rewardType, ["item", "trophy"])
}

trophyReward.getType <- function getType(config)
{
  if (isRewardMultiAward(config))
    return "multiAwardsOnWorthGold" in config? "multiAwardsOnWorthGold" : "modsForBoughtUnit"

  if (config)
    foreach(param, value in config)
      if (::isInArray(param, rewardTypes))
        return param

  ::dagor.debug("TROPHYREWARD::GETTYPE recieved bad config")
  ::debugTableData(config)
  return ""
}

trophyReward.getName <- function getName(config)
{
  let rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ""

  let item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getName()

  return ""
}

trophyReward.getRewardText <- function getRewardText(config, isFull = false, color = "")
{
  return ::PrizesView.getPrizeText(::DataBlockAdapter(config), true, false, true, isFull, color)
}

trophyReward.getCommonRewardText <- function getCommonRewardText(configsArray)
{
  let result = {}
  local currencies = {}

  foreach(config in configsArray)
  {
    let currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
    if (currencyCfg)
    {
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
    if (rewType == "item")
    {
      let item = ::ItemsManager.findItemById(config[rewType])
      if (item)
      {
        rewData.subType <- item.iType
        rewData.item <- item
        rewType = rewType + "_" + item.iType
      }
    }
    else
      rewData.config <- config

    if (!::getTblValue(rewType, result))
      result[rewType] <- rewData

    result[rewType].num++;
  }

  currencies = ::u.values(currencies)
  currencies.sort(@(a, b) a.type <=> b.type)
  currencies = ::u.map(currencies, @(c) c.printFunc(c.val))
  currencies = ::g_string.implode(currencies, ::loc("ui/comma"))

  local returnData = [ currencies ]

  foreach(data in result)
  {
    if (data.type == "item")
    {
      let item = ::getTblValue("item", data)
      if (item)
        returnData.append(item.getTypeName() + ::loc("ui/colon") + data.num)
    }
    else
    {
      local text = ::trophyReward.getRewardText(data.config)
      if (data.num > 1)
        text += ::loc("ui/colon") + data.num
      returnData.append(text)
    }
  }
  returnData = ::g_string.implode(returnData, ", ")
  return ::colorize("activeTextColor", returnData)
}

trophyReward.isRewardMultiAward <- function isRewardMultiAward(config)
{
  return ::getTblValue("multiAwardsOnWorthGold", config) != null
         || ::getTblValue("modsForBoughtUnit", config) != null
}

trophyReward.showInResults <- function showInResults(rewardType)
{
  return rewardType != "unlockType" && rewardType != "resourceType"
}

trophyReward.getRewardList <- function getRewardList(config)
{
  if (isRewardMultiAward(config))
    return TrophyMultiAward(::DataBlockAdapter(config)).getResultPrizesList()

  let prizes = []
  foreach (rewardType in rewardTypes)
    if (rewardType in config && showInResults(rewardType))
    {
      let prize = {
        [rewardType] = config[rewardType]
        count = ::getTblValue("count", config)
      }
      if (!::isInArray(rewardType, iconsRequired))
        prize.noIcon <- true
      if (rewardType in specialPrizeParams)
        specialPrizeParams[rewardType](config, prize)

      prizes.append(::DataBlockAdapter(prize))
    }
  return prizes
}

trophyReward.getRewardsListViewData <- function getRewardsListViewData(config, params = {})
{
  local rewardsList = []
  local singleReward = config
  if (typeof(config) != "array")
    rewardsList = getRewardList(config)
  else
  {
    singleReward = (config.len() == 1) ? config[0] : null
    foreach(cfg in config)
      rewardsList.extend(getRewardList(cfg))
  }

  if (singleReward != null && ::getTblValue("multiAwardHeader", params)
      && isRewardMultiAward(singleReward))
    params.header <- TrophyMultiAward(::DataBlockAdapter(singleReward)).getName()

  params.receivedPrizes <- true

  return ::PrizesView.getPrizesListView(rewardsList, params)
}

trophyReward.getRewardType <- function getRewardType(prize)
{
  foreach (rewardType in rewardTypes)
    if (rewardType in prize)
      return rewardType
  return ""
}

trophyReward.getFullDescriptonView <- function getFullDescriptonView(prizeConfig = {}) {
  let view = {
    textTitle = getRewardText(prizeConfig, false)
    prizeImg = getImageByConfig(prizeConfig, true)
    textDesc = ::PrizesView.getDescriptonView(prizeConfig).textDesc
    markupDesc = ::PrizesView.getDescriptonView(prizeConfig).markupDesc
  }

  return ::handyman.renderCached("%gui/items/trophyRewardDesc", view)
}