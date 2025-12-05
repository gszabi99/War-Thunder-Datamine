from "%scripts/dagui_natives.nut" import get_name_by_unlock_type
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isArray } = require("%sqStdLibs/helpers/u.nut")

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoRoles.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockType } = require("%scripts/unlocks/unlocksModule.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getUnitTypeTextByUnit } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByUnlockedItemType } = require("%scripts/customization/types.nut")
let { buildUnitSlot } = require("%scripts/slotbar/slotbarView.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getWPIcon } = require("%scripts/items/prizesView.nut")

let template = "%gui/items/trophyDesc.tpl"
let singleItemIconLayer = "item_place_single"
let itemContainerLayer = "trophy_reward_place"

const MIN_ITEMS_OFFSET = 0.5
const MAX_ITEMS_OFFSET = 1

function getIncomeView(gold, wp) {
  let res = []
  if (gold)
    res.append({
      icon = "#ui/gameuiskin#item_type_eagles.svg"
      title = gold.tostring()
    })

  if (wp)
    res.append({
      icon = "#ui/gameuiskin#item_type_warpoints.svg"
      title = wp.tostring()
    })

  return res
}

let getEntitlementGiftView = @(entitlement) (entitlement?.entitlementGift ?? []).map(function(giftId) {
  let config = getEntitlementConfig(giftId)
  if (config)
    return {
      icon = "#ui/gameuiskin#item_type_premium.svg"
      title = colorize("userlogColoredText", getEntitlementName(config))
    }

  return null
})

let getUnlockView = @(entitlement) (entitlement?.unlockGift ?? []).map(function(unlockId) {
  let unlockType = getUnlockType(unlockId)
  let typeValid = unlockType >= 0
  let unlockTypeText = typeValid ? get_name_by_unlock_type(unlockType) : "unknown"

  local unlockTypeName = loc($"trophy/unlockables_names/{unlockTypeText}")
  unlockTypeName = colorize(typeValid ? "activeTextColor" : "red", unlockTypeName)

  local name = unlockTypeName

  local nameText = getUnlockNameText(unlockType, unlockId)
  nameText = colorize(typeValid ? "userlogColoredText" : "red", nameText)
  if (unlockType != UNLOCKABLE_SLOT && nameText != "")
    name = loc("ui/colon").concat(name, nameText)

  return {
    title = name
    icon = getTypeByUnlockedItemType(unlockType).prizeTypeIcon
  }
})

function getDecoratorActionButtonsView(decorator, decoratorType) {
  if (!(decorator?.canPreview() ?? false))
    return []

  let gcb = globalCallbacks.DECORATOR_PREVIEW
  return [{
    image = "#ui/gameuiskin#btn_preview.svg"
    tooltip = "#mainmenu/btnPreview"
    funcName = gcb.cbName
    actionParamsMarkup = gcb.getParamsMarkup({
      resource = decorator.id,
      resourceType = decoratorType.resourceType
    })
  }]
}

let getDecoratorGiftView = @(giftArray, decoratorType, params) (giftArray ?? []).map(function(giftId) {
  let locName = decoratorType.getLocName(giftId, true)
  let decorator = getDecorator(giftId, decoratorType)
  let nameColor = decorator ? decorator.getRarityColor() : "activeTextColor"
  let isHave = params?.ignoreAvailability ? false : decoratorType.isPlayerHaveDecorator(giftId)
  let buttons = getDecoratorActionButtonsView(decorator, decoratorType)

  return {
    title = colorize(nameColor, locName)
    icon = decoratorType.prizeTypeIcon
    tooltipId = getTooltipType("DECORATION").getTooltipId(giftId, decoratorType.unlockedItemType)
    commentText = isHave ? colorize("badTextColor", loc("mainmenu/receiveOnlyOnce")) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
})

function getUnitActionButtonsView(unit) {
  if ((unit.isInShop ?? false) == false)
    return []

  let gcb = globalCallbacks.UNIT_PREVIEW
  return [{
    image = "#ui/gameuiskin#btn_preview.svg"
    tooltip = "#mainmenu/btnPreview"
    funcName = gcb.cbName
    actionParamsMarkup = gcb.getParamsMarkup({ unitId = unit.name })
  }]
}

let getUnitsGiftView = @(entitlement, params) (entitlement?.aircraftGift ?? []).map(function(unitName) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return null

  let ignoreAvailability = params?.ignoreAvailability
  let isBought = ignoreAvailability ? false : unit.isBought()
  let classIco = getUnitClassIco(unit)
  let shopItemType = getUnitRole(unit)
  let buttons = getUnitActionButtonsView(unit)
  let receiveOnce = "mainmenu/receiveOnlyOnce"

  let unitPlate = buildUnitSlot(unitName, unit, {
    status = ignoreAvailability ? "owned" : isBought ? "locked" : "canBuy"
    isLocalState = !ignoreAvailability
    showAsTrophyContent = true
    tooltipParams = {
      showLocalState = true
    }
  })
  return {
    classIco = classIco,
    shopItemType = shopItemType,
    unitPlate = unitPlate,
    commentText = isBought ? colorize("badTextColor", loc(receiveOnce)) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
})

function getEntitlementView(entitlement, params = {}) {
  if (type(entitlement) == "string")
    entitlement = getEntitlementConfig(entitlement)

  if (!entitlement)
    return ""

  let view = params
  view.list <- []
  view.list.extend(getIncomeView(entitlement?.goldIncome, entitlement?.wpIncome))
  view.list.extend(getEntitlementGiftView(entitlement))
  view.list.extend(getUnlockView(entitlement))
  view.list.extend(getDecoratorGiftView(entitlement?.decalGift, decoratorTypes.DECALS, params))
  view.list.extend(getDecoratorGiftView(entitlement?.attachableGift, decoratorTypes.ATTACHABLES, params))
  view.list.extend(getDecoratorGiftView(entitlement?.skinGift, decoratorTypes.SKINS, params))
  view.list.extend(getUnitsGiftView(entitlement, params))
  return handyman.renderCached(template, view)
}

let generateLayers = function(layersArray) {
  let offsetByItem = LayersIcon.getOffset(layersArray.len(), MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET)
  let offsetAllItems = (layersArray.len() - 1) / 2.0
  let res = layersArray.map(function(imageLayer, idx) {
    return LayersIcon.genDataFromLayer(
      { x = $"({offsetByItem} * {idx - offsetAllItems})@itemWidth", w = "1@itemWidth", h = "1@itemWidth" },
      LayersIcon.genDataFromLayer(
        LayersIcon.findLayerCfg(singleItemIconLayer),
        imageLayer
      )
    )
  })
  return LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg(itemContainerLayer), "".join(res))
}

let getDecoratorLayeredIcon = @(giftArray, decoratorType) (giftArray ?? []).map(function(giftId) {
  let decorator = getDecorator(giftId, decoratorType)
  let cfg = clone LayersIcon.findLayerCfg("item_decal")
  cfg.img <- decoratorType.getImage(decorator)

  local image = ""
  if (cfg.img != "")
    image = LayersIcon.genDataFromLayer(cfg)

  if (image == "")
    image = LayersIcon.getIconData($"reward_{decoratorType.resourceType}")

  return image
})

let getUnitLayeredIcon = @(unitArray) (unitArray ?? []).map(function(unitId) {
  let unitType = getUnitTypeTextByUnit(getAircraftByName(unitId)).tolower()
  return LayersIcon.getIconData($"reward_unit_{unitType}")
})

function getIconsCount(layers) {
  return layers.reduce(@(count, iconsArr) count += (iconsArr?.len() ?? 0), 0)
}

function reduceIconsCount(layers, maxCount) {
  let totalCount = getIconsCount(layers)
  if (maxCount == -1 || totalCount <= maxCount)
    return { icons = layers, totalCount, reducedCount = totalCount }

  let counts = layers.map(@(icons) icons?.len() ?? 0)
  let resCounts = counts.map(@(_c) 0)
  local resCount = 0

  while (resCount < maxCount - 1)
    foreach (index, count in counts) {
      if (count > 0) {
        counts[index] = count-1
        resCounts[index] = resCounts[index] + 1
        resCount++
      }
    }

  let resLayers = []
  foreach (index, count in resCounts)
    if (count > 0)
      resLayers.extend(layers[index].filter(@(_val, idx) idx < count))

  return { icons = resLayers, totalCount, reducedCount = maxCount }
}

function getSortedLayersIcons(entitlement) {
  if (!entitlement)
    return []

  let tempIcons = []
  tempIcons.append(entitlement?.goldIncome != null ? [LayersIcon.getIconData("reward_gold")] : null)
  tempIcons.append(entitlement?.wpIncome != null ? [LayersIcon.getIconData(getWPIcon(entitlement.wpIncome))] : null)

  let layerStyles = []
  layerStyles.extend((entitlement?.entitlementGift ?? [])
    .filter(@(entId) getEntitlementConfig(entId) != null)
    .map(@(_entId) "reward_entitlement")
  )
  layerStyles.extend((entitlement?.unlockGift ?? []).map(@(_unlockId) "reward_unlock"))

  tempIcons.append(layerStyles.map(@(style) LayersIcon.getIconData(style)))
  tempIcons.append(getDecoratorLayeredIcon(entitlement?.decalGift, decoratorTypes.DECALS))
  tempIcons.append(getDecoratorLayeredIcon(entitlement?.attachableGift, decoratorTypes.ATTACHABLES))
  tempIcons.append(getDecoratorLayeredIcon(entitlement?.skinGift, decoratorTypes.SKINS))
  tempIcons.append(getUnitLayeredIcon(entitlement?.aircraftGift))
  return tempIcons
}

function getEntitlementLayerIconsConfig(entitlement, params = null) {
  if (type(entitlement) == "string")
    entitlement = getEntitlementConfig(entitlement)

  if (!entitlement)
    return { icons = "", totalCount = 0, count = 0 }

  let allIcons = getSortedLayersIcons(entitlement)
  let { maxCount = -1 } = params
  let reducedIconsData = reduceIconsCount(allIcons, maxCount)

  let layersArray = []
  foreach (val in reducedIconsData.icons) {
    if ((val?.len() ?? 0) == 0)
      continue
    if (isArray(val))
      layersArray.extend(val)
    else
      layersArray.append(val)
  }
  return {
    icons = generateLayers(layersArray),
    totalCount = reducedIconsData.totalCount,
    count = reducedIconsData.reducedCount
  }
}

return {
  getEntitlementView
  getEntitlementLayerIconsConfig
}