require ecs
require net
require CollRes
require inventory
require ecs.common
require DagorSystem
require DngHuman
require HumanPhys
require DagorMath
require DagorMathUtils
require AnimV20

require %appGame.es.inventory_common






[es(tag=server, on_appear)]
def inventory_item_push_es(evt : Event; eid : EntityId; item__ownerEid : EntityId)
  query(item__ownerEid) <| $ [es] (var itemContainer : EidList)
    if find_index(itemContainer, eid) == -1
      push(itemContainer, eid)

[es(tag=server, on_appear)]
def set_armor_pickup_score(evt : Event; eid : EntityId; var item__pickupScore : float&; item__armorAmount : float)
  if item__pickupScore < 0.0
    item__pickupScore = item__armorAmount
  else
    logerr("item {getEntityTemplateName(eid)} has multiple pickupScore sources")


[es(tag=server, on_appear)]
def set_inventory_extension_pickup_score(evt : Event; eid : EntityId; var item__pickupScore : float&; item__inventoryExtension : float)
  if item__pickupScore < 0.0
    item__pickupScore = item__inventoryExtension
  else
    logerr("item {getEntityTemplateName(eid)} has multiple pickupScore sources")











































































































































