require ecs


def add_controllable_hero_item(itemEid)
  if !!itemEid && !has(itemEid, "item__owned_controllable_hero")
    addSubTemplate(itemEid, "controllable_hero_item")


def remove_controllable_hero_item(itemEid)
  if has(itemEid, "item__owned_controllable_hero")
    removeSubTemplate(itemEid, "controllable_hero_item")


def for_each_item(itemContainer : EidList; human_equipment__slots : Object; cb : block<(EntityId) : void>)
  for itemEid in itemContainer
    invoke(cb, itemEid)

  for it in human_equipment__slots
    let slot = get_ecs_object(it.value)
    if slot != null
      let itemEid = get_Eid(*slot, "item") ?? INVALID_ENTITY_ID
      invoke(cb, itemEid)

[es(tag=gameClient, on_appear, track=(itemContainer, human_equipment__slots), REQUIRE=hero, REQUIRE_NOT=isReplayObserved)]
def track_hero_items_appear_es(evt : Event; isAlive : bool; itemContainer : EidList; human_equipment__slots : Object)
  if isAlive
    for_each_item(itemContainer, human_equipment__slots) <| $(eid : EntityId)
      add_controllable_hero_item(eid)

[es(tag=gameClient, on_disappear, REQUIRE=hero)]
def track_hero_items_disappear_es(evt : Event; itemContainer : EidList; human_equipment__slots : Object)
  for_each_item(itemContainer, human_equipment__slots) <| $(eid : EntityId)
    remove_controllable_hero_item(eid)

[es(tag=gameClient, track=isAlive, REQUIRE=hero)]
def track_died_hero_items_es(evt : Event; isAlive : bool; itemContainer : EidList; human_equipment__slots : Object)
  if !isAlive
    for_each_item(itemContainer, human_equipment__slots) <| $(eid : EntityId)
      remove_controllable_hero_item(eid)

[es(on_appear, track=item__ownerEid, tag=gameClient)]
def controlable_hero_items_es(evt : Event; eid : EntityId; item__ownerEid : EntityId)
  if has(item__ownerEid, "hero") && !has(item__ownerEid, "isReplayObserved")
    addSubTemplate(eid, "controllable_hero_item")
  elif has(eid, "item__owned_controllable_hero")
    removeSubTemplate(eid, "controllable_hero_item")
