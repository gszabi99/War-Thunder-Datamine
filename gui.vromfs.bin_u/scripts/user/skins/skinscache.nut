from "%scripts/dagui_library.nut" import *
let { get_skins_blk } = require("blkGetters")
let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let itemRarity = require("%scripts/items/itemRarity.nut")

let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplaceStatus.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getSkinCost, getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")

let skinsCache = {}
local waitingItemdefs = {}

function updateSkinRarity(skinData, source) {
  let {item_quality = null, name_color = null } = source
  let rarity = itemRarity.get(item_quality, name_color)
  skinData.isRare = rarity.isRare
  skinData.rarityColor = rarity.color
}

function canReceive(skinData) {
  let { marketplaceItemdefId, unlockId, skinId } = skinData
  return marketplaceItemdefId != null
    || getUnlockById(unlockId) != null
    || !getSkinCost(skinId).isZero()
}

function isSkinVisible(skinData) {
  let { isUnlocked, hideForLang, reqFeature, hideUntilUnlocked } = skinData
  if (hideForLang?.indexof(getLanguageName()) != null)
    return false

  if (reqFeature != null)
    foreach (feature in reqFeature)
      if (!hasFeature(feature))
        return false

  if (!isUnlocked && (hideUntilUnlocked || !canReceive(skinData)))
    return false

  return true
}

function updateSkinsCache() {
  let blk = get_skins_blk()
  let numDecors = blk.blockCount()
  for (local i = 0; i < numDecors; ++i) {
    let skinBlk = blk.getBlock(i)
    let skinId = skinBlk.getBlockName()

    let unitId = getPlaneBySkinId(skinId)
    let unit = getAircraftByName(unitId)
    if (!unit || !unit.isVisibleInShop())
      continue

    let isUnlocked = decoratorTypes.SKINS.isPlayerHaveDecorator(skinId)
    let { marketplaceItemdefId = null, unlock = "", hideUntilUnlocked = false } = skinBlk
    let hideForLang = skinBlk % "hideForLang"
    let reqFeature = skinBlk % "reqFeature"
    let skinData = {
      skinId
      country = getUnitCountry(unit)
      unitType = unit.unitType.armyId
      rank = unit.rank
      sortOrder = getEsUnitType(unit)
      isUnitBought = unit.isBought()
      isUnlocked
      isRare = false
      rarityColor = "f1f1d6"
      marketplaceItemdefId
      unlockId = unlock
      hideUntilUnlocked
      hideForLang = hideForLang.len() == 0 ? null : hideForLang
      reqFeature = reqFeature.len() == 0 ? null : reqFeature
    }

    skinsCache[skinId] <- skinData

    updateSkinRarity(skinData, skinBlk)

    if (marketplaceItemdefId != null && isMarketplaceEnabled()) {
      let couponItem = findItemById(marketplaceItemdefId)
      if (couponItem)
        updateSkinRarity(skinData, couponItem.itemDef)
      else
        waitingItemdefs[marketplaceItemdefId] <- skinData
    }
  }
}

function onEventItemsShopUpdate(_) {
  foreach (itemDefId, skinData in waitingItemdefs) {
    let couponItem = findItemById(itemDefId)
    if (couponItem) {
      updateSkinRarity(skinData, couponItem.itemDef)
      waitingItemdefs[itemDefId] = null
    }
  }
  waitingItemdefs = waitingItemdefs.filter(@(v) v != null)
}

function getSkinsCache() {
  if (skinsCache.len() == 0)
    updateSkinsCache()
  return skinsCache
}

let invalidateSkinsCache = @() skinsCache.clear()

addListenersWithoutEnv({
  ItemsShopUpdate = onEventItemsShopUpdate
  LoginComplete = @(_) invalidateSkinsCache()
  SignOut = @(_) invalidateSkinsCache()
}, g_listener_priority.CONFIG_VALIDATION)

eventbus_subscribe("on_dl_content_skins_invalidate", @(_) invalidateSkinsCache())

eventbus_subscribe("update_unit_skins_list", function update_unit_skins_list(evt) {
  getAircraftByName(evt.unitName)?.resetSkins()
})


return {
  getSkinsCache
  isSkinVisible
}