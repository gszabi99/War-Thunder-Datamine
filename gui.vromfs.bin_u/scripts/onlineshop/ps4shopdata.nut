local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local statsd = require("statsd")
local psn = require("sonyLib/webApi.nut")
local u = require("sqStdLibs/helpers/u.nut")
local seenList = require("scripts/seen/seenList.nut").get(SEEN.EXT_PS4_SHOP)
local { fillBlock } = require("scripts/utils/datablockConverter.nut")

local { isPlatformSony } = require("scripts/clientState/platform.nut")

local Ps4ShopPurchasableItem = require("scripts/onlineShop/ps4ShopPurchasableItem.nut")

local persist = {
  categoriesData = ::DataBlock() // Collect one time in a session, reset on relogin
  itemsList = {} //Updatable during game
}
::g_script_reloader.registerPersistentData("PS4ShopData", persist, ["categoriesData", "itemsList"])

local STORE_REQUEST_ADDITIONAL_FLAGS = {
  flag = "discounts"
  useCurrencySymbol = "false"
  useFree = "true"
  sort = "release_date"
  keepHtmlTag = "true"
}

local isFinishedUpdateItems = false //Status of FULL update items till creating list of classes PS4ShopPurchasableItem
local invalidateSeenList = false
local visibleSeenIds = []

local getShopItem = @(id) persist.itemsList?[id]

local canUseIngameShop = @() isPlatformSony && ::has_feature("PS4IngameShop")

local haveItemDiscount = null

// Calls on finish updating skus extended info
local onFinishCollectData = function()
{
  if (!canUseIngameShop())
    return

  isFinishedUpdateItems = true
  haveItemDiscount = null

  if (invalidateSeenList)
  {
    visibleSeenIds.clear()
    seenList.onListChanged()
  }
  invalidateSeenList = false

  //Must call in the end
  ::dagor.debug("PSN: Shop Data: Finish update items info")
  ::broadcastEvent("Ps4ShopDataUpdated", {isLoadingInProgress = false})
}

// Return next category, after passed, for request info
local getNextCategoryName = function(lastCategory = "") {
  local needRequestCategory = lastCategory == ""

  for (local i = 0; i < persist.categoriesData.blockCount(); i++)
  {
    local newCat = persist.categoriesData.getBlock(i).getBlockName()
    if (needRequestCategory)
      return newCat

    needRequestCategory = newCat == lastCategory
  }

  return null
}

local makeRequestForNextCategory = function(onFoundCb, onFinishCb = @() null, lastCategory = "") {
  local newCategoryRequest = getNextCategoryName(lastCategory)
  if (newCategoryRequest)
    onFoundCb(newCategoryRequest)
  else
    onFinishCb()
}

// Send requests on skus extended info, per category separatly.
local requestLinksFullInfo = @(category) null
local fillLinkFullInfo = @(category = "") makeRequestForNextCategory(requestLinksFullInfo, onFinishCollectData, category)

local itemIndex = 0
local onReceivedResponeOnFullInfo = function(response, category, linksList) {
  if (!(category in persist.categoriesData))
    return

  if (response != null)
    response.each(function(linkBlock, idx) {
      local label = linkBlock.label

      // Received full info, we don't need short
      persist.categoriesData[category].links.removeBlock(label)

      fillBlock(label, persist.categoriesData[category].links, linkBlock)
      persist.categoriesData[category].links[label].setStr("category", category)
      persist.itemsList[label] <- Ps4ShopPurchasableItem(persist.categoriesData[category].links[label], itemIndex++)

      local linkIdx = linksList.findindex(@(p) p == label)
      if (linkIdx != null)
        linksList.remove(linkIdx)
    })

  if (linksList.len())
    ::dagor.debug("PSN: Shop data: onReceivedResponeOnFullInfo: Didn't recieved info for {0}".subst(linksList.tostring()))

  fillLinkFullInfo(category)
}

