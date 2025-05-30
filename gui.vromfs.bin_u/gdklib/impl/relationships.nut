let rel = require("gdk.relationships")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")


function update_friends_list(fire_events, callback) {
  let eventName = "xbox_update_friends_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let success = res.success
    callback?(success)
  })
  rel.update_friends_list(fire_events, eventName)
}


function update_mute_list(fire_events, callback) {
  let eventName = "xbox_update_mute_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let success = res.success
    callback?(success)
  })
  rel.update_mute_list(fire_events, eventName)
}


function update_avoid_list(fire_events, callback) {
  let eventName = "xbox_update_avoid_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let success = res.success
    callback?(success)
  })
  rel.update_avoid_list(fire_events, eventName)
}


function retrieve_related_people_list(callback) {
  let eventName = "xbox_get_related_people_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let xuids = res?.xuids
    callback?(xuids)
  })
  rel.get_related_people_list(eventName)
}


function retrieve_avoid_people_list(callback) {
  let eventName = "xbox_get_avoid_people_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let xuids = res?.xuids
    callback?(xuids)
  })
  rel.get_avoid_people_list(eventName)
}


function retrieve_muted_people_list(callback) {
  let eventName = "xbox_get_get_muted_people_list"
  eventbus_subscribe_onehit(eventName, function(res) {
    let xuids = res?.xuids
    callback?(xuids)
  })
  rel.get_muted_people_list(eventName)
}


function subscribe_to_relationships_change_events(callback) {
  let eventName = "relationships_changed"
  rel.install_relationships_handler()
  eventbus_subscribe(eventName, function(res) {
    let list = res?.list
    let change_type = res?.type
    let xuids = res?.xuids
    callback?(list, change_type, xuids)
  })
}


return {
  ListType = rel.ListType
  ChangeType = rel.ChangeType

  subscribe_to_changes = rel.subscribe_to_changes
  unsubscribe_from_changes = rel.unsubscribe_from_changes
  cleanup_relationships = rel.cleanup

  update_friends_list
  update_mute_list
  update_avoid_list

  retrieve_related_people_list
  retrieve_avoid_people_list
  retrieve_muted_people_list

  subscribe_to_relationships_change_events
}