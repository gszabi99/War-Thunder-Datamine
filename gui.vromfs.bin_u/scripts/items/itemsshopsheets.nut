from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType
from "%scripts/mainConsts.nut" import SEEN

let u = require("%sqStdLibs/helpers/u.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { getShopList } = require("%scripts/items/itemsManagerGetters.nut")
let { isItemVisible, checkItemsMaskFeatures } = require("%scripts/items/itemsChecks.nut")
let { getInventoryListByShopMask } = require("%scripts/items/itemsManager.nut")

let shopSheets = {
  types = []
}

let isOnlyExtInventory = @(shopTab) shopTab != itemsTab.WORKSHOP && hasFeature("ExtInventory")

shopSheets.template <- {
  id = "" 
  sortId = 0
  searchId = null 
  locId = null 
  emptyTabLocId = null 

  typeMask = itemType.INVENTORY_ALL
  isDevItemsTab = false
  isMarketplace = false
  hasSubLists = @() false

  getSeenId = @() $"##item_sheet_{this.id}"

  isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP
  isEnabled = @(shopTab) this.isAllowedForTab(shopTab)
    && checkItemsMaskFeatures(this.typeMask) != 0
    && (shopTab != itemsTab.SHOP || this.id == "ALL" || this.getItemsList(shopTab).len() > 0)
    && (shopTab != itemsTab.RECYCLING || this.id == "ALL" || this.getItemsList(shopTab, this.id).len() > 0)

  getItemFilterFunc = @(shopTab)
    shopTab == itemsTab.SHOP
      ? (@(item) isItemVisible(item, shopTab) && this.isDevItemsTab == item.isDevItem)
      : (@(item) isItemVisible(item, shopTab))

  getItemsList = function(shopTab, _subsetId = null) {
    let visibleTypeMask = checkItemsMaskFeatures(this.typeMask)
    let filterFunc = this.getItemFilterFunc(shopTab).bindenv(this)
    if (shopTab == itemsTab.INVENTORY || shopTab == itemsTab.RECYCLING)
      return getInventoryListByShopMask(visibleTypeMask, filterFunc)
    if (shopTab == itemsTab.SHOP)
      return getShopList(visibleTypeMask, filterFunc)
    return []
  }
  getSubsetsListParameters = @() null
  getSubsetIdByItemId = @(_itemId) null
  getSubsetSeenListId = @(subsetId) "{0}/{1}".subst(this.getSeenId(), subsetId)
}

function getTabSeenId(tabIdx) { 
  if (tabIdx == itemsTab.SHOP)
    return SEEN.ITEMS_SHOP
  if (tabIdx == itemsTab.INVENTORY)
    return SEEN.INVENTORY
  if (tabIdx == itemsTab.WORKSHOP)
    return SEEN.WORKSHOP
  if (tabIdx == itemsTab.RECYCLING)
    return SEEN.RECYCLING
  return null
}

let isTabVisible = @(tabIdx) tabIdx != itemsTab.WORKSHOP || workshop.isAvailable() 

shopSheets.addSheets <- function(sheetsTable) {
  enums.addTypes(this, sheetsTable,
    function() {
      if (!this.locId)
        this.locId = $"itemTypes/{this.id.tolower()}"
      if (!this.emptyTabLocId)
        this.emptyTabLocId = $"items/shop/emptyTab/{this.id.tolower()}"
      if (!this.searchId)
        this.searchId = this.id
    },
    "id")
  shopSheets.types.sort(@(a, b) a.sortId <=> b.sortId)

  
  for (local tab = 0; tab < itemsTab.TOTAL; tab++)
    if (isTabVisible(tab)) {
      let curTab = tab
      let tabSeenList = seenList.get(getTabSeenId(tab))
      foreach (sh in this.types)
        if (sh.isAllowedForTab(tab)) {
          let curSheet = sh
          let shSeenId = sh.getSeenId()
          tabSeenList.setSubListGetter(shSeenId, @() curSheet.getItemsList(curTab).map(@(it) it.getSeenId()))

          if (sh.hasSubLists()) {
            let subsetList = curSheet.getSet().getSubsetsList()
            subsetList.apply(@(subset) tabSeenList.setSubListGetter(curSheet.getSubsetSeenListId(subset.id),
              @() curSheet.getItemsList(curTab, subset.id).map(@(it) it.getSeenId())))
          }
        }
    }
}

shopSheets.findSheet <- function(config, defSheet = null) {
  local res = null
  foreach (sh in this.types) {
    if (config == sh) {
      res = sh 
      break
    }

    local isFullMatch = true
    local isPartMatch = false
    foreach (key, value in config)
      if (key in sh)
        if (value == sh[key])
          isPartMatch = true
        else
          isFullMatch = false

    if (isFullMatch || (isPartMatch && !res))
      res = sh
    if (isFullMatch)
      break
  }
  return res ?? defSheet
}

local sortId = 0
shopSheets.addSheets({
  ALL = {
    locId = "userlog/page/all"
    typeMask = itemType.INVENTORY_ALL
    sortId = sortId++
  }
  TROPHY = {
    typeMask = itemType.TROPHY
    isAllowedForTab = @(shopTab) shopTab == itemsTab.SHOP
    sortId = sortId++
  }
  BOOSTER = {
    typeMask = itemType.BOOSTER
    sortId = sortId++
  }
  WAGERS = {
    typeMask = itemType.WAGER
    sortId = sortId++
  }
  DISCOUNT = {
    typeMask = itemType.DISCOUNT
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab == itemsTab.INVENTORY
      || (shopTab == itemsTab.SHOP && hasFeature("CanBuyDiscountItems"))
      || (shopTab == itemsTab.RECYCLING)
  }
  TICKETS = {
    typeMask = itemType.TICKET
    sortId = sortId++
  }
  ORDERS = {
    typeMask = itemType.ORDER
    sortId = sortId++
  }
  UNIVERSAL_SPARE = {
    locId = "itemTypes/universalSpare"
    emptyTabLocId = "items/shop/emptyTab/universalSpare"
    typeMask = itemType.UNIVERSAL_SPARE
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP && !hasFeature("ItemModUpgrade")
  }
  MODIFICATIONS = {
    locId = "mainmenu/btnWeapons"
    typeMask = itemType.UNIVERSAL_SPARE | itemType.MOD_UPGRADE | itemType.MOD_OVERDRIVE
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP && hasFeature("ItemModUpgrade")
  }
  VEHICLES = {
    typeMask = itemType.VEHICLE | itemType.RENTED_UNIT | itemType.UNIT_COUPON_MOD
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  SKINS = {
    typeMask = itemType.SKIN
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  DECALS = {
    locId = "unlocks/chapter/decals"
    typeMask = itemType.DECAL
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  ATTACHABLE = {
    locId = "unlocks/chapter/attachable"
    typeMask = itemType.ATTACHABLE
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  KEYS = {
    typeMask = itemType.KEY
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  CHESTS = {
    typeMask = itemType.CHEST
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  PROFILE_ICONS = {
    typeMask = itemType.PROFILE_ICON
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  SMOKE = {
    locId = "itemTypes/aerobatic_smoke"
    typeMask = itemType.SMOKE
    isAllowedForTab = @(shopTab) shopTab == itemsTab.SHOP || shopTab == itemsTab.RECYCLING
    sortId = sortId++
  }
  OTHER = {
    locId = "attachables/category/other"
    typeMask = itemType.WARBONDS | itemType.ENTITLEMENT | itemType.INTERNAL_ITEM
      | itemType.WARPOINTS | itemType.UNLOCK
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  DEV_ITEMS = {
    locId = "itemTypes/devItems"
    emptyTabLocId = "items/shop/emptyTabdevItems/"
    typeMask = itemType.ALL
    isDevItemsTab = true
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab == itemsTab.SHOP && hasFeature("devItemShop")
  }
})

shopSheets.updateWorkshopSheets <- function() {
  let sets = workshop.getSetsList()
  let newSheets = {}

  foreach (idx, set in sets) {
    let id = set.getShopTabId()
    if (id in this)
      continue

    newSheets[id] <- {
      locId = set.locId
      typeMask = itemType.ALL
      searchId = set.id
      isMarketplace = true
      sortId = sortId++

      setIdx = idx
      getSet = @() workshop.getSetsList()?[this.setIdx] ?? workshop.emptySet
      isAllowedForTab = @(shopTab) shopTab == itemsTab.WORKSHOP
      isEnabled = @(shopTab) this.isAllowedForTab(shopTab) && this.getSet().isVisible()

      hasSubLists = @() this.getSet().hasSubsets

      getItemFilterFunc = function(_shopTab) {
        let s = this.getSet()
        return s.isItemInSet.bindenv(s)
      }

      getItemsList = @(_shopTab, subsetId = null) subsetId == null
        ? this.getSet().getItemsList()
        : this.getSet().getItemsSubList(subsetId)
      getSubsetsListParameters = function() {
        let curSet = this.getSet()
        return {
          subsetList = curSet.getSubsetsList()
          curSubsetId  = curSet.getCurSubsetId()
        }
      }
      setSubset = @(subsetId) this.getSet().setSubset(subsetId)
      getSubsetIdByItemId = @(itemId) this.getSet().getSubsetIdByItemId(itemId)
    }
  }

  if (newSheets.len())
    shopSheets.addSheets(newSheets)
}

shopSheets.getSheetDataByItem <- function(item) {
  if (item.shouldAutoConsume)
    return null

  this.updateWorkshopSheets()

  let iType = item.iType
  for (local tab = 0; tab < itemsTab.TOTAL; tab++)
    if (isTabVisible(tab))
      foreach (sh in this.types)
        if ((sh.typeMask & iType)
            && sh.isAllowedForTab(tab)
            && u.search(sh.getItemsList(tab), @(it) item.isEqual(it)) != null)
          return {
            tab = tab
            sheet = sh
            subsetId = sh.getSubsetIdByItemId(item.id)
          }
  return null
}

return shopSheets