requestLinksFullInfo = function(category) {
  local categoryBlock = persist.categoriesData.getBlockByName(category)
  if (!categoryBlock)
  {
    ::dagor.debug($"PSN: Shop data: requestLinksFullInfo: no block found for category {category}")
    fillLinkFullInfo(category)
    return
  }

  //Check gui.blk for skippable items
  local skipItemsList = ::configs.GUI.get()?.ps4_ingame_shop.itemsHide ?? ::DataBlock()

  local linksList = []
  for (local i = categoryBlock.links.blockCount() - 1; i >= 0; i--)
  {
    local linkId = categoryBlock.links.getBlock(i).getBlockName()
    if (linkId in skipItemsList)
    {
      persist.categoriesData[category].links.removeBlock(linkId)
      continue
    }

    linksList.append(linkId)
  }

  // Remove category block if no items left
  if (!linksList.len())
  {
    ::dagor.debug("PSN: Shop Data: requestLinksFullInfo: No link left to display. Remove category " + category)
    persist.categoriesData.removeBlock(category)
    fillLinkFullInfo(category)
    return
  }

  psn.send(psn.commerce.detail(linksList, STORE_REQUEST_ADDITIONAL_FLAGS),
    function(response, err) {
      if (err)
      {
        statsd.send_counter("sq.ingame_store.request", 1,
          {status = "error", request = "links_full_info", category = category, error_code = err.code})
        ::dagor.debug("PSN: Shop Data: requestLinksFullInfo: on send linksList: Error " + ::toString(err))
        ::debugTableData(linksList)
        return
      }
      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "success", request = "links_full_info", category = category})

      onReceivedResponeOnFullInfo(response, category, linksList)
    }
  )
}

// Send request for category on full list of links.
// It is recursible, fill info on receive data.
// On receiving final items, checked by total_result and size params,
// send another request for next category.
local requestCategoryFullLinksList = @(category) null
requestCategoryFullLinksList = @(category) psn.fetch(psn.commerce.listCategory(category),
  function(response, err) {
    if (err)
    {
      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "error", request = "category_full_links_list", category = category, error_code = err.code})
      ::dagor.debug("PSN: Shop Data: requestCategoryFullLinksList: Category " + category + ", Error receieved: " + ::toString(err))
      return
    }

    if (!(category in persist.categoriesData))
      return

    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "success", request = "category_full_links_list", category = category})

    if (typeof response != "array") //Inconsistent response, can be table
      response = [response]

    fillBlock("links", persist.categoriesData[category], response[0].links)

    local size = (response[0]?.size || 0) + (response[0]?.start || 0)
    local total = response[0]?.total_results || size
    if (size != 0 && total == size)
      makeRequestForNextCategory(requestCategoryFullLinksList, fillLinkFullInfo, category)
  }
)

// Dig categories with requests to collect info
//  cat1 = { links = {}}, cat2 = { links = {}}, etc...
// In prior, PSN shop info have tree structure,
// For usability, save it in linear structure.
// Full links info will be sended later

local digCategory = @(response, err = null) null

digCategory = function(response, err = null)
{
  if (err)
  {
    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "error", request = "dig_category", error = err.code})

    if (::u.isString(err.code) || err.code < 500 || err.code >= 600)
      ::script_net_assert_once("psn_categories_error", "PSN: Shop Data: Dig Category: received error: " + ::toString(err))
    return
  }
  statsd.send_counter("sq.ingame_store.request", 1,
    {status = "success", request = "dig_category"})

  local categories = []
  foreach (data in response)
  {
    local products = []

    foreach (link in data.links)
    {
      if (link.container_type == "category")
        categories.append(link.label)
      else
        products.append(link)
    }

    if (products.len())
      fillBlock(data.label, persist.categoriesData, data)
  }

  if (categories.len())
    psn.send(psn.commerce.detail(categories), digCategory)
  else
  {
    // No categories left for digging. Left only products
    // Start request full links
    makeRequestForNextCategory(requestCategoryFullLinksList, fillLinkFullInfo)
  }
}

