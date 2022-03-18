let { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")
let { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
let globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")

let template = "%gui/items/trophyDesc"
let singleItemIconLayer = "item_place_single"
let itemContainerLayer = "trophy_reward_place"

const MIN_ITEMS_OFFSET = 0.5
const MAX_ITEMS_OFFSET = 1

let function getIncomeView(gold, wp) {
  let res = []
  if (gold)
    res.append({
      icon = "#ui/gameuiskin#item_type_eagles"
      title = gold.tostring()
    })

  if (wp)
    res.append({
      icon = "#ui/gameuiskin#item_type_warpoints"
      title = wp.tostring()
    })

  return res
}

let getEntitlementGiftView = @(entitlement) (entitlement?.entitlementGift ?? []).map(function(giftId) {
  let config = getEntitlementConfig(giftId)
  if (config)
    return {
      icon = "#ui/gameuiskin#item_type_premium"
      title = ::colorize("userlogColoredText", getEntitlementName(config))
    }

  return null
})

let getUnlockView = @(entitlement) (entitlement?.unlockGift ?? []).map(function(unlockId) {
  let unlockType = ::get_unlock_type_by_id(unlockId)
  let typeValid = unlockType >= 0
  let unlockTypeText = typeValid ? ::get_name_by_unlock_type(unlockType) : "unknown"

  local unlockTypeName = ::loc($"trophy/unlockables_names/{unlockTypeText}")
  unlockTypeName = ::colorize(typeValid ? "activeTextColor" : "red", unlockTypeName)

  local name = unlockTypeName

  local nameText = ::get_unlock_name_text(unlockType, unlockId)
  nameText = ::colorize(typeValid ? "userlogColoredText" : "red", nameText)
  if (unlockType != ::UNLOCKABLE_SLOT && nameText != "")
    name += ::loc("ui/colon") + nameText

  return {
    title = name
    icon = ::g_decorator_type.getTypeByUnlockedItemType(unlockType).prizeTypeIcon
  }
})

let function getDecoratorActionButtonsView(decorator, decoratorType) {
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
  let decorator = ::g_decorator.getDecorator(giftId, decoratorType)
  let nameColor = decorator ? decorator.getRarityColor() : "activeTextColor"
  let isHave = params?.ignoreAvailability ? false : decoratorType.isPlayerHaveDecorator(giftId)
  let buttons = getDecoratorActionButtonsView(decorator, decoratorType)

  return {
    title = ::colorize(nameColor, locName)
    icon = decoratorType.prizeTypeIcon
    tooltipId = ::g_tooltip.getIdDecorator(giftId, decoratorType.unlockedItemType)
    commentText = isHave ? ::colorize("badTextColor", ::loc("mainmenu/receiveOnlyOnce")) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
})

let function getUnitActionButtonsView(unit) {
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
  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return null

  let ignoreAvailability = params?.ignoreAvailability
  let isBought = ignoreAvailability ? false : unit.isBought()
  let classIco = ::getUnitClassIco(unit)
  let shopItemType = getUnitRole(unit)
  let buttons = getUnitActionButtonsView(unit)
  let receiveOnce = "mainmenu/receiveOnlyOnce"

  let unitPlate = ::build_aircraft_item(unitName, unit, {
    hasActions = true
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
    commentText = isBought? ::colorize("badTextColor", ::loc(receiveOnce)) : null
    buttons = buttons
    buttonsCount = buttons.len()
  }
})

local function getEntitlementView(entitlement, params = {}) {
  if (typeof entitlement == "string")
    entitlement = getEntitlementConfig(entitlement)

  if (!entitlement)
    return ""

  let view = params
  view.list <- []
  view.list.extend(getIncomeView(entitlement?.goldIncome, entitlement?.wpIncome))
  view.list.extend(getEntitlementGiftView(entitlement))
  view.list.extend(getUnlockView(entitlement))
  view.list.extend(getDecoratorGiftView(entitlement?.decalGift, ::g_decorator_type.DECALS, params))
  view.list.extend(getDecoratorGiftView(entitlement?.attachableGift, ::g_decorator_type.ATTACHABLES, params))
  view.list.extend(getDecoratorGiftView(entitlement?.skinGift, ::g_decorator_type.SKINS, params))
  view.list.extend(getUnitsGiftView(entitlement, params))
  return ::handyman.renderCached(template, view)
}

let generateLayers = function(layersArray) {
  let offsetByItem = ::LayersIcon.getOffset(layersArray.len(), MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET)
  let offsetAllItems = (layersArray.len()-1) / 2.0
  let res = layersArray.map(function(imageLayer, idx) {
    return ::LayersIcon.genDataFromLayer(
      { x = $"({offsetByItem} * {idx - offsetAllItems})@itemWidth", w = "1@itemWidth", h = "1@itemWidth" },
      ::LayersIcon.genDataFromLayer(
        ::LayersIcon.findLayerCfg(singleItemIconLayer),
        imageLayer
      )
    )
  })
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg(itemContainerLayer), "".join(res))
}

let getDecoratorLayeredIcon = @(giftArray, decoratorType) (giftArray ?? []).map(function(giftId) {
  let decorator = ::g_decorator.getDecorator(giftId, decoratorType)
  let cfg = clone ::LayersIcon.findLayerCfg("item_decal")
  cfg.img <- decoratorType.getImage(decorator)

  local image = ""
  if (cfg.img != "")
    image = ::LayersIcon.genDataFromLayer(cfg)

  if (image == "")
    image = ::LayersIcon.getIconData("reward_" + decoratorType.resourceType)

  return image
})

let getUnitLayeredIcon = @(unitArray) (unitArray ?? []).map(function(unitId) {
  let unitType = ::getUnitTypeTextByUnit(::getAircraftByName(unitId)).tolower()
  return ::LayersIcon.getIconData($"reward_unit_{unitType}")
})

local function getEntitlementLayerIcons(entitlement) {
  if (typeof entitlement == "string")
    entitlement = getEntitlementConfig(entitlement)

  if (!entitlement)
    return ""

  let layerStyles = []
  if (entitlement?.goldIncome != null)
    layerStyles.append("reward_gold")
  if (entitlement?.wpIncome != null)
    layerStyles.append(::trophyReward.getWPIcon(entitlement.wpIncome))

  layerStyles.extend((entitlement?.entitlementGift ?? [])
    .filter(@(entId) getEntitlementConfig(entId) != null)
    .map(@(entId) "reward_entitlement")
  )
  layerStyles.extend((entitlement?.unlockGift ?? []).map(@(unlockId) "reward_unlock"))

  let layersArray = layerStyles.map(@(style) ::LayersIcon.getIconData(style))

  layersArray.extend(getDecoratorLayeredIcon(entitlement?.decalGift, ::g_decorator_type.DECALS))
  layersArray.extend(getDecoratorLayeredIcon(entitlement?.attachableGift, ::g_decorator_type.ATTACHABLES))
  layersArray.extend(getDecoratorLayeredIcon(entitlement?.skinGift, ::g_decorator_type.SKINS))
  layersArray.extend(getUnitLayeredIcon(entitlement?.aircraftGift))

  return generateLayers(layersArray)
}

return {
  getEntitlementView = getEntitlementView
  getEntitlementLayerIcons = getEntitlementLayerIcons
}