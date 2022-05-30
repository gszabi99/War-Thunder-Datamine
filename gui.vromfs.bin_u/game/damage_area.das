require ecs
require %game.utils_common
require %dasGameLibs.math.base
require DagorMath
require DagorDebug3D
require DagorConsole
require GamePhys
require Level
require Mission
require WTDamageModel
require WTFx
require DmDebug


[es(on_appear)]
def damage_area_init(evt : Event;
                     damage_area__pos1 : float3;
                     var damage_area__vel : float3&;
                     damage_area__fallVel : float3;
                     damage_area__velocityMult : float;
                     damage_area__maxRise : float)
  let speed = length(damage_area__fallVel) * damage_area__velocityMult
  let verSpeed = min(abs(damage_area__fallVel.y), sqrt(2. * damage_area__maxRise * gravity()));
  let horSpeed = sqrt(square(speed) - square(verSpeed))
  var horVel = float2(damage_area__fallVel.x, damage_area__fallVel.z)
  horVel = normalize(horVel) * horSpeed
  damage_area__vel.x = horVel.x
  damage_area__vel.y = verSpeed
  damage_area__vel.z = horVel.y
  let dbgId = int(DmDebugTool DAMAGE_AREA)
  if (is_dm_dbg_tool_enabled(dbgId))
    let dbgMinorId = 1
    let fallVecColor = E3DCOLOR(0xFF00FF00)
    let p1 = damage_area__pos1 - damage_area__fallVel
    dm_dbg_render_add_line_3d(dbgId, dbgMinorId, damage_area__pos1, p1, fallVecColor)


[es]
def damage_area_update_move_es(act : UpdateStageInfoAct;
                               var damage_area__move : bool&;
                               var damage_area__pos2 : float3&;
                               damage_area__vel, damage_area__pos1 : float3;
                               var damage_area__flightTime : float&;
                               damage_area__maxFlightTime, damage_area__maxFlightDist : float)
  if (damage_area__move)
    damage_area__pos2 += (act.dt * damage_area__vel - float3(0., -0.5 * square(act.dt) * gravity(), 0.))
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
    var pos2 = damage_area__pos2;
    pos2.y = get_scene_height(damage_area__pos2);
    volumetric_damage(damage_area__pos1, pos2, damage_area__radius,
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
  if (!damage_area__move && damage_area__scorchStrength > 0. && damage_area__scorchDuration > 0.)
    damage_area_destroy_fx(damage_area__fxId)
    damage_area__fxId = -1
    let decalDir = normalize(damage_area__pos2 - damage_area__pos1)
    let decalPos = damage_area__pos1 - decalDir * damage_area__radius
    let decalLen = length(damage_area__pos1 - damage_area__pos2) + damage_area__radius * 2.
    let decalSize = float2(decalLen + damage_area__scorchMarginSize, damage_area__radius + damage_area__scorchMarginSize)
    add_burning_decals(decalPos, decalDir, decalSize, damage_area__scorchStrength, damage_area__scorchDuration)
    let dbgId = int(DmDebugTool DAMAGE_AREA)
    if (is_dm_dbg_tool_enabled(dbgId))
      let dbgMinorId = 0
      let scorchColor = E3DCOLOR(0xFF000000)
      let p1 = decalPos + decalDir * decalSize.x
      dm_dbg_render_add_line_3d(dbgId, dbgMinorId, decalPos, p1, scorchColor)


[es(tag=gameClient, track=damage_area__pos2)]
def damage_area_pos_track_es(evt : Event;
                             damage_area__pos1 : float3;
                             damage_area__pos2 : float3;
                             damage_area__radius : float;
                             damage_area__vel : float3;
                             damage_area__fxId : int;
                             damage_area__burnFxType : string;
                             damage_area__burnFxSize : float;
                             var damage_area__burnFxIds : ecs::IntList&)
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
  let dbgId = int(DmDebugTool DAMAGE_AREA)
  if (is_dm_dbg_tool_enabled(dbgId))
    let dbgMinorId = 0
    let emitterColor = E3DCOLOR(0xFFFF8F8F)
    let combustColor = E3DCOLOR(0xFFFFFF00)
    dm_dbg_render_clear(dbgId, dbgMinorId)
    dm_dbg_render_add_sph(dbgId, dbgMinorId, damage_area__pos2, damage_area__radius, emitterColor);
    var pos2 = damage_area__pos2;
    pos2.y = get_scene_height(damage_area__pos2);
    dm_dbg_render_add_capsule(dbgId, dbgMinorId, damage_area__pos1, pos2, damage_area__radius, combustColor)
