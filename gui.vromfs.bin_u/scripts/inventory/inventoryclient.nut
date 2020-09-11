local progressMsg = ::require("sqDagui/framework/progressMsg.nut")
local contentSignKeys = ::require("scripts/inventory/inventoryContentSign.nut")

enum validationCheckBitMask {
  VARTYPE            = 0x01
  EXISTENCE          = 0x02
  INVALIDATE         = 0x04
  VALUE              = 0x08

  // masks
  REQUIRED           = 0x03
  VITAL              = 0x07
  REQUIRED_AND_VALUE = 0x0B
}

const INVENTORY_PROGRESS_MSG_ID = "INVENTORY_REQUEST"
const WAR_THUNDER_EAGLES = "WTE"

local function getPremultipliedAlphaIcon(icon) {
  if (icon == "" || icon.slice(0,1) == "!")
    return icon
  return $"!{icon}"
}

local validateValueFunction = {
  icon_url = getPremultipliedAlphaIcon
  icon_url_large = getPremultipliedAlphaIcon
}

local requestInternal = function(requestData, data, callback, progressBoxData = null) {
  if (data) {
    requestData["data"] <- data;
  }

  if (progressBoxData)
    progressMsg.create(INVENTORY_PROGRESS_MSG_ID, progressBoxData)

  ::inventory.request(requestData, function(res) {
    callback(res)
    if (progressBoxData)
      progressMsg.destroy(INVENTORY_PROGRESS_MSG_ID, true)
  })
}

local getErrorId = @(result) result.error.split(":")[0]

