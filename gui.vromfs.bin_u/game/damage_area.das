require ecs
require DagorConsole
require GamePhys
require Level
require Mission
require WTDamageModel
require WTFx

[es]
def damage_area_update_move_es(act : UpdateStageInfoAct;
                               var damage_area__move : bool&;
                               var damage_area__pos2 : float3&;
                               damage_area__vel, damage_area__pos1 : float3;
                               var damage_area__flightTime : float&;
                               damage_area__maxFlightTime, damage_area__maxFlightDist : float)
  if (damage_area__move)
    damage_area__pos2 += (act.dt * damage_area__vel - float3(0., -0.5 * act.dt * act.dt * gravity(), 0.))
    damage_area__flightTime += act.dt
    let height = get_scene_height(damage_area__pos2);
    if (damage_area__pos2.y < height)
      if (height - damage_area__pos2.y > 0.5)
        damage_area__move = false
      damage_area__pos2.y = height
    if (damage_area__flightTime > damage_area__maxFlightTime || length(damage_area__pos1 - damage_area__pos2) > damage_area__maxFlightDist)
      damage_area__move = false

[es(tag=server, after=damage_area_update_move_es)]
def damage_area_update_es(act : UpdateStageInfoAct;
                          eid : EntityId;
                          damage_area__pos1, damage_area__pos2 : float3;
                          damage_area__endTime, damage_area__radius, damage_area__damage : float;
                          damage_area__damageTypeId, damage_area__offenderId, damage_area__seed : int;
                          var damage_area__nextUpdateTime : float&)
  if (act.curTime >= damage_area__endTime)
    destroyEntity(eid)
  if (act.curTime > damage_area__nextUpdateTime)
    damage_area__nextUpdateTime = act.curTime + 1.
    volumetric_damage(damage_area__pos1, damage_area__pos2, damage_area__radius,
      damage_area__damage, damage_area__damageTypeId, damage_area__offenderId, damage_area__seed)


[es(tag=gameClient, on_appear)]
def damage_area_create_client_fx_es(evt : Event;
                                    damage_area__pos2 : float3;
                                    damage_area__vel : float3;
                                    damage_area__fxType : string;
                                    var damage_area__fxId : int&)
  if (damage_area__fxId < 0)
    damage_area__fxId = damage_area_create_fx(damage_area__fxType, damage_area__pos2, damage_area__vel, true);


[es(tag=gameClient, on_disappear)]
def damage_area_destroy_client_es(evt : Event;
                                  damage_area__fxId : int;
                                  damage_area__burnFxIds : ecs::IntList)
  if (damage_area__fxId >= 0)
    damage_area_destroy_fx(damage_area__fxId)
  for burnFxId in damage_area__burnFxIds
    damage_area_destroy_fx(burnFxId)


[es(tag=gameClient, track=damage_area__move)]
def damage_area_move_track_es(evt : Event;
                              damage_area__move : bool;
                              damage_area__pos1, damage_area__pos2 : float3;
                              damage_area__radius : float;
                              var damage_area__fxId : int&;
                              damage_area__scorchMarginSize, damage_area__scorchStrength, damage_area__scorchDuration : float)
  if (!damage_area__move)
    damage_area_destroy_fx(damage_area__fxId)
    damage_area__fxId = -1
    let decalDir = normalize(damage_area__pos2 - damage_area__pos1)
    let decalPos = damage_area__pos1 - decalDir * damage_area__radius
    let decalLen = length(damage_area__pos1 - damage_area__pos2) + damage_area__radius * 2.
    let decalSize = float2(decalLen + damage_area__scorchMarginSize, damage_area__radius + damage_area__scorchMarginSize)
    add_burning_decals(decalPos, decalDir, decalSize, damage_area__scorchStrength, damage_area__scorchDuration)


[es(tag=gameClient, track=damage_area__pos2)]
def damage_area_pos_track_es(evt : Event;
                             damage_area__pos1 : float3;
                             damage_area__pos2 : float3;
                             damage_area__vel : float3;
                             damage_area__fxId : int;
                             damage_area__burnFxType : string;
                             damage_area__burnFxSize : float;
                             var damage_area__burnFxIds : ecs::IntList&)
  print("damage_area_print {damage_area__pos2}")
  if (damage_area__fxId >= 0)
    damage_area_update_fx(damage_area__fxId, damage_area__pos2, damage_area__vel, 1.)
  var count = 1
  if (damage_area__burnFxSize > 0.)
    count = int(length(damage_area__pos1 - damage_area__pos2) / damage_area__burnFxSize)
  if (length(damage_area__burnFxIds) < count)
    let dir = normalize(damage_area__pos2 - damage_area__pos1)
    let up = float3(1., 0., 0.)
    while length(damage_area__burnFxIds) < count
      let curCount = float(length(damage_area__burnFxIds));
      var fxPos = damage_area__pos1 + dir * (damage_area__burnFxSize * curCount)
      fxPos.y = get_scene_height(fxPos);
      let burnFxId = damage_area_create_fx(damage_area__burnFxType, fxPos, up, true)
      damage_area__burnFxIds |> push(burnFxId)
