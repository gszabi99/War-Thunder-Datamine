let impl = require("%xboxLib/impl/store.nut")
let {eventbus_subscribe, eventbus_send} = require("eventbus")

let eventName = "XBOX_STORE_INITIALIZED_EVENT"


function subscribe_to_store_init(callback) {
  eventbus_subscribe(eventName, function(res) {
    callback?(res?.success ?? false)
  })
}


function initialize(callback) {
  impl.initialize(function(success) {
    callback?(success)
    eventbus_send(eventName, {success = success})
  })
}


return {
  ProductKind = impl.ProductKind

  initialize
  shutdown = impl.shutdown
  subscribe_to_store_init

  gather_products_list = impl.gather_products_list
  retrieve_product_info = impl.retrieve_product_info
  get_total_quantity = impl.get_total_quantity

  request_review = impl.request_review
  show_purchase = impl.show_purchase
  show_details = impl.show_details
  show_marketplace = impl.show_marketplace
}