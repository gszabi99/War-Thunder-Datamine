let store = require("xbox.store")
let {eventbus_subscribe_onehit} = require("eventbus")


function initialize(callback) {
  let eventName = "xbox_store_initialize"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  store.initialize(eventName)
}


function gather_products_list(callback) {
  let eventName = "xbox_store_gather_products_list"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let products = result?.products
    callback?(success, products)
  })
  store.gather_products_list(eventName)
}


function retrieve_product_info(product_id, callback) {
  let eventName = "xbox_store_retrieve_product_info"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    let product = result?.product
    callback?(success, product)
  })
  store.get_product_info(product_id, eventName)
}


function request_review(callback) {
  let eventName = "xbox_store_request_review"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  store.request_review(eventName)
}


function show_purchase(offer_id, callback) {
  let eventName = "xbox_store_show_purchase"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  store.show_purchase(offer_id, eventName)
}


function show_details(product_id, callback) {
  let eventName = "xbox_store_show_details"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  store.show_details(product_id, eventName)
}


function show_marketplace(product_kind, callback) {
  let eventName = "xbox_store_show_marketplace"
  eventbus_subscribe_onehit(eventName, function(result) {
    let success = result?.success
    callback?(success)
  })
  store.show_marketplace(product_kind, eventName)
}


function get_total_quantity(product) {
  local res = 0
  foreach (sku in product?.skus ?? []) {
    res += sku?.quantity ?? 0
  }
  return res
}


return {
  ProductKind = store.ProductKind

  initialize
  shutdown = store.shutdown

  gather_products_list
  retrieve_product_info
  get_total_quantity

  request_review
  show_purchase
  show_details
  show_marketplace
}