local InventoryClient = class {
  items = {}
  itemdefs = {}
  prices = {}

  REQUEST_TIMEOUT_MSEC = 15000
  lastUpdateTime = -1
  lastRequestTime = -1

  lastItemdefsRequestTime = -1
  itemdefidsRequested = {} // Failed ids stays here, to avoid repeated requests.
  pendingItemDefRequest = null

  firstProfileLoadComplete = false

  needRefreshItems = false

  haveInitializedPublicKeys = false

  validateResponseData = {
    item_json = {
      [ validationCheckBitMask.VITAL ] = {
        itemid = ""
        itemdef = -1
      },
      [ validationCheckBitMask.REQUIRED ] = {
        accountid = ""
        position = 0
        quantity = 0
        state = "none"
        timestamp = ""
      },
      [ validationCheckBitMask.VARTYPE ] = {
      },
    }
    itemdef_json = {
      [ validationCheckBitMask.VITAL ] = {
        itemdefid = -1
      },
      [ validationCheckBitMask.REQUIRED ] = {
        type = ""
        Timestamp = ""
        marketable = false
        tradable = false
        exchange = ""
        background_color = ""
        name_color = ""
        promo = ""
        item_quality = 0
        meta = ""
        tags = ""
        item_slot = ""
      },
      [ validationCheckBitMask.REQUIRED_AND_VALUE ] = {
        icon_url = ""
        icon_url_large = ""
      },
      [ validationCheckBitMask.VARTYPE ] = {
        bundle = ""
        name = ""
        name_english = ""
        description = ""
        description_english = ""
      },
    }
  }

  tagsValueRemap = {
    yes         = true,
    no          = false,
    ["true"]    = true,
    ["false"]   = false,
  }


  constructor()
  {
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    if (::g_login.isProfileReceived())
      refreshDataOnAuthorization()
  }

  function onEventProfileUpdated(p) {
    if (!firstProfileLoadComplete)
      refreshDataOnAuthorization()
    firstProfileLoadComplete = true
  }

  function refreshDataOnAuthorization()
  {
    refreshItems()
    requestPrices()
  }


  function request(action, headers, data, callback, progressBoxData = null)
  {
    headers.appid <- WT_APPID
    local requestData = {
      add_token = true,
      headers = headers,
      action = action
    }
    requestInternal(requestData, data, callback.bindenv(this), progressBoxData)
  }


  function requestWithSignCheck(action, headers, data, callback, progressBoxData = null)
  {
    if (!contentSignKeys.initialized)
      return request(action, headers, data, callback, progressBoxData)

    headers.appid <- WT_APPID
    local requestData = {
      content_sign_check = true,
      add_token = true,
      headers = headers,
      action = action
    }
    requestInternal(requestData, data, callback.bindenv(this), progressBoxData)
  }


  function getResultData(result, name)
  {
    local data = result?.response?[name]
    return _validate(data, name)
  }

  function _validate(data, name)
  {
    local validation = validateResponseData?[name]
    if (!data || !validation)
      return data

    if (!::u.isArray(data))
      return null

    local itemsBroken  = []
    local keysMissing   = {}
    local keysWrongType = {}

    for (local i = data.len() - 1; i >= 0; i--)
    {
      local item = data[i]
      local isItemValid = ::u.isTable(item)
      local itemErrors = 0

      foreach (checks, keys in validation)
      {
        local shouldInvalidate     = (checks & validationCheckBitMask.INVALIDATE) != 0
        local shouldCheckExistence = (checks & validationCheckBitMask.EXISTENCE) != 0
        local shouldCheckType      = (checks & validationCheckBitMask.VARTYPE) != 0
        local shouldValidateValue  = (checks & validationCheckBitMask.VALUE) != 0

        if (isItemValid)
          foreach (key, defVal in keys)
          {
            local isExist = (key in item)
            local val = item?[key]
            local isTypeCorrect = isExist && (type(val) == type(defVal) || ::is_numeric(val) == ::is_numeric(defVal))

            local isMissing   = shouldCheckExistence && !isExist
            local isWrongType = shouldCheckType && isExist && !isTypeCorrect
            if (isMissing || isWrongType)
            {
              itemErrors++

              if (isMissing)
                keysMissing[key] <- true
              if (isWrongType)
                keysWrongType[key] <- type(val) + "," + val

              if (shouldInvalidate)
                isItemValid = false

              item[key] <- defVal
            }

            if (shouldValidateValue)
              item[key] = validateValueFunction[key](item[key])
          }
      }

      if (!isItemValid || itemErrors)
      {
        local itemDebug = []
        foreach (checks, keys in validation)
          if (checks & validationCheckBitMask.INVALIDATE)
            foreach (key, val in keys)
              if (key in item)
                itemDebug.append(key + "=" + item[key])
        itemDebug.append(isItemValid ? ("err=" + itemErrors) : "INVALID")
        itemDebug.append(::u.isTable(item) ? ("len=" + item.len()) : ("var=" + type(item)))

        itemsBroken.append(::g_string.implode(itemDebug, ","))
      }

      if (!isItemValid)
        data.remove(i)
    }

    if (itemsBroken.len() || keysMissing.len() || keysWrongType.len())
    {
      itemsBroken = ::g_string.implode(itemsBroken, ";")
      keysMissing = ::g_string.implode(keysMissing.keys(), ";")
      keysWrongType = ";".join(keysWrongType.topairs().map(@(i) i[0] + "=" + i[1]))
      ::script_net_assert_once("inventory client bad response", $"InventoryClient: Response has errors: {name}")
    }

    return data
  }

  function getMarketplaceBaseUrl()
  {
    local circuit = ::get_cur_circuit_name();
    local networkBlock = ::get_network_block();
    local url = networkBlock?[circuit]?.marketplaceURL ?? networkBlock?.marketplaceURL;
    if (!url)
      return null

    return "auto_login auto_local " + url + "?a=" + ::WT_APPID +
      (::steam_is_running()
        ? ::format("&app_id=%d&steam_id=%s", steam_get_app_id(), steam_get_my_id())
        : "")
  }

  function getMarketplaceItemUrl(itemdefid, itemid = null)
  {
    local marketplaceBaseUrl = getMarketplaceBaseUrl()
    if (!marketplaceBaseUrl)
      return null

    local item = itemdefid && itemdefs?[itemdefid]
    if ((item?.market_hash_name ?? "") != "")
      return marketplaceBaseUrl+ "&viewitem&n=" + ::encode_uri_component(item.market_hash_name)

    return null
  }

  function addInventoryItem(item)
  {
    local itemdefid = item.itemdef
    local shouldUpdateItemdDefs = addItemDefIdToRequest(itemdefid)
    item.itemdefid <- itemdefid
    item.itemdef = itemdefs[itemdefid] //fix me: why we use same field name for other purposes?
    items[item.itemid] <- item
    return shouldUpdateItemdDefs
  }

  function handleRpc(params)
  {
    if (params.func == "changed")
    {
      refreshItems()
    }
  }

  function refreshItems()
  {
    if (needRefreshItems)
      return

    if (!canRefreshData())
      return

    needRefreshItems = true
    dagor.debug("schedule requestItems")
    g_delayed_actions.add(requestItemsInternal.bindenv(this), 100)
  }

  isWaitForInventory = @() canRefreshData() && lastUpdateTime < 0

  function requestItemsInternal()
  {
    needRefreshItems = false
    if (!canRefreshData())
      return

    local wasWaitForInventory = isWaitForInventory()
    lastRequestTime = ::dagor.getCurTime()
    requestInventory(function(result) {
      lastUpdateTime = ::dagor.getCurTime()
      local hasInventoryChanges = false
      if (wasWaitForInventory)
        hasInventoryChanges = true //need event about we received inventory once, even if it empty.

      local itemJson = getResultData(result, "item_json");
      if (!itemJson)
      {
        if (wasWaitForInventory)
          notifyInventoryUpdate(hasInventoryChanges)
        return
      }

      local oldItems = items
      local shouldUpdateItemdefs = false
      items = {}
      foreach (item in itemJson) {
        local oldItem = ::getTblValue(item.itemid, oldItems)
        if (oldItem) {
          if (oldItem.timestamp != item.timestamp) {
            hasInventoryChanges = true
          }

          addInventoryItem(item)
          delete oldItems[item.itemid]

          continue
        }

        if (item.quantity <= 0)
          continue

        hasInventoryChanges = true
        shouldUpdateItemdefs = addInventoryItem(item) || shouldUpdateItemdefs
      }

      if (oldItems.len() > 0) {
        hasInventoryChanges = true
      }

      if (shouldUpdateItemdefs) {
        requestItemDefs()
      }
      else {
        notifyInventoryUpdate(hasInventoryChanges)
      }
    })
  }

  function requestInventory(callback) {
    request("GetInventory", {}, null, callback)
  }

  isItemdefRequestInProgress = @() lastItemdefsRequestTime >= 0
    && lastItemdefsRequestTime + REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime()

  function updatePendingItemDefRequest(cb, shouldRefreshAll)
  {
    if (!pendingItemDefRequest)
      pendingItemDefRequest = {
        cbList = [],
        shouldRefreshAll = false,
        fireCb = function() {
          foreach(_cb in cbList)
            _cb()
        }
      }
    pendingItemDefRequest.shouldRefreshAll = shouldRefreshAll || pendingItemDefRequest.shouldRefreshAll
    if (cb)
      pendingItemDefRequest.cbList.append(::Callback(cb, this))
  }

  _lastDelayedItemdefsRequestTime = 0
  function requestItemDefs(cb = null, shouldRefreshAll = false) {
    updatePendingItemDefRequest(cb, shouldRefreshAll)
    if (isItemdefRequestInProgress()
        || (_lastDelayedItemdefsRequestTime && _lastDelayedItemdefsRequestTime < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC))
      return
    _lastDelayedItemdefsRequestTime = ::dagor.getCurTime()
    ::handlersManager.doDelayed(function() {
      _lastDelayedItemdefsRequestTime = 0
      requestItemDefsImpl()
    }.bindenv(this))
  }

  function requestItemDefsImpl() {
    if (isItemdefRequestInProgress() || !pendingItemDefRequest)
      return
    local requestData = pendingItemDefRequest
    pendingItemDefRequest = null

    if (requestData.shouldRefreshAll)
      itemdefidsRequested.clear()

    local itemdefidsRequest = []
    foreach(itemdefid, value in itemdefs)
    {
      if (!requestData.shouldRefreshAll && (!::u.isEmpty(value) || itemdefidsRequested?[itemdefid]))
        continue

      itemdefidsRequest.append(itemdefid)
      itemdefidsRequested[itemdefid] <- true
    }

    if (!itemdefidsRequest.len())
      return requestData.fireCb()

    local itemdefidsString = ::g_string.implode(itemdefidsRequest, ",")
    dagor.debug("Request itemdefs " + itemdefidsString)

    lastItemdefsRequestTime = ::dagor.getCurTime()
    local steamLanguage = ::g_language.getCurrentSteamLanguage()
    requestWithSignCheck("GetItemDefsClient", {itemdefids = itemdefidsString, language = steamLanguage}, null,
      function(result) {
        lastItemdefsRequestTime = -1
        local itemdef_json = getResultData(result, "itemdef_json");
        if (!itemdef_json || steamLanguage != ::g_language.getCurrentSteamLanguage())
        {
          requestData.fireCb()
          requestItemDefsImpl()
          return
        }

        local hasItemDefChanges = false
        foreach (itemdef in itemdef_json) {
          local itemdefid = itemdef.itemdefid
          if (itemdefid in itemdefidsRequested)
            delete itemdefidsRequested[itemdefid]
          hasItemDefChanges = hasItemDefChanges || requestData.shouldRefreshAll || ::u.isEmpty(itemdefs?[itemdefid])
          addItemDef(itemdef)
        }

        notifyInventoryUpdate(true, hasItemDefChanges)
        requestData.fireCb()
        requestItemDefsImpl()
      })
  }

  function removeItem(itemid) {
    if (itemid in items)
      delete items[itemid]
    notifyInventoryUpdate(true)
  }

  function notifyInventoryUpdate(hasInventoryChanges = false, hasItemDefChanges = false) {
    if (hasItemDefChanges) {
      ::dagor.debug("ExtInventory itemDef changed")
      ::broadcastEvent("ItemDefChanged")
    }
    if (hasInventoryChanges) {
      ::dagor.debug("ExtInventory changed")
      ::broadcastEvent("ExtInventoryChanged")
    }
  }

  getItems             = @() items
  getItemdefs          = @() itemdefs
  getItemCost          = @(itemdefid) prices?[itemdefid] ?? ::zero_money

  function addItemDefIdToRequest(itemdefid)
  {
    if (itemdefid == null || itemdefid in itemdefs)
      return false

    itemdefs[itemdefid] <- {}
    return true
  }

  function requestItemdefsByIds(itemdefIdsList, cb = null)
  {
    foreach (itemdefid in itemdefIdsList)
      addItemDefIdToRequest(itemdefid)
    requestItemDefs(cb)
  }

  function addItemDef(itemdef) {
    local originalItemDef = itemdefs?[itemdef.itemdefid] || {}
    originalItemDef.clear()
    originalItemDef.__update(itemdef)
    originalItemDef.tags = getTagsItemDef(originalItemDef)
    itemdefs[itemdef.itemdefid] <- originalItemDef
  }

  function getTagsItemDef(itemdef)
  {
    local tags = ::getTblValue("tags" , itemdef, null)
    if (!tags)
      return null

    local parsedTags = ::DataBlock()
    foreach (pair in ::split(tags, ";")) {
      local parsed = ::split(pair, ":")
      if (parsed.len() == 2) {
        local v = parsed[1]
        parsedTags[parsed[0]] <- tagsValueRemap?[v] ?? v
      }
    }
    return parsedTags
  }

  function parseRecipesString(recipesStr)
  {
    local recipes = []
    foreach (recipe in ::split(recipesStr || "", ";"))
    {
      local parsedRecipe = {
        components = []
        reqItems = []
        requirement = null
        recipeStr = recipe
      }
      foreach (component in ::split(recipe, ","))
      {
        local requirement = ::g_string.cutPrefix(component, "require=")
        if (requirement != null) {
          parsedRecipe.requirement = requirement
          continue
        }
        local reqItems = ::g_string.cutPrefix(component, "req_items=")
        if (reqItems != null) {
          foreach (reqItem in ::split(reqItems, "+")) {
            local pair = ::split(reqItem, "x")
            if (!pair.len())
              continue
            parsedRecipe.reqItems.append({
              itemdefid = ::to_integer_safe(pair[0])
              quantity  = (1 in pair) ? ::to_integer_safe(pair[1]) : 1
            })
          }
          continue
        }

        local pair = ::split(component, "x")
        if (!pair.len())
          continue
        parsedRecipe.components.append({
          itemdefid = ::to_integer_safe(pair[0])
          quantity  = (1 in pair) ? ::to_integer_safe(pair[1]) : 1
        })
      }
      recipes.append(parsedRecipe)
    }
    return recipes
  }

  function handleItemsDelta(result, cb = null, errocCb = null, shouldCheckInventory = true) {
    if (result?.error != null) {
      errocCb?(getErrorId(result))
      return
    }

    local itemJson = getResultData(result, "item_json")
    if (!itemJson)
      return

    local newItems = []
    local shouldUpdateItemdefs = false
    local hasInventoryChanges = false
    foreach (item in itemJson) {
      local oldItem = ::getTblValue(item.itemid, items)
      if (item.quantity == 0) {
        if (oldItem) {
          delete items[item.itemid]
          hasInventoryChanges = true
        }

        continue
      }

      if (oldItem) {
        addInventoryItem(item)
        hasInventoryChanges = true
        continue
      }

      newItems.append(item)
      hasInventoryChanges = true
      shouldUpdateItemdefs = addInventoryItem(item) || shouldUpdateItemdefs
    }

    if (!shouldCheckInventory)
      return cb(newItems)

    if (shouldUpdateItemdefs) {
      requestItemDefs(function() {
        if (cb) {
          for (local i = newItems.len() - 1; i >= 0; --i) {
            if (typeof(newItems[i].itemdef) != "table") {
              newItems.remove(i)
            }
          }

          cb(newItems)
        }
      })
    }
    else {
      notifyInventoryUpdate(hasInventoryChanges)
      if (cb) {
        cb(newItems)
      }
    }
  }

  function exchangeViaChard(materials, outputItemDefId, cb = null, errocCb = null, shouldCheckInventory = true, requirement = null) {
    local json = {
      outputitemdefid = outputItemDefId
      materials = materials
    }
    if (::u.isString(requirement) && requirement.len() > 0)
    {
      json["permission"] <- requirement
    }

    local internalCb = ::Callback((@(cb, shouldCheckInventory) function(data) {
                                     handleItemsDelta(data, cb, errocCb, shouldCheckInventory)
                                 })(cb, shouldCheckInventory), this)
    local taskId = ::char_send_custom_action("cln_inventory_exchange_items",
                                             EATT_JSON_REQUEST,
                                             ::DataBlock(),
                                             ::json_to_string(json, false),
                                             -1)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, internalCb, null, TASK_CB_TYPE.REQUEST_DATA)
  }

  function exchangeDirect(materials, outputItemDefId, cb = null, errocCb = null, shouldCheckInventory = true) {
    local req = {
        outputitemdefid = outputItemDefId,
        materials = materials
    }

    request("ExchangeItems", {}, req,
      function(result) {
        handleItemsDelta(result, cb, errocCb, shouldCheckInventory)
      },
      { }
    )
  }

  function exchange(materials, outputItemDefId, cb = null, errocCb = null, shouldCheckInventory = true, requirement = null) {
    // We can continue to use exchangeDirect if requirement is null. It would be
    // better to use exchangeViaChard in all cases for the sake of consistency,
    // but this will break compatibility with the char server. This distinction
    // can be removed later.

    if (!::u.isString(requirement) || requirement.len() == 0)
    {
      exchangeDirect(materials, outputItemDefId, cb, errocCb, shouldCheckInventory)
      return
    }

    exchangeViaChard(materials, outputItemDefId, cb, errocCb, shouldCheckInventory, requirement)
  }

  function getChestGeneratorItemdefIds(itemdefid) {
    local usedToCreate = itemdefs?[itemdefid]?.used_to_create
    local parsedRecipes = parseRecipesString(usedToCreate)

    local res = []
    foreach (recipeCfg in parsedRecipes)
    {
      local id = ::to_integer_safe(recipeCfg.components?[0]?.itemdefid ?? "", -1)
      if (id != -1)
        res.append(id)
    }
    return res
  }

  function canRefreshData()
  {
    return ::has_feature("ExtInventory")
  }

  function forceRefreshItemDefs()
  {
    requestItemDefs(function() {
      notifyInventoryUpdate(true, true)
    }, true)
  }

  function requestPrices()
  {
    request("GetItemPrices",
      { currency = WAR_THUNDER_EAGLES },
      null,
      function(result) {
        local itemPrices = result?.response?.itemPrices
        if (!::u.isArray(itemPrices))
        {
          notifyPricesChanged()
          return
        }

        prices.clear()
        local shouldRequestItemdefs = false
        foreach(data in itemPrices)
        {
          local itemdefid = data?.itemdefid
          if (itemdefid == null)
            continue
          prices[itemdefid] <- ::Cost(0, data?.price)
          shouldRequestItemdefs = addItemDefIdToRequest(itemdefid) || shouldRequestItemdefs
        }

        if (shouldRequestItemdefs)
          requestItemDefs(notifyPricesChanged)
        else
          notifyPricesChanged()
      })
  }

  function notifyPricesChanged()
  {
    ::broadcastEvent("ExtPricesChanged")
  }

  function onEventSignOut(p)
  {
    lastUpdateTime = -1
    firstProfileLoadComplete = false
    prices.clear()
    items.clear()
  }

  function cancelDelayedExchange(itemUid, cb = null, errocCb = null) {
    request("CancelDelayedExchange",
      { itemId = itemUid },
      null,
      @(result) handleItemsDelta(result, cb, errocCb)
    )
  }

}

return InventoryClient()