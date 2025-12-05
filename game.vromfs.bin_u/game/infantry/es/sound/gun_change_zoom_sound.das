require ecs

require %appGame.wt_events
require DngWeapon
require soundEvent



[es(tag=sound, REQUIRE=watchedByPlr)]
def gun_change_zoom_sound(evt : NextVariableZoomGunScope;
                          human_weap__currentScope : EntityId;
                          human_weap__currentGunEid : EntityId)

  query(human_weap__currentGunEid) <| $ [es] (gun_change_zoom_sound__path : string; gun__integratedScope : bool = false)
    let gunScopeEid = human_weap__currentScope
    let gunModEid = gun__integratedScope && !gunScopeEid ? human_weap__currentGunEid : gunScopeEid

    query(gunModEid) <| $ [es] (gunmod__variableZoomOptions : Array)
      if length(gunmod__variableZoomOptions) > 1
        oneshot(gun_change_zoom_sound__path)
