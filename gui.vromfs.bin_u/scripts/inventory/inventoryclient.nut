from "%scripts/dagui_natives.nut" import get_cur_circuit_name, char_send_custom_action
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import LOST_DELAYED_ACTION_MSEC

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let inventory = require("inventory")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { split_by_chars } = require("string")
let { get_time_msec } = require("dagor.time")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let contentSignKeys = require("%scripts/inventory/inventoryContentSign.nut")
let { APP_ID } = require("app")
let { encode_uri_component } = require("url")
let DataBlock = require("DataBlock")
let { object_to_json_string } = require("json")
let { cutPrefix } = require("%sqstd/string.nut")
let { TASK_CB_TYPE, addTask } = require("%scripts/tasker.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { get_network_block } = require("blkGetters")
let { getCurrentSteamLanguage } = require("%scripts/langUtils/language.nut")
let { mnSubscribe, mrSubscribe } = require("%scripts/matching/serviceNotifications/mrpc.nut")
let { steam_is_running, steam_get_my_id, steam_get_app_id } = require("steam")

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
const WAR_THUNDER_WARPOINTS = "WTS"

function getPremultipliedAlphaIcon(icon) {
  if (icon == "" || icon.slice(0, 1) == "!")
    return icon
  return $"!{icon}"
}

let validateValueFunction = {
  icon_url = getPremultipliedAlphaIcon
  icon_url_large = getPremultipliedAlphaIcon
}

let requestInternal = function(requestData, data, callback, progressBoxData = null) {
  if (data) {
    requestData["data"] <- data;
  }

  if (progressBoxData)
    progressMsg.create(INVENTORY_PROGRESS_MSG_ID, progressBoxData)

  inventory.request(requestData, function(res) {
    callback(res)
    if (progressBoxData)
      progressMsg.destroy(INVENTORY_PROGRESS_MSG_ID, true)
  })
}

let getErrorId = @(result) result.error.split(":")[0]
let priceEagles = mkWatched(persist, "priceEagles", {})
let priceWarPoint = mkWatched(persist, "priceWarPoint", {})
let prices = Computed(function() {
  let res = clone priceWarPoint.value

  foreach (key, value in priceEagles.value) {
    if (key in res) {
      res[key] = res[key] + value
    }
    else{
      res[key] <- value
    }
  }
  return res
})

function notifyPricesChanged() {
  broadcastEvent("ExtPricesChanged")
}
prices.subscribe(@(_) notifyPricesChanged())

const REQUEST_TIMEOUT_MSEC = 15000

let validateResponseData = {
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

let tagsValueRemap = {
  yes         = true,
  no          = false,
  ["true"]    = true,
  ["false"]   = false,
}


function _validate(data, name) {
  let validation = validateResponseData?[name]
  if (!data || !validation)
    return data

  if (!u.isArray(data))
    return null

  local itemsBroken  = []
  local keysMissing   = {}
  local keysWrongType = {}

  for (local i = data.len() - 1; i >= 0; i--) {
    let item = data[i]
    local isItemValid = u.isTable(item)
    local itemErrors = 0

    foreach (checks, keys in validation) {
      let shouldInvalidate     = (checks & validationCheckBitMask.INVALIDATE) != 0
      let shouldCheckExistence = (checks & validationCheckBitMask.EXISTENCE) != 0
      let shouldCheckType      = (checks & validationCheckBitMask.VARTYPE) != 0
      let shouldValidateValue  = (checks & validationCheckBitMask.VALUE) != 0

      if (isItemValid)
        foreach (key, defVal in keys) {
          let isExist = (key in item)
          let val = item?[key]
          let isTypeCorrect = isExist && (type(val) == type(defVal) || is_numeric(val) == is_numeric(defVal))

          let isMissing   = shouldCheckExistence && !isExist
          let isWrongType = shouldCheckType && isExist && !isTypeCorrect
          if (isMissing || isWrongType) {
            itemErrors++

            if (isMissing)
              keysMissing[key] <- true
            if (isWrongType)
              keysWrongType[key] <- $"{type(val)},{val}"

            if (shouldInvalidate)
              isItemValid = false

            item[key] <- defVal
          }

          if (shouldValidateValue)
            item[key] = validateValueFunction[key](item[key])
        }
    }

    if (!isItemValid || itemErrors) {
      let itemDebug = []
      foreach (checks, keys in validation)
        if (checks & validationCheckBitMask.INVALIDATE)
          foreach (key, _val in keys)
            if (key in item)
              itemDebug.append($"{key}={item[key]}")
      itemDebug.append(isItemValid ? ($"err={itemErrors}") : "INVALID")
      itemDebug.append(u.isTable(item) ? $"len={item.len()}" : $"var={type(item)}")

      itemsBroken.append(",".join(itemDebug, true))
    }

    if (!isItemValid)
      data.remove(i)
  }

  if (itemsBroken.len() || keysMissing.len() || keysWrongType.len()) {
    itemsBroken = ";".join(itemsBroken, true) // warning disable: -assigned-never-used
    keysMissing = ";".join(keysMissing.keys(), true) // warning disable: -assigned-never-used
    keysWrongType = ";".join(keysWrongType.topairs().map(@(i) $"{i[0]}={i[1]}")) // warning disable: -assigned-never-used
    script_net_assert_once("inventory client bad response", $"InventoryClient: Response has errors: {name}")
  }

  return data
}


let class InventoryClient {
  items = {}
  itemdefs = {}
  itemsForRequest = {}

  lastUpdateTime = -1
  lastRequestTime = -1

  lastItemdefsRequestTime = -1
  itemdefidsRequested = {} // Failed ids stays here, to avoid repeated requests.
  pendingItemDefRequest = null

  firstProfileLoadComplete = false
  needRefreshItems = false
  haveInitializedPublicKeys = false

  constructor() {
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    if (::g_login.isProfileReceived())
      this.refreshDataOnAuthorization()
  }

  function onEventProfileUpdated(_p) {
    if (!this.firstProfileLoadComplete)
      this.refreshDataOnAuthorization()
    this.firstProfileLoadComplete = true
  }

  function refreshDataOnAuthorization() {
    this.refreshItems()
    this.requestPrices()
  }


  function request(action, headers, data, callback, progressBoxData = null) {
    headers.appid <- APP_ID
    let requestData = {
      add_token = true
      headers
      action
    }
    requestInternal(requestData, data, callback.bindenv(this), progressBoxData)
  }


  function requestWithSignCheck(action, headers, data, callback, progressBoxData = null) {
    if (!contentSignKeys.initialized)
      return this.request(action, headers, data, callback, progressBoxData)

    headers.appid <- APP_ID
    let requestData = {
      content_sign_check = true,
      add_token = true,
      headers = headers,
      action = action
    }
    requestInternal(requestData, data, callback.bindenv(this), progressBoxData)
  }


  function getResultData(result, name) {
    let data = result?.response?[name]
    return _validate(data, name)
  }

  function getMarketplaceBaseUrl() {
    let circuit = get_cur_circuit_name();
    let networkBlock = get_network_block();
    let url = networkBlock?[circuit]?.marketplaceURL ?? networkBlock?.marketplaceURL;
    if (!url)
      return null

    return "".concat($"auto_login auto_local sso_service=any {url}", "?a=", APP_ID,
      (steam_is_running() ? $"&app_id={steam_get_app_id()}&steam_id={steam_get_my_id()}" : ""))
  }

  function getMarketplaceItemUrl(itemdefid, _itemid = null) {
    let marketplaceBaseUrl = this.getMarketplaceBaseUrl()
    if (!marketplaceBaseUrl)
      return null

    let item = itemdefid && this.itemdefs?[itemdefid]
    if ((item?.market_hash_name ?? "") != "")
      return "".concat(marketplaceBaseUrl, "&viewitem&n=", encode_uri_component(item.market_hash_name))

    return null
  }

  function addInventoryItem(item) {
    let itemdefid = item.itemdef
    let shouldUpdateItemdDefs = this.addItemDefIdToRequest(itemdefid)
    item.itemdefid <- itemdefid
    item.itemdef = this.itemsForRequest?[itemdefid] ?? this.itemdefs[itemdefid] //fix me: why we use same field name for other purposes?
    this.items[item.itemid] <- item
    return shouldUpdateItemdDefs
  }

  function refreshItems() {
    if (this.needRefreshItems)
      return

    if (!this.canRefreshData())
      return

    this.needRefreshItems = true
    log("schedule requestItems")
    ::g_delayed_actions.add(this.requestItemsInternal.bindenv(this), 100)
  }

  isWaitForInventory = @() this.canRefreshData() && this.lastUpdateTime < 0

  function requestItemsInternal() {
    this.needRefreshItems = false
    if (!this.canRefreshData())
      return

    let wasWaitForInventory = this.isWaitForInventory()
    this.lastRequestTime = get_time_msec()
    this.requestInventory(function(result) {
      this.lastUpdateTime = get_time_msec()
      local hasInventoryChanges = false
      if (wasWaitForInventory)
        hasInventoryChanges = true //need event about we received inventory once, even if it empty.

      let itemJson = this.getResultData(result, "item_json");
      if (!itemJson) {
        if (wasWaitForInventory)
          this.notifyInventoryUpdate(hasInventoryChanges)
        return
      }

      let oldItems = this.items
      local shouldUpdateItemdefs = false
      this.items = {}
      foreach (item in itemJson) {
        let oldItem = getTblValue(item.itemid, oldItems)
        if (oldItem) {
          if (oldItem.timestamp != item.timestamp) {
            hasInventoryChanges = true
          }

          this.addInventoryItem(item)
          oldItems.$rawdelete(item.itemid)

          continue
        }

        if (item.quantity <= 0)
          continue

        hasInventoryChanges = true
        shouldUpdateItemdefs = this.addInventoryItem(item) || shouldUpdateItemdefs
      }

      if (oldItems.len() > 0) {
        hasInventoryChanges = true
      }

      if (shouldUpdateItemdefs) {
        this.requestItemDefs()
      }
      else {
        this.notifyInventoryUpdate(hasInventoryChanges)
      }
    })
  }

  function requestInventory(callback) {
    this.request("GetInventory", {}, null, callback)
  }

  isItemdefRequestInProgress = @() this.lastItemdefsRequestTime >= 0
    && this.lastItemdefsRequestTime + REQUEST_TIMEOUT_MSEC > get_time_msec()

  function updatePendingItemDefRequest(cb, shouldRefreshAll) {
    if (!this.pendingItemDefRequest)
      this.pendingItemDefRequest = {
        cbList = [],
        shouldRefreshAll = false,
        fireCb = function() {
          foreach (c in this.cbList)
            c()
        }
      }
    this.pendingItemDefRequest.shouldRefreshAll = shouldRefreshAll || this.pendingItemDefRequest.shouldRefreshAll
    if (cb)
      this.pendingItemDefRequest.cbList.append(Callback(cb, this))
  }

  _lastDelayedItemdefsRequestTime = 0

  function requestItemDefs(cb = null, shouldRefreshAll = false) {
    this.updatePendingItemDefRequest(cb, shouldRefreshAll)
    if (this.isItemdefRequestInProgress()
        || (this._lastDelayedItemdefsRequestTime
          && (this._lastDelayedItemdefsRequestTime + LOST_DELAYED_ACTION_MSEC > get_time_msec())))
      return
    this._lastDelayedItemdefsRequestTime = get_time_msec()
    handlersManager.doDelayed(function() {
      this._lastDelayedItemdefsRequestTime = 0
      this.requestItemDefsImpl()
    }.bindenv(this))
  }

  function requestItemDefsImpl() {
    if (this.isItemdefRequestInProgress() || !this.pendingItemDefRequest)
      return
    let requestData = this.pendingItemDefRequest
    this.pendingItemDefRequest = null

    let itemdefidsRequest = []
    if (requestData.shouldRefreshAll) {
      this.itemdefidsRequested.clear()
      foreach (itemdefid, _value in this.itemdefs) {
        if (this.itemdefidsRequested?[itemdefid])
          continue

        itemdefidsRequest.append(itemdefid)
        this.itemdefidsRequested[itemdefid] <- true
      }
    }

    foreach (itemdefid, _value in this.itemsForRequest) {
      if (this.itemdefidsRequested?[itemdefid])
        continue
      itemdefidsRequest.append(itemdefid)
      this.itemdefidsRequested[itemdefid] <- true
    }

    if (!itemdefidsRequest.len())
      return requestData.fireCb()

    let itemdefidsString = ",".join(itemdefidsRequest, true)
    log($"Request itemdefs {itemdefidsString}")

    this.lastItemdefsRequestTime = get_time_msec()
    let steamLanguage = getCurrentSteamLanguage()
    this.requestWithSignCheck("GetItemDefsClient", { itemdefids = itemdefidsString, language = steamLanguage }, null,
      function(result) {
        this.lastItemdefsRequestTime = -1
        let itemdef_json = this.getResultData(result, "itemdef_json");
        if (!itemdef_json || steamLanguage != getCurrentSteamLanguage()) {
          requestData.fireCb()
          this.requestItemDefsImpl()
          return
        }

        local hasItemDefChanges = false
        foreach (itemdef in itemdef_json) {
          let itemdefid = itemdef.itemdefid
          this.itemdefidsRequested?.$rawdelete(itemdefid)
          hasItemDefChanges = hasItemDefChanges || requestData.shouldRefreshAll || u.isEmpty(this.itemdefs?[itemdefid])
          this.addItemDef(itemdef)
        }

        this.notifyInventoryUpdate(true, hasItemDefChanges)
        requestData.fireCb()
        this.requestItemDefsImpl()
      })
  }

  function removeItem(itemid) {
    this.items?.$rawdelete(itemid)
    this.notifyInventoryUpdate(true)
  }

  function notifyInventoryUpdate(hasInventoryChanges = false, hasItemDefChanges = false) {
    if (hasItemDefChanges) {
      log("ExtInventory itemDef changed")
      broadcastEvent("ItemDefChanged")
    }
    if (hasInventoryChanges) {
      log("ExtInventory changed")
      broadcastEvent("ExtInventoryChanged")
    }
  }

  getItems             = @() this.items
  getItemdefs          = @() this.itemdefs
  getItemCost          = @(itemdefid) prices.value?[itemdefid] ?? zero_money

  function addItemDefIdToRequest(itemdefid) {
    if (itemdefid == null || itemdefid in this.itemdefs || itemdefid in this.itemsForRequest)
      return false

    this.itemsForRequest[itemdefid] <- {}
    return true
  }

  function requestItemdefsByIds(itemdefIdsList, cb = null) {
    foreach (itemdefid in itemdefIdsList)
      this.addItemDefIdToRequest(itemdefid)
    this.requestItemDefs(cb)
  }

  function addItemDef(itemdef) {
    let originalItemDef = this.itemsForRequest?[itemdef.itemdefid] ?? this.itemdefs?[itemdef.itemdefid] ?? {}
    originalItemDef.clear()
    originalItemDef.__update(itemdef)
    originalItemDef.tags = this.getTagsItemDef(originalItemDef)
    this.itemdefs[itemdef.itemdefid] <- originalItemDef
    if (itemdef.itemdefid in this.itemsForRequest)
      this.itemsForRequest.$rawdelete(itemdef.itemdefid)
  }

  function getTagsItemDef(itemdef) {
    let tags = getTblValue("tags",  itemdef, null)
    if (!tags)
      return null

    let parsedTags = DataBlock()
    foreach (pair in split_by_chars(tags, ";")) {
      let parsed = split_by_chars(pair, ":")
      if (parsed.len() == 2) {
        let v = parsed[1]
        parsedTags[parsed[0]] <- tagsValueRemap?[v] ?? v
      }
    }
    return parsedTags
  }

  function parseRecipesString(recipesStr) {
    let recipes = []
    foreach (recipe in split_by_chars(recipesStr || "", ";")) {
      let parsedRecipe = {
        components = []
        reqItems = []
        requirement = null
        recipeStr = recipe
      }
      foreach (component in split_by_chars(recipe, ",")) {
        let requirement = cutPrefix(component, "require=")
        if (requirement != null) {
          parsedRecipe.requirement = requirement
          continue
        }
        let reqItems = cutPrefix(component, "req_items=")
        if (reqItems != null) {
          foreach (reqItem in split_by_chars(reqItems, "+")) {
            let pair = split_by_chars(reqItem, "x")
            if (!pair.len())
              continue
            parsedRecipe.reqItems.append({
              itemdefid = to_integer_safe(pair[0])
              quantity  = (1 in pair) ? to_integer_safe(pair[1]) : 1
            })
          }
          continue
        }

        let pair = split_by_chars(component, "x")
        if (!pair.len())
          continue
        parsedRecipe.components.append({
          itemdefid = to_integer_safe(pair[0])
          quantity  = (1 in pair) ? to_integer_safe(pair[1]) : 1
        })
      }
      recipes.append(parsedRecipe)
    }
    return recipes
  }

  function handleItemsDelta(result, cb = null, errocCb = null) {
    if (result?.error != null) {
      errocCb?(getErrorId(result))
      return
    }

    let itemJson = this.getResultData(result, "item_json")
    if (!itemJson)
      return

    let newItems = []
    local shouldUpdateItemdefs = false
    local hasInventoryChanges = false
    foreach (item in itemJson) {
      let oldItem = getTblValue(item.itemid, this.items)
      if (item.quantity == 0) {
        if (oldItem) {
          this.items.$rawdelete(item.itemid)
          hasInventoryChanges = true
        }

        continue
      }

      if (oldItem) {
        this.addInventoryItem(item)
        hasInventoryChanges = true
        continue
      }

      newItems.append(item)
      hasInventoryChanges = true
      shouldUpdateItemdefs = this.addInventoryItem(item) || shouldUpdateItemdefs
    }

    if (shouldUpdateItemdefs) {
      this.requestItemDefs(function() {
        if (!cb)
          return

        for (local i = newItems.len() - 1; i >= 0; --i)
          if (type(newItems[i].itemdef) != "table") {
            newItems.remove(i)
          }

        cb(newItems)
      })
    }
    else {
      this.notifyInventoryUpdate(hasInventoryChanges)
      cb?(newItems)
    }
  }

  function exchangeViaChard(materials, outputItemDefId, quantity, cb = null, errocCb = null, requirement = null) {
    let json = {
      outputitemdefid = outputItemDefId
      quantity
      materials
    }
    if (u.isString(requirement) && requirement.len() > 0) {
      json["permission"] <- requirement
    }

    let internalCb = Callback( function(data) {
                                     this.handleItemsDelta(data, cb, errocCb)
                                 }, this)
    let taskId = char_send_custom_action("cln_inventory_exchange_items",
                                             EATT_JSON_REQUEST,
                                             DataBlock(),
                                             object_to_json_string(json, false),
                                             -1)
    addTask(taskId, { showProgressBox = true }, internalCb, null, TASK_CB_TYPE.REQUEST_DATA)
  }

  function exchangeDirect(materials, outputItemDefId, quantity, cb = null, errocCb = null) {
    let req = {
      outputitemdefid = outputItemDefId
      quantity
      materials
    }

    this.request("ExchangeItems", {}, req,
      function(result) {
        this.handleItemsDelta(result, cb, errocCb)
      },
      { }
    )
  }

  function exchange(materials, outputItemDefId, quantity, cb = null, errocCb = null, requirement = null) {
    // We can continue to use exchangeDirect if requirement is null. It would be
    // better to use exchangeViaChard in all cases for the sake of consistency,
    // but this will break compatibility with the char server. This distinction
    // can be removed later.

    if (!u.isString(requirement) || requirement.len() == 0) {
      this.exchangeDirect(materials, outputItemDefId, quantity, cb, errocCb)
      return
    }

    this.exchangeViaChard(materials, outputItemDefId, quantity, cb, errocCb, requirement)
  }

  function getChestGeneratorItemdefIds(itemdefid) {
    let usedToCreate = this.itemdefs?[itemdefid]?.used_to_create
    let parsedRecipes = this.parseRecipesString(usedToCreate)

    let res = []
    foreach (recipeCfg in parsedRecipes) {
      let id = to_integer_safe(recipeCfg.components?[0]?.itemdefid ?? "", -1)
      if (id != -1)
        res.append(id)
    }
    return res
  }

  function canRefreshData() {
    return hasFeature("ExtInventory")
  }

  function forceRefreshItemDefs(cb) {
    this.requestItemDefs(function() {
      cb()
      this.notifyInventoryUpdate(true, true)
    }, true)
  }

  function updatePrice(watch, result, typeOfPrice) {
    let itemPrices = result?.response?.itemPrices
    if (!u.isArray(itemPrices)) {
      notifyPricesChanged()
      return
    }
    let res = {}
    local shouldRequestItemdefs = false
    foreach (data in itemPrices) {
      let itemdefid = data?.itemdefid
      if (itemdefid == null)
        continue
      res[itemdefid] <- typeOfPrice == WAR_THUNDER_EAGLES ? Cost(0, data?.price) : Cost(data?.price, 0)
      shouldRequestItemdefs = this.addItemDefIdToRequest(itemdefid) || shouldRequestItemdefs
    }
    watch(res)

    if (shouldRequestItemdefs)
      this.requestItemDefs(notifyPricesChanged)
  }

  function requestPrices() {
    this.request("GetItemPrices",
      { currency = WAR_THUNDER_EAGLES },
      null,
      @(result) this.updatePrice(priceEagles, result, WAR_THUNDER_EAGLES)
    )

    this.request("GetItemPrices",
      { currency = WAR_THUNDER_WARPOINTS },
      null,
      @(result) this.updatePrice(priceWarPoint, result, WAR_THUNDER_WARPOINTS)
    )
  }

  function onEventSignOut(_p) {
    this.lastUpdateTime = -1
    this.firstProfileLoadComplete = false
    priceEagles.value.clear()
    priceWarPoint.value.clear()
    this.items.clear()
  }

  function cancelDelayedExchange(itemUid, cb = null, errocCb = null) {
    this.request("CancelDelayedExchange",
      { itemId = itemUid },
      null,
      @(result) this.handleItemsDelta(result, cb, errocCb)
    )
  }
}

let client = InventoryClient()

function handleRpc(params) {
  if (params.func == "changed") {
    client.refreshItems()
  }
}

mnSubscribe("inventory", handleRpc)
mrSubscribe("inventory", @(params, _cb) handleRpc(params))

return client
