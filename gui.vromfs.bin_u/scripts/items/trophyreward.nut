::trophyReward <- {
  maxRewardsShow = 5

  //!!FIX ME: need to convert reward type by enum_utils
  rewardTypes = [ "multiAwardsOnWorthGold", "modsForBoughtUnit",
                  "unit", "rentedUnit",
                  "trophy", "item", "unlock", "unlockType", "resource", "resourceType",
                  "entitlement", "gold", "warpoints", "exp", "warbonds"]
  iconsRequired = [ "trophy", "item", "unlock", "entitlement", "resource" ]
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
}

trophyReward.processUserlogData <- function processUserlogData(configsArray = [])
{
  if (configsArray.len() == 0)
    return []

  local tempBuffer = {}
  foreach(idx, config in configsArray)
  {
    local rType = ::trophyReward.getType(config)
    local typeVal = config?[rType]
    local count = config?.count ?? 1

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

  local res = []
  foreach(block in tempBuffer)
  {
    local result = clone configsArray[block.arrayIdx]
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

  local typeA = ::trophyReward.getType(a)
  local typeB = ::trophyReward.getType(b)
  if (typeA != typeB)
    return typeA <=> typeB

  if (typeA == "item")
  {
    local itemA = ::ItemsManager.findItemById(a.item)
    local itemB = ::ItemsManager.findItemById(b.item)
    if (itemA && itemB)
      return ::ItemsManager.getItemsSortComparator()(itemA, itemB)
  }

  return (a?[typeA] ?? "") <=> (b?[typeB] ?? "")
}

trophyReward.getImageByConfig <- function getImageByConfig(config = null, onlyImage = true, layerCfgName = "item_place_single", imageAsItem = false)
{
  local image = ""
  local rewardType = ::trophyReward.getType(config)
  if (rewardType == "")
    return ""

  local rewardValue = config[rewardType] // warning disable: -access-potentially-nulled
  local style = "reward_" + rewardType

  if (rewardType == "multiAwardsOnWorthGold" || rewardType == "modsForBoughtUnit")
    image = ::TrophyMultiAward(::DataBlockAdapter(config)).getRewardImage()
  else if (::trophyReward.isRewardItem(rewardType))
  {
    local item = ::ItemsManager.findItemById(rewardValue)
    if (!item)
      return ""

    if (onlyImage)
      return item.getIcon()

    image = ::handyman.renderCached(("gui/items/item"), {
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
      local visCfg = getDecoratorVisualConfig(config)
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
    image = getFullWarbondsIcon(rewardValue)

  if (image == "")
    image = ::LayersIcon.getIconData(style)

  if (!isRewardMultiAward(config) && !onlyImage)
    image += getMoneyLayer(config)

  local resultImage = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg(layerCfgName), image)
  if (!imageAsItem)
    return resultImage

  return ::handyman.renderCached(("gui/items/item"), {items = [{layered_image = resultImage}]})
}

trophyReward.getDecoratorVisualConfig <- function getDecoratorVisualConfig(config)
{
  local res = {
    style = ""
    image = ""
  }

  local decoratorType = ::g_decorator_type.getTypeByResourceType(config.resourceType)
  if (decoratorType)
  {
    local decorator = ::g_decorator.getDecorator(config?.resource, decoratorType)
    local cfg = clone ::LayersIcon.findLayerCfg("item_decal")
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
  local currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
  if (!currencyCfg)
    return  ""

  local layerCfg = ::LayersIcon.findLayerCfg("roulette_money_text")
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
  local layer = ::LayersIcon.findLayerCfg("item_warpoints")
  local wpLayer = ::LayersIcon.findLayerCfg(getWPIcon(wp))
  if (layer && wpLayer)
    layer.img <- ::getTblValue("img", wpLayer, "")
  return ::LayersIcon.genDataFromLayer(layer)
}

trophyReward.getFullWarbondsIcon <- function getFullWarbondsIcon(wbId)
{
  local layer = ::LayersIcon.findLayerCfg("item_warpoints")
  layer.img <- "#ui/gameuiskin#item_warbonds"
  return ::LayersIcon.genDataFromLayer(layer)
}

trophyReward.getRestRewardsNumLayer <- function getRestRewardsNumLayer(configsArray, maxNum)
{
  local restRewards = configsArray.len() - maxNum
  if (restRewards <= 0)
    return ""

  local layer = ::LayersIcon.findLayerCfg("item_rest_rewards_text")
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
  debugTableData(config)
  return ""
}

trophyReward.getName <- function getName(config)
{
  local rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ""

  local item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getName()

  return ""
}

trophyReward.getDecription <- function getDecription(config, isFull = false)
{
  local rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ::trophyReward.getRewardText(config, isFull)

  local item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getDescription()

  return ""
}

trophyReward.getRewardText <- function getRewardText(config, isFull = false)
{
  return ::PrizesView.getPrizeText(::DataBlockAdapter(config), true, false, true, isFull)
}

trophyReward.getCommonRewardText <- function getCommonRewardText(configsArray)
{
  local result = {}
  local currencies = {}

  foreach(config in configsArray)
  {
    local currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
    if (currencyCfg)
    {
      if (!(currencyCfg.type in currencies))
        currencies[currencyCfg.type] <- currencyCfg
      else
        currencies[currencyCfg.type].val += currencyCfg.val
      continue
    }

    local rewType = ::trophyReward.getType(config)
    local rewData = {
      type = rewType
      subType = null
      num = 0
    }
    if (rewType == "item")
    {
      local item = ::ItemsManager.findItemById(config[rewType])
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
      local item = ::getTblValue("item", data)
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
    return ::TrophyMultiAward(::DataBlockAdapter(config)).getResultPrizesList()

  local prizes = []
  foreach (rewardType in rewardTypes)
    if (rewardType in config && showInResults(rewardType))
    {
      local prize = {
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
    params.header <- ::TrophyMultiAward(::DataBlockAdapter(singleReward)).getName()

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
