local statsd = require("statsd")
local psn = require("sonyLib/webApi.nut")
local datablock = require("DataBlock")
local stdLog = require("std/log.nut")()
local log = stdLog.with_prefix("[PSN: Shop Data: V1] ")
local logerr = stdLog.logerr

local { fillBlock } = require("std/datablock.nut")

local STORE_REQUEST_ADDITIONAL_FLAGS = {
  flag = "discounts"
  useCurrencySymbol = "false"
  useFree = "true"
  sort = "release_date"
  keepHtmlTag = "true"
  size = 100 //TODO: rework on lazy load through, e.g. watched
}

local categoriesData = datablock()

local onFinishCollectData = @(...) null
local onFilterCollectData = @(...) null

local finalizeCollectData = function() {
  onFinishCollectData(categoriesData)
  onFinishCollectData = @(...) null
  onFilterCollectData = @(...) null
}

// Return next category, after passed, for request info
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

local makeRequestForNextCategory = function(onFoundCb, onFinishCb = @() null, lastCategory = "") {
  local newCategoryRequest = getNextCategoryName(lastCategory)
  if (newCategoryRequest)
    onFoundCb(newCategoryRequest)
  else
    onFinishCb()
}

// Send requests on skus extended info, per category separatly.
local requestLinksFullInfo = @(category) null
local fillLinkFullInfo = @(category = "") makeRequestForNextCategory(
  requestLinksFullInfo,
  finalizeCollectData,
  category
)

local onReceivedResponeOnFullInfo = function(response, category, linksList) {
  if (!(category in categoriesData))
    return

  if (response != null)
    response.each(function(linkBlock, idx) {
      local label = linkBlock.label

      // Received full info, we don't need short
      categoriesData[category].links.removeBlock(label)

      fillBlock(label, categoriesData[category].links, linkBlock)
      categoriesData[category].links[label].setStr("category", category)

      local linkIdx = linksList.findindex(@(p) p == label)
      if (linkIdx != null)
        linksList.remove(linkIdx)
    })

  if (linksList.len())
    log("onReceivedResponeOnFullInfo: Didn't recieved info for ", linksList)

  fillLinkFullInfo(category)
}

requestLinksFullInfo = function(category) {
  local categoryBlock = categoriesData.getBlockByName(category)
  if (!categoryBlock) {
    log("requestLinksFullInfo: no block found for category ", category)
    fillLinkFullInfo(category)
    return
  }

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
    log("requestLinksFullInfo: No link left to display. Remove category ", category)
    categoriesData.removeBlock(category)
    fillLinkFullInfo(category)
    return
  }

  psn.send(psn.commerce.detail(linksList, STORE_REQUEST_ADDITIONAL_FLAGS),
    function(response, err) {
      if (err) {
        statsd.send_counter("sq.ingame_store.request", 1,
          {status = "error", request = "links_full_info", category = category, error_code = err.code})
        log("requestLinksFullInfo: on send linksList: Error ", err)
        log(linksList)
        finalizeCollectData()
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
requestCategoryFullLinksList = @(category) psn.send(psn.commerce.listCategory(category, STORE_REQUEST_ADDITIONAL_FLAGS),
  function(response, err) {
    if (err) {
      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "error", request = "category_full_links_list", category = category, error_code = err.code})
      log($"requestCategoryFullLinksList: Category {category}, Error receieved: ", err)
      finalizeCollectData()
      return
    }

    if (!(category in categoriesData))
      return

    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "success", request = "category_full_links_list", category = category})

    if (typeof response != "array") //Inconsistent response, can be table
      response = [response]

    fillBlock("links", categoriesData[category], response[0].links)
    for (local i = 0; i < categoriesData[category].links.blockCount(); i++)
      categoriesData[category].links.getBlock(i).category = category

    makeRequestForNextCategory(requestCategoryFullLinksList, fillLinkFullInfo, category)
  }
)

// Check categories with requests to collect info
//  cat1 = { links = {}}, cat2 = { links = {}}, etc...
// In prior, PSN shop info have tree structure,
// For usability, save it in linear structure.
// Full links info will be sended later

local collectCategories = @(response, err = null) null
collectCategories = function(response, err = null) {
  if (err) {
    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "error", request = "dig_category", error = err.code})

    if (::type(err.code) == "string" || err.code < 500 || err.code >= 600)
      logerr($"PSN: Shop Data: Dig Category: received error: {err.code}")
    return
  }
  statsd.send_counter("sq.ingame_store.request", 1,
    {status = "success", request = "dig_category"})

  local categories = []
  foreach (data in response) {
    local products = []

    foreach (link in data.links) {
      if (link.container_type == "category")
        categories.append(link.label)
      else
        products.append(link)
    }

    if (products.len()) {
      fillBlock(data.label, categoriesData, data)
    }
  }

  if (categories.len())
    psn.send(psn.commerce.detail(categories), collectCategories)
  else {
    // No categories left for digging. Left only products
    // Start request full links
    makeRequestForNextCategory(requestCategoryFullLinksList, fillLinkFullInfo)
  }
}

// Start make requests for categories info
local collectCategoriesAndItems = @() psn.send(
  psn.commerce.listCategory(""),
  function(response, err) {
    categoriesData.reset()

    if (err) {
      statsd.send_counter("sq.ingame_store.request", 1,
        {status = "error", request = "collect_categories_and_items", error = err.code})
      log("collectCategoriesAndItems: Received error: ", err)
      return
    }
    statsd.send_counter("sq.ingame_store.request", 1,
      {status = "success", request = "collect_categories_and_items"})

    //Proceed data in response, what have come
    collectCategories(response)
  }
)

// For updating single info and send event for updating it in shop, if opened
// We can remake on array of item labels,
// but for now require only for single item at once.
local updateSpecificItemInfo = function(idsArray, onSuccessCb, onErrorCb = @(r, err) null) {
  psn.send(psn.commerce.detail(idsArray, STORE_REQUEST_ADDITIONAL_FLAGS),
    function(response, err) {
      if (err) {
        statsd.send_counter("sq.ingame_store.request", 1,
          {status = "error", request = "update_specific_item_info", error = err.code})
        log("updateSpecificItemInfo: items: ", idsArray, " Error: ", err)
        onErrorCb(response, err)
        return
      }

      statsd.send_counter("sq.ingame_store.request", 1,
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
          res.append(itemData)
          log($"updateSpecificItemInfo: not found block for {itemId}, don't cache it")
          continue
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