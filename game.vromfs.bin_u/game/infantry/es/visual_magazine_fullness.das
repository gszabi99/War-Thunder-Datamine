require ecs
require ecs.common
require %game.events

require %appGame.wt_events
require strings
require DagorConsole


[es(tag=gameClient, on_appear)]
def visual_magazine_fullness_on_init(evt : Event;
                                     anim_irq__eventNames : Object;
                                     var visual_magazine_fullness__irqId : int&)
  for event in anim_irq__eventNames
    let eventObj = get_ecs_object(event.value)
    if eventObj != null
      let eventName = event.key
      if !empty(eventName) && eventName == "newMagazineShown"
        visual_magazine_fullness__irqId = get_int(*eventObj, "irqId") ?? -1
        break


[es(tag=gameClient, track=gun__ammo, on_appear)]
def visual_magazine_fullness_track_ammo(evt : Event;
                                        gun__ammo : int;
                                        gun_anim__reloadProgress : float;
                                        var visual_magazine_fullness__ammoCount : int&)
  if gun_anim__reloadProgress <= 0.0
    visual_magazine_fullness__ammoCount = gun__ammo


[es(tag=gameClient)]
def visual_magazine_fullness_on_reload(evt : EventAnimIrq;
                                       gun__ammoToReloadCount : int;
                                       visual_magazine_fullness__irqId : int;
                                       var visual_magazine_fullness__ammoCount : int&)
  if evt.irqType == visual_magazine_fullness__irqId
    visual_magazine_fullness__ammoCount = gun__ammoToReloadCount
