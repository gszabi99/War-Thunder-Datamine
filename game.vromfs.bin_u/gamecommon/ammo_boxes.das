require ecs
require %game.events

[es(tag=server)]
def rearm_from_ammo_box_es(evt : EventRearmFromAmmoBox;
                           eid : EntityId;
                           var ammo_box__bulletCount : int&)
  ammo_box__bulletCount -= evt.count
  if ammo_box__bulletCount <= 0
    destroyEntity(eid)