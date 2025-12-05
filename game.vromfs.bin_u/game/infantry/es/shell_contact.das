
require ecs
require ecs.safe
require math.base
require DagorMath
require %appGame.wt_events
require %appGame.infantry.es.shell_fx_common
require Weapon
require Dacoll


def calc_effect_tm(pos : float3; norm : float3)
  var tm = IDENT_TM
  tm[1] = normalize(norm)
  tm[2] = normalize(cross(float3(1, 0, 0), tm[1]))
  tm[0] = normalize(cross(tm[1], tm[2]))
  tm[3] = pos
  return tm


def spawn_effect(pos : float3;
                 norm : float3;
                 fx_name : string)
  if empty(fx_name) || fx_name == "-"
    return
  let fxTm = calc_effect_tm(pos, norm)
  createEntity(fx_name) <| $(var init : ComponentsInitializer)
    set(init, "transform", fxTm)


def get_fx_name_based_on_surface(pos : float3;
                                 norm : float3;
                                 fx_info_eid : EntityId;
                                 is_under_water : bool;
                                 var riex_handle : riex_handle_t&)
  var res : string
  query(fx_info_eid) <| $ [es] (shell_contact_fx__traceLength : float;
                                shell_contact_fx__default : string;
                                shell_contact_fx__info : Object const?;
                                shell_contact_fx__tracePosOffset : float = 0.0)
    let matName = is_under_water ? "water3d" : get_surface_material_name(pos + norm * shell_contact_fx__tracePosOffset, -norm, shell_contact_fx__traceLength, riex_handle)
    let obj = shell_contact_fx__info?[matName] ?as Object
    res = obj?.fx ?? shell_contact_fx__default
  return res


def spawn_contact_effect(fx_info_template : string; pos : float3; norm : float3; is_under_water : bool = false)
  let fxInfoEid = getSingletonEntity(fx_info_template)
  var riExtraHandle : riex_handle_t
  let fxName = get_fx_name_based_on_surface(pos, norm, fxInfoEid, is_under_water, riExtraHandle)
  spawn_effect(pos, norm, fxName)


[es(tag=gameClient)]
def shell_save_norm_on_contact(evt : EventProjectilePhysContact;
                               var proj__lastContactNorm : float3&)
  proj__lastContactNorm = evt.norm


[es(tag=gameClient, no_order)]
def spawn_grenade_collision_vfx_on_contact(evt : UpdateStageInfoAct;
                                           shell_contact_fx__infoTemplate : string;
                                           proj__timeStep : float;
                                           proj__atTick : int;
                                           proj__lastContactNorm : float3;
                                           proj_collision__vfxDelay : float;
                                           proj_collision__vfxAccelThreshold : float;
                                           var proj_collision__nextVfxCheckAt : float&;
                                           var proj_collision__lastProcessedTick : int&;
                                           var proj_collision__prevVelocity : float3&;
                                           var proj_collision__isUnderWater : bool&;
                                           var proj__physObj : ProjectilePhysObject&)
  if proj__atTick <= proj_collision__lastProcessedTick
    return
  proj_collision__lastProcessedTick = proj__atTick
  let curPos = float3(proj__physObj |> phys().currentState.location.P)
  let prevPos = float3(proj__physObj |> phys().previousState.location.P)
  
  
  
  let curVel = (curPos - prevPos) / proj__timeStep
  let prevIsUnderWater = proj_collision__isUnderWater
  var waterLevel = 0.0
  proj_collision__isUnderWater = traceht_water(prevPos, waterLevel) && prevPos.y < waterLevel

  if evt.curTime >= proj_collision__nextVfxCheckAt
    if proj_collision__isUnderWater
      if !prevIsUnderWater
        proj_collision__nextVfxCheckAt = evt.curTime + proj_collision__vfxDelay
        spawn_contact_effect(shell_contact_fx__infoTemplate, prevPos, float3(0, 1, 0), true)
    elif length_sq(proj_collision__prevVelocity) > 0.0001 && proj__lastContactNorm != float3()
      let accel = (curVel - proj_collision__prevVelocity) / proj__timeStep
      if length_sq(accel) > square(proj_collision__vfxAccelThreshold)
        proj_collision__nextVfxCheckAt = evt.curTime + proj_collision__vfxDelay
        spawn_contact_effect(shell_contact_fx__infoTemplate, prevPos, proj__lastContactNorm)

  proj_collision__prevVelocity = curVel
