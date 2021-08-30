local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local datablock = require("DataBlock")

local seenList = require("scripts/seen/seenList.nut").get(SEEN.EXT_PS4_SHOP)
local storeData = require("sonyLib/store/storeData.nut")

local { isPlatformSony } = require("scripts/clientState/platform.nut")

local psnStoreItem = require("scripts/onlineShop/psnStoreItem.nut")

local persistent = {
  categoriesData = datablock() // Collect one time in a session, reset on relogin
  itemsList = {} //Updatable during game
}
::g_script_reloader.registerPersistentData("PS4ShopData", persistent, ["categoriesData", "itemsList"])



local isFinishedUpdateItems = false //Status of FULL update items till creating list of classes psnStoreItem
local invalidateSeenList = false
local visibleSeenIds = []

local getShopItem = @(id) persistent.itemsList?[id]

local canUseIngameShop = @() isPlatformSony && ::has_feature("PS4IngameShop")

local haveItemDiscount = null

// Calls on finish updating skus extended info
local onFinishCollectData = function(_categoriesData = null)
{
  if (!canUseIngameShop())
    return

  persistent.categoriesData.setFrom(_categoriesData)
  isFinishedUpdateItems = true
  haveItemDiscount = null

  if (invalidateSeenList)
  {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  local itemIndex = 0
  foreach (category, categoryInfo in persistent.categoriesData)
    foreach (label, itemInfo in (categoryInfo?.links ?? datablock()))
      persistent.itemsList[label] <- psnStoreItem(itemInfo, itemIndex++)

  //Must call in the end
  ::dagor.debug("PSN: Shop Data: Finish update items info")
  ::broadcastEvent("Ps4ShopDataUpdated", {isLoadingInProgress = false})
}

local filterFunc = function(label) {
 //Check gui.blk for skippable items
  local skipItemsList = ::configs.GUI.get()?.ps4_ingame_shop.itemsHide ?? datablock()
  return label in skipItemsList
}

local isCategoriesInitedOnce = false
local initPs4CategoriesAfterLogin = function()
{
  if (!isCategoriesInitedOnce && canUseIngameShop())
  {
    persistent.categoriesData.reset()

    isCategoriesInitedOnce = true
    invalidateSeenList = true
    isFinishedUpdateItems = false
    ::broadcastEvent("Ps4ShopDataUpdated", {isLoadingInProgress = true})

    storeData.request(onFinishCollectData, filterFunc)
  }
}


local getVisibleSeenIds = function()
{
  if (isFinishedUpdateItems && !visibleSeenIds.len() && persistent.categoriesData.blockCount() && persistent.itemsList.len())
  {
    for (local i = 0; i < persistent.categoriesData.blockCount(); i++)
    {
      local productsList = persistent.categoriesData.getBlock(i).links
      for (local j = 0; j < productsList.blockCount(); j++)
      {
        local item = getShopItem(productsList.getBlock(j).getBlockName())
        if (!item)
          continue

        if (!item.canBeUnseen())
          visibleSeenIds.append(item.getSeenId())
      }
    }
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local haveAnyItemWithDiscount = function()
{
  if (!persistent.itemsList.len())
    return false

  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (item in persistent.itemsList)
    if (item.haveDiscount())
    {
      haveItemDiscount = true
      break
    }

  return haveItemDiscount
}

local haveDiscount = function()
{
  if (!canUseIngameShop())
    return false

  if (!isCategoriesInitedOnce)
  {
    initPs4CategoriesAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}

// For updating single info and send event for updating it in shop, if opened
// We can remake on array of item labels,
// but for now require only for single item at once.
local function onSuccessCb(itemsArray) {
  foreach (itemData in itemsArray)
  {
    local itemId = itemData.label
    local shopItem = getShopItem(itemId)

    shopItem.updateSkuInfo(itemData)
  }

  // Send event for updating items in shop
  ::broadcastEvent("PS4IngameShopUpdate")
}

local updateSpecificItemInfo = function(id)
{
  storeData.updateSpecificItemInfo([id], onSuccessCb)
}

subscriptions.addListenersWithoutEnv({
  PS4ItemUpdate = @(p) updateSpecificItemInfo(p.id)
  ProfileUpdated = @(p) initPs4CategoriesAfterLogin()
  ScriptsReloaded = function(p) {
    visibleSeenIds.clear()
    persistent.itemsList.clear()
    isCategoriesInitedOnce = false
    initPs4CategoriesAfterLogin()
  }
  SignOut = function(p) {
    isCategoriesInitedOnce = false
    isFinishedUpdateItems = false
    persistent.categoriesData.reset()
    persistent.itemsList.clear()
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop = canUseIngameShop
  haveDiscount = haveDiscount

  getData = @() persistent.categoriesData
  getShopItemsTable = @() persistent.itemsList
  getShopItem = getShopItem

  isItemsUpdated = @() isFinishedUpdateItems
}
