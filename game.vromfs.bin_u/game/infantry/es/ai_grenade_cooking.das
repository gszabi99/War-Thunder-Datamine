require ecs
require app
require %game.events


[es(tag=server)]
def ai_cook_grenade_on_throw_start(evt : EventOnGrenadeThrow;
                                   human_weap__grenadeThrower : EntityId;
                                   beh_tree__enabled : bool)
  
  
  
  
  if !beh_tree__enabled
    return
  query(human_weap__grenadeThrower) <| $ [es] (grenade_thrower__projectileEntity : EntityId)
    sendEvent(grenade_thrower__projectileEntity, CmdStartCookingGrenade(atTime = get_sync_time()))
