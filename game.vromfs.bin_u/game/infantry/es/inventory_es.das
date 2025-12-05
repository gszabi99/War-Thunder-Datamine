require ecs
require app
require net
require DngHuman
require HumanPhys
require DagorSystem
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.inventory_common

[es(tag=server, REQUIRE=human_inventory)]
def inventory_use_item_server_es(evt : EventUseItem;
                                 eid : EntityId;
                                 isAlive : bool;
                                 var human_net_phys : HumanActor&;
                                 var human_inventory__targetToUse : EntityId&;
                                 var human_inventory__entityUseStart : float&;
                                 var human_inventory__entityUseEnd : float&;
                                 fortification_repair__active : bool;
                                 entity_mods__itemUseTimeMult : float = 1f;
                                 entity_mods__targetUseTimeMult : float = 1f;
                                 isDowned : bool = false;
                                 possessedByPlr : EntityId;
                                 name : string;
                                 surname : string;
                                 var human_inventory__entityToUse : EntityId&)
  let item = evt.item
  if !item
    return

  if item == human_inventory__entityToUse || fortification_repair__active
    sendEventImmediate(eid, EventInterruptItemUse())
    return

  if !isAlive
    return

  if !doesEntityExist(item)
    sendEventImmediate(eid, EventInterruptItemUse())
    return

  if human_inventory__entityToUse == item
    return

  if human_inventory__entityToUse != INVALID_ENTITY_ID
    sendEventImmediate(eid, EventInterruptItemUse())

  let target = evt.target
  let isSelfTargeting = target == INVALID_ENTITY_ID || target == eid
  var useTime = get_item_use_time(item, isDowned, isSelfTargeting)
  if useTime <= 0f
    return
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)
  useTime = max(0.1f, useTime * (isSelfTargeting ? entity_mods__itemUseTimeMult : entity_mods__targetUseTimeMult))
  let curTime = get_sync_time()
  human_inventory__entityUseEnd = curTime + useTime
  human_inventory__entityUseStart = curTime
  human_inventory__entityToUse = item
  human_inventory__targetToUse = target == INVALID_ENTITY_ID ? eid : target
  sendEventImmediate(human_inventory__entityToUse, EventOnItemStartUse(target = human_inventory__targetToUse))
  query(human_inventory__targetToUse) <| $ [es] (var hitpoints__revivingCount : int&;
                                                 var hitpoints__revivingStartTime : float&;
                                                 var hitpoints__revivingEndTime : float&;
                                                 var hitpoints__revivingUserName : das_string&;
                                                 isDowned : bool)
    if isDowned
      if possessedByPlr == INVALID_ENTITY_ID
        hitpoints__revivingUserName := "{name} {surname}"
      else
        query(possessedByPlr) <| $ [es] (name aka player_name : string)
          hitpoints__revivingUserName := player_name
      hitpoints__revivingStartTime = human_inventory__entityUseStart
      hitpoints__revivingEndTime = human_inventory__entityUseEnd
      hitpoints__revivingCount = max(0, hitpoints__revivingCount) + 1

[es(tag=netClient, REQUIRE=human_inventory)]
def inventory_use_item_client_es(evt : EventUseItem;
                                 eid : EntityId;
                                 human_inventory__entityToUse : EntityId) 
  let item = evt.item
  if !item
    return

  if item == human_inventory__entityToUse
    sendEventImmediate(eid, EventInterruptItemUse())
    return

  send_net_event(eid, HumanUseItemRequest(item = item, target = evt.target))

[es(tag=server, REQUIRE=human_inventory)]
def inventory_use_item_request_es(evt : HumanUseItemRequest; eid : EntityId)
  sendEvent(eid, EventUseItem(item = evt.item, target = evt.target))
