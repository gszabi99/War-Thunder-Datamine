require ecs
require math

require %appGame.wt_events
require DagorSystem
require DagorMath
require AnimV20
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
    weap__sightEid = gun_anim__weapModEid
  else
    weap__sightEid = eid

[es]
def weapon_switch_sight_es(evt : CmdWeapSwitchSight;
                           weap__sightEid : EntityId)
  query(weap__sightEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                   sightPresets : Array;
                                   var weap__current_sight_preset : int&;
                                   var weapon_frontsight_node__nodeIdx : int&;
                                   var weapon_rearsight_node__nodeIdx : int&)
    let sightPresetsCount = sightPresets |> length()
    assert(sightPresetsCount > 0)
    let inc = evt.toNext ? +1 : -1
    weap__current_sight_preset = (weap__current_sight_preset + inc + sightPresetsCount) % sightPresetsCount

    let preset = get_ecs_object(sightPresets[weap__current_sight_preset])

    let frontsightNodeName = preset |> get_string("frontsightNode", "")
    if frontsightNodeName != ""
      let nodeIdx = find_weapon_sight_node_idx(weap__sightEid, animchar, frontsightNodeName)
      weapon_frontsight_node__nodeIdx = nodeIdx

    let rearsightNodeName = preset |> get_string("rearsightNode", "")
    if rearsightNodeName != ""
      let nodeIdx = find_weapon_sight_node_idx(weap__sightEid, animchar, rearsightNodeName)
      weapon_rearsight_node__nodeIdx = nodeIdx
