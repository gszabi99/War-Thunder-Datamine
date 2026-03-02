require ecs
require math
require net

require %appGame.wt_events
require DagorSystem
require DagorMath
require AnimV20
require PhysVars
require GeomNodeTree

def find_weapon_sight_node_idx(eid : EntityId;
                               animchar : AnimcharBaseComponent;
                               nodeName : string) : int
  let nodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
  if (nodeIdx < 0)
    let templateName = getEntityTemplateName(eid)
    logerr("Can't find sight node {nodeName} in {templateName}")
  return nodeIdx


[es(on_appear)]
def weapon_laser_node_init(evt : Event;
                           animchar : AnimcharBaseComponent;
                           laser__fxNodeName : string;
                           var laser__fxNodeIdx : int&)
  laser__fxNodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(laser__fxNodeName)


[es(on_appear)]
def weapon_frontsight_node_init(evt : Event;
                                eid : EntityId;
                                animchar : AnimcharBaseComponent;
                                weapon_frontsight_node__nodeName : das_string const?;
                                var weapon_frontsight_node__nodeIdx : int&)
  let nodeName = weapon_frontsight_node__nodeName != null ? string(*weapon_frontsight_node__nodeName) : "frontsight_aim"
  let nodeIdx = find_weapon_sight_node_idx(eid, animchar, nodeName)
  weapon_frontsight_node__nodeIdx = nodeIdx

[es(on_appear)]
def weapon_rearsight_node_init(evt : Event;
                               eid : EntityId;
                               animchar : AnimcharBaseComponent;
                               weapon_rearsight_node__nodeName : das_string const?;
                               var weapon_rearsight_node__nodeIdx : int&)
  let nodeName = weapon_rearsight_node__nodeName != null ? string(*weapon_rearsight_node__nodeName) : "rearsight_aim"
  let nodeIdx = find_weapon_sight_node_idx(eid, animchar, nodeName)
  weapon_rearsight_node__nodeIdx = nodeIdx

[es(tag=render, after=slot_attach_init_tms_es)]
def update_gun_tm_info_for_render(info : UpdateStageInfoAct;
                                  animchar : AnimcharBaseComponent;
                                  weapon_rearsight_node__nodeIdx : int;
                                  var weapon_rearsight_node__nodeTm : mat44f&)
  if weapon_rearsight_node__nodeIdx < 0
    return

  var newTm : float3x4
  geomtree_getNodeWtmScalar(*animchar.nodeTree, weapon_rearsight_node__nodeIdx, newTm)
  weapon_rearsight_node__nodeTm = mat44f(newTm)

[es(tag=render, on_appear, track=gun_anim__weapModEid)]
def weapon_change_eid_for_sights_es(evt : Event;
                                    eid : EntityId;
                                    gun_anim__weapModEid : EntityId;
                                    var weap__sightEid : EntityId&)
  if has(gun_anim__weapModEid, "weapon_rearsight_node__nodeIdx")
    var useParentSight = false
    query(gun_anim__weapModEid) <| $ [es] (sightPresets : Array;
                                           weap__current_sight_preset : int)
      let presetsCount = length(sightPresets)
      if presetsCount > 0
        let presetIdx = clamp(weap__current_sight_preset, 0, presetsCount - 1)
        let preset = get_ecs_object(sightPresets[presetIdx])
        if preset != null
          let useWeaponSight = preset |> get_bool("useWeaponSight")
          if useWeaponSight != null && *useWeaponSight
            useParentSight = true
    weap__sightEid = useParentSight ? eid : gun_anim__weapModEid
  else
    weap__sightEid = eid