// Start make requests for categories info
local collectCategoriesAndItems = @() psn.send(
  psn.commerce.listCategory(""),
  function(response, err)
  {
    if (err)
    {
      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "error", request = "collect_categories_and_items", error = err.code})
      ::dagor.debug("PSN: Shop Data: collectCategoriesAndItems: Received error: " + ::toString(err))
      return
    }
    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "success", request = "collect_categories_and_items"})

    persist.categoriesData.reset()
    invalidateSeenList = true
    isFinishedUpdateItems = false
    ::broadcastEvent("Ps4ShopDataUpdated", {isLoadingInProgress = true})

    //Proceed data in response, what have come
    digCategory(response)
  }
)

local isCategoriesInitedOnce = false
local initPs4CategoriesAfterLogin = function()
{
  if (!isCategoriesInitedOnce && canUseIngameShop())
  {
    isCategoriesInitedOnce = true
    collectCategoriesAndItems()
  }
}

// For updating single info and send event for updating it in shop, if opened
// We can remake on array of item labels,
// but for now require only for single item at once.
local updateSpecificItemInfo = function(id)
{
  local linksArray = [id]
  psn.send(psn.commerce.detail(linksArray, STORE_REQUEST_ADDITIONAL_FLAGS),
    function(response, err) {
      if (err)
      {
        statsd.send_counter("sq.ingame_store.request", 1,
          {status = "error", request = "update_specific_item_info", error = err.code})
        ::dagor.debug("PSN: Shop Data: updateSpecificItemInfo: items: " + ::toString(linksArray) + "; Error: " + ::toString(err))
        return
      }

      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "success", request = "update_specific_item_info"})

      foreach (idx, itemData in response)
      {
        local itemId = linksArray[idx]
        local shopItem = getShopItem(itemId)

        if (!(shopItem.category in persist.categoriesData))
          continue

        local linksBlock = persist.categoriesData[shopItem.category].links
        // No need old info, remove block, and fill with new one
        linksBlock.removeBlock(itemId)

        fillBlock(itemId, linksBlock, itemData)
        linksBlock[itemId].setStr("category", shopItem.category)

        shopItem.updateSkuInfo(linksBlock[itemId])
      }

      // Send event for updating items in shop
      ::broadcastEvent("PS4IngameShopUpdate")
    }
  )
}

local getVisibleSeenIds = function()
{
  if (isFinishedUpdateItems && !visibleSeenIds.len() && persist.categoriesData.blockCount() && persist.itemsList.len())
  {
    for (local i = 0; i < persist.categoriesData.blockCount(); i++)
    {
      local productsList = persist.categoriesData.getBlock(i).links
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
  if (!persist.itemsList.len())
    return false

  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (item in persist.itemsList)
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

subscriptions.addListenersWithoutEnv({
  PS4ItemUpdate = @(p) updateSpecificItemInfo(p.id)
  ProfileUpdated = @(p) initPs4CategoriesAfterLogin()
  ScriptsReloaded = function(p) {
    visibleSeenIds.clear()
    persist.itemsList.clear()
    itemIndex = 0
    onFinishCollectData()
  }
  SignOut = function(p) {
    isCategoriesInitedOnce = false
    isFinishedUpdateItems = false
    persist.categoriesData.reset()
    persist.itemsList.clear()
    itemIndex = 0
    visibleSeenIds.clear()
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  collectCategoriesAndItems = collectCategoriesAndItems

  canUseIngameShop = canUseIngameShop
  haveDiscount = haveDiscount

  getData = @() persist.categoriesData
  getShopItemsTable = @() persist.itemsList
  getShopItem = getShopItem

  isItemsUpdated = @() isFinishedUpdateItems
}
