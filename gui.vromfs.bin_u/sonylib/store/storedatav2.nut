local statsd = require("statsd")
local psn = require("sonyLib/webApi.nut")
local datablock = require("DataBlock")
local u = require("sqStdLibs/helpers/u.nut")

local { fillBlock } = require("sqStdlibs/helpers/datablockUtils.nut")

local SERVICE_LABEL = ::get_platform() == "ps5"? 1 : 0
local STORE_REQUEST_ADDITIONAL_FLAGS = {
  useCurrencySymbol = "false"
  useFree = "true"
  sort = "release_date"
  keepHtmlTag = "true"
}

local categoriesData = datablock()

local onFinishCollectData = @(...) null
local onFilterCollectData = @(...) null

local finalizeCollectData = function() {
  onFinishCollectData(categoriesData)
  onFinishCollectData = @(...) null
  onFilterCollectData = @(...) null
}

local getNextCategoryName = function(lastCategory = "") {
  local needRequestCategory = lastCategory == ""

  for (local i = 0; i < categoriesData.blockCount(); i++) {
    local newCat = categoriesData.getBlock(i).getBlockName()
    if (needRequestCategory)
      return newCat

    needRequestCategory = newCat == lastCategory
  }

  return null
}

local gatherAllItemsForCategory = function(onFoundCb, onFinishCb = @() null, lastCategory = "") {
  local newCategoryRequest = getNextCategoryName(lastCategory)
  if (newCategoryRequest)
    onFoundCb(newCategoryRequest)
  else
    onFinishCb()
}

// Send requests on skus extended info, per category separatly.
local requestLinksFullInfo = @(category) null
local fillLinkFullInfo = @(category = "") gatherAllItemsForCategory(
  requestLinksFullInfo,
  finalizeCollectData,
  category
)

requestLinksFullInfo = function(category) {
  local categoryBlock = categoriesData.getBlockByName(category)
  if (!categoryBlock)
    ::dagor.debug($"PSN: Shop data: V2: requestLinksFullInfo: no block found for category {category}")

  local linksList = []
  for (local i = categoryBlock.links.blockCount() - 1; i >= 0; i--) {
    local linkId = categoryBlock.links.getBlock(i).getBlockName()
    if (onFilterCollectData(linkId)) {
      categoriesData[category].links.removeBlock(linkId)
      continue
    }

    linksList.append(linkId)
  }

  // Remove category block if no items left
  if (!linksList.len()) {
    ::dagor.debug($"PSN: Shop Data: V2: requestLinksFullInfo: No link left to display. Remove category {category}")
    categoriesData.removeBlock(category)
  }

  fillLinkFullInfo(category)
}

local requestCategoryFullLinksList = @(category) null
requestCategoryFullLinksList = @(category) psn.send(psn.inGameCatalog.get([category], SERVICE_LABEL, STORE_REQUEST_ADDITIONAL_FLAGS),
  function(response, err) {
    if (err) {
      statsd.send_counter("sq.ingame_store.v2.request", 1,
        {status = "error", request = "category_full_links_list", category = category, error_code = err.code})
      ::dagor.debug($"PSN: Shop Data: V2: requestCategoryFullLinksList: Category {category}, Error receieved: {::toString(err, 4)}")
      finalizeCollectData()
      return
    }

    if (!(category in categoriesData))
      return

    statsd.send_counter("sq.ingame_store.v2.request", 1,
      {status = "success", request = "category_full_links_list", category = category})

    if (typeof response != "array") //Inconsistent response, can be table
      response = [response]

    fillBlock("links", categoriesData[category], response[0].children)
    for (local i = 0; i < categoriesData[category].links.blockCount(); i++)
      categoriesData[category].links.getBlock(i).category = category

    gatherAllItemsForCategory(requestCategoryFullLinksList, fillLinkFullInfo, category)
  }
)

local collectCategories = @(response, err = null) null
collectCategories = function(response, err = null) {
  if (err) {
    statsd.send_counter("sq.ingame_store.v2.request", 1,
      {status = "error", request = "dig_category", error = err.code})

    if (u.isString(err.code) || err.code < 500 || err.code >= 600)
      ::script_net_assert_once("psn_categories_error", $"PSN: Shop Data: Dig Category: received error: {::toString(err, 4)}")
    finalizeCollectData()
    return
  }

  statsd.send_counter("sq.ingame_store.v2.request", 1,
    {status = "success", request = "dig_category"})

  local categories = []
  foreach (data in response) {
    local products = []

    foreach (block in data.children) {
      if (block.type == "category")
        categories.append(block.label)
      else
        products.append(block)
    }

    if (products.len())
      fillBlock(data.label, categoriesData, data)
  }

  if (categories.len())
    psn.send(psn.inGameCatalog.get(categories, SERVICE_LABEL), collectCategories)
  else {
    // No categories left for digging. Left only products
    // Start request full links
    gatherAllItemsForCategory(requestCategoryFullLinksList, fillLinkFullInfo)
  }
}

local collectCategoriesAndItems = @() psn.send(
  psn.inGameCatalog.get([], SERVICE_LABEL),
  function(response, err) {
    categoriesData.reset()

    if (err) {
      statsd.send_counter("sq.ingame_store.v2.request", 1,
        {status = "error", request = "collect_categories_and_items", error = err.code})
      ::dagor.debug($"PSN: Shop Data: V2: collectCategoriesAndItems: Received error: {::toString(err, 4)}")
      finalizeCollectData()
      return
    }

    statsd.send_counter("sq.ingame_store.v2.request", 1,
      {status = "success", request = "collect_categories_and_items"})

    //Proceed data in response, what have come
    collectCategories(response)
  }
)

// For updating single info and send event for updating it in shop, if opened
// We can remake on array of item labels,
// but for now require only for single item at once.
local updateSpecificItemInfo = function(idsArray, onSuccessCb) {
  psn.send(psn.inGameCatalog.get(idsArray, SERVICE_LABEL, STORE_REQUEST_ADDITIONAL_FLAGS),
    function(response, err) {
      if (err) {
        statsd.send_counter("sq.ingame_store.v2.request", 1,
          {status = "error", request = "update_specific_item_info", error = err.code})
        ::dagor.debug($"PSN: Shop Data: V2: updateSpecificItemInfo: items: {::toString(idsArray)}; Error: {::toString(err)}")
        return
      }

      statsd.send_counter("sq.ingame_store.v2.request", 1,
        {status = "success", request = "update_specific_item_info"})

      local res = []
      foreach (idx, itemData in response) {
        local itemId = idsArray[idx]
        local category = ""
        local linksBlock = null

        for (local i = 0; i < categoriesData.blockCount(); i++) {
          local catInfo = categoriesData.getBlock(i)
          if (itemId in catInfo.links) {
            linksBlock = catInfo.links
            category = catInfo.getBlockName()
            break
          }
        }

        if (!linksBlock) {
          ::dagor.debug($"PSN: Shop Data: V2: updateSpecificItemInfo: not found block for {itemId}")
          return
        }

        // No need old info, remove block, and fill with new one
        linksBlock.removeBlock(itemId)

        fillBlock(itemId, linksBlock, itemData)
        linksBlock[itemId].setStr("category", category)
        res.append(linksBlock[itemId])
      }

      onSuccessCb(res)
    }
  )
}

return {
  request = function(onFinishCb, onFilterCb = @(...) null) {
    onFinishCollectData = onFinishCb
    onFilterCollectData = onFilterCb
    collectCategoriesAndItems()
  }
  updateSpecificItemInfo
}