[es]
def weapon_switch_sight_es(evt : CmdWeapSwitchSight;
                           eid : EntityId;
                           gun_anim__weapModEid : EntityId;
                           weap__sightEid : EntityId)
  let parentGunEid = eid
  let presetsEid = !!gun_anim__weapModEid ? gun_anim__weapModEid : weap__sightEid
  query(presetsEid) <| $ [es] (animchar : AnimcharBaseComponent;
                               sightPresets : Array;
                               gun__owner : EntityId;
                               weapon__aimSightPresetIndex : int const?;
                               var weap__current_sight_preset : int&;
                               var gun__launchVerticalAngle : float&;
                               var phys_vars : PhysVars&;
                               var weapon__aimNodeOffset : float&;
                               var weapon_frontsight_node__nodeIdx : int&;
                               var weapon_rearsight_node__nodeIdx : int&)
    let sightPresetsCount = sightPresets |> length()
    assert(sightPresetsCount > 0)
    let inc = evt.toNext ? +1 : -1
    weap__current_sight_preset = (weap__current_sight_preset + inc + sightPresetsCount) % sightPresetsCount

    let preset = get_ecs_object(sightPresets[weap__current_sight_preset])

    let isUseWeaponSight = (preset |> get_bool("useWeaponSight")) ?? false
    let additionalAngle = preset |> get_float("additionalVertAngle")

    if isUseWeaponSight || additionalAngle != null
      let angle = isUseWeaponSight ? 0.0 : *additionalAngle
      gun__launchVerticalAngle = angle
      send_net_event(gun__owner, CmdSetGunLaunchVerticalAngle(gunEid = presetsEid, angle = angle))

    if isUseWeaponSight
      set(parentGunEid, "weap__sightEid", parentGunEid)
      return

    if weap__sightEid != presetsEid
      set(parentGunEid, "weap__sightEid", presetsEid)

    let aimOffset = preset |> get_float("aimNodeOffset")
    if aimOffset != null
      weapon__aimNodeOffset = *aimOffset

    let useAnimIndex = preset |> get_int("useAnimNodeIndex")
    if useAnimIndex != null && weapon__aimSightPresetIndex != null
      setVar(phys_vars, *weapon__aimSightPresetIndex, float(*useAnimIndex))
      return

    let frontsightNodeName = preset |> get_string("frontsightNode", "")
    if frontsightNodeName != ""
      let nodeIdx = find_weapon_sight_node_idx(presetsEid, animchar, frontsightNodeName)
      weapon_frontsight_node__nodeIdx = nodeIdx

    let rearsightNodeName = preset |> get_string("rearsightNode", "")
    if rearsightNodeName != ""
      let nodeIdx = find_weapon_sight_node_idx(presetsEid, animchar, rearsightNodeName)
      weapon_rearsight_node__nodeIdx = nodeIdx


[es(on_appear)]
def init_sight_preset_index_id(evt : Event;
                               var phys_vars : PhysVars&;
                               var weapon__gunAnimSightPresetIndexId : int&)
  weapon__gunAnimSightPresetIndexId = registerVar(phys_vars, "sight_preset_index", float(0))

[es(on_appear)]
def init_gun_launch_vertical_angle_es(evt : Event;
                                      sightPresets : Array;
                                      weap__current_sight_preset : int;
                                      var gun__launchVerticalAngle : float&;
                                      var weapon__aimNodeOffset : float&)
  let presetsCount = length(sightPresets)
  if presetsCount > 0
    let presetIdx = clamp(weap__current_sight_preset, 0, presetsCount - 1)
    let preset = get_ecs_object(sightPresets[presetIdx])
    if preset != null
      let aimOffset = preset |> get_float("aimNodeOffset")
      if aimOffset != null
        weapon__aimNodeOffset = *aimOffset
      let additionalAngle = preset |> get_float("additionalVertAngle")
      if additionalAngle != null
        gun__launchVerticalAngle = *additionalAngle

[es(tag=server, REQUIRE=human)]
def set_gun_launch_vertical_angle_es(evt : CmdSetGunLaunchVerticalAngle)
  query(evt.gunEid) <| $ [es] (var gun__launchVerticalAngle : float&)
    gun__launchVerticalAngle = evt.angle
