from "%scripts/dagui_library.nut" import *

let { subscribe_onehit } = require("eventbus")
let { generate_items, get_all_items, is_running, add_promo_item, grant_promo_items } = require("steam")

let LOG_PREFIX = "[Steam Inventory] "
let logS = log_with_prefix($"{LOG_PREFIX} ")

const k_EResultOK = 1 


function requestAllItems(cb = null) {
  if (!is_running())
    return

  logS($"call requestAllItems")
  subscribe_onehit("steam.inventory_details", function(res) {
    if (res.result != k_EResultOK) {
      logS("error on requestAllItems request", res)
      return
    }

    logS(res)
    cb?(res)
  })
  get_all_items()
}

function addPromoItem(itemId) {
  subscribe_onehit("steam.inventory_result", function(res) {
    if (res.result != k_EResultOK) {
      logerr($"{LOG_PREFIX} error on addPromoItem request {itemId}")
      logS(res)
    }
  })
  add_promo_item(itemId)
}

function generateItems(itemsList) {
  subscribe_onehit("steam.inventory_result", function(res) {
    if (res.result != k_EResultOK) {
      logerr($"{LOG_PREFIX} error on generateItems request")
      logS(res)
    }
  })
  generate_items(itemsList)
}

function grantPromoItems(cb = null) {
  if (!is_running())
    return
  logS($"call grantPromoItems")
  subscribe_onehit("steam.inventory_result", function(res) {
    if (res.result != k_EResultOK) {
      logerr($"{LOG_PREFIX} error on grantPromoItems request")
      logS(res)
      return
    }
    logS($"finish grantPromoItems", res)
    cb?()
  })
  grant_promo_items()
}

return {
  requestAllItems
  addPromoItem
  generateItems
  grantPromoItems
}