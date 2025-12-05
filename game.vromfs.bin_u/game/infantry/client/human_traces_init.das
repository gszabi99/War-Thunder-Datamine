require ecs
require GeomNodeTree
require AnimV20
require PhysMat
require Unit
require app

require %appGame.wt_events

def init_lod_nodes_list(animchar : AnimcharBaseComponent&; var node_ids : IntList; node_names : StringList)
  let nodesCount = length(node_names)
  resize(node_ids, nodesCount)
  for i in range(0, nodesCount)
    node_ids[i] = *animchar.nodeTree |> geomtree_findNodeIndex(string(node_names[i]))

[es(on_appear)]
def init_los_trace_material(evt : Event; nodes_los__traceMatName : string; var nodes_los__traceMatId : int&)
  nodes_los__traceMatId = get_material_id(nodes_los__traceMatName)

[es(on_appear)]
def init_los_lods_nodes(evt : Event;
                        animchar : AnimcharBaseComponent&;
                        var nodes_los__nodeIdlod0 : IntList;
                        nodes_los__nodeNamesLod0 : StringList;
                        var nodes_los__nodeIdlod1 : IntList;
                        nodes_los__nodeNamesLod1 : StringList;
                        var nodes_los__nodeIdlod2 : IntList;
                        nodes_los__nodeNamesLod2 : StringList;
                        var nodes_los__nodeIdlod3 : IntList;
                        nodes_los__nodeNamesLod3 : StringList)
  init_lod_nodes_list(animchar, nodes_los__nodeIdlod0, nodes_los__nodeNamesLod0)
  init_lod_nodes_list(animchar, nodes_los__nodeIdlod1, nodes_los__nodeNamesLod1)
  init_lod_nodes_list(animchar, nodes_los__nodeIdlod2, nodes_los__nodeNamesLod2)
  init_lod_nodes_list(animchar, nodes_los__nodeIdlod3, nodes_los__nodeNamesLod3)

[es(tag=gameClient)]
def markers_update_time_es(evt : EventEntityDied;
                           squad_member__playerEid : EntityId)
  if squad_member__playerEid != get_local_player_eid()
    return
  query(evt.offender) <| $ [es] (nodes_los__forceShowMarkerTime : float;
                                 var nodes_los__forceShowMarkerToTime : float&)
    nodes_los__forceShowMarkerToTime = get_sync_time() + nodes_los__forceShowMarkerTime


[es(tag=gameClient, no_order, REQUIRE_NOT=deadEntity)]
def save_human_los_cached_data(info : UpdateStageInfoAct;
                               unit__ref : UnitRef;
                               nodes_los__visiblePrecalc : bool;
                               nodes_los__forceShowMarkerToTime : float;
                               nodes_los__considerAsVisibleTime : float;
                               nodes_los__considerAsInvisibleTime : float;
                               nodes_los__considerMapAsVisibleTime : float;
                               var nodes_los__considerMapVisibleToTime : float&;
                               var nodes_los__considerVisibleToTime : float&;
                               var nodes_los__considerInvisibleToTime : float&;
                               var nodes_los__visible : bool&;
                               var nodes_los__showKillerMarker : bool&;
                               var nodes_los__showMarker : bool&;
                               var nodes_los__showMapMarker : bool&)
  let unit = unit__ref.unit
  if unit.isDelayed
    nodes_los__visible = false
    nodes_los__showMapMarker = false
    nodes_los__showMarker = false
    nodes_los__showKillerMarker = false
    return

  nodes_los__visible = nodes_los__visiblePrecalc
  nodes_los__showKillerMarker = nodes_los__forceShowMarkerToTime > info.curTime

  if nodes_los__visible && !nodes_los__showMarker && !nodes_los__showKillerMarker && nodes_los__considerInvisibleToTime < 0.
    nodes_los__considerInvisibleToTime = info.curTime + nodes_los__considerAsInvisibleTime

  let considerInvisible = nodes_los__considerInvisibleToTime > info.curTime

  if nodes_los__visible
    if !considerInvisible
      nodes_los__considerVisibleToTime = info.curTime + nodes_los__considerAsVisibleTime
  else
    nodes_los__considerInvisibleToTime = -1.

  nodes_los__showMarker = nodes_los__showKillerMarker || nodes_los__considerVisibleToTime >= info.curTime
  if (nodes_los__showMarker)
    nodes_los__considerMapVisibleToTime = info.curTime + nodes_los__considerMapAsVisibleTime
  nodes_los__showMapMarker = nodes_los__considerMapVisibleToTime >= info.curTime



[es(tag=gameClient, on_appear, REQUIRE=deadEntity)]
def reset_dead__human_los_cached_data(evt : Event;
                                      var nodes_los__visible : bool&;
                                      var nodes_los__showKillerMarker : bool&;
                                      var nodes_los__showMarker : bool&;
                                      var nodes_los__showMapMarker : bool&)
  nodes_los__visible = false
  nodes_los__showMapMarker = false
  nodes_los__showMarker = false
  nodes_los__showKillerMarker = false

[es(tag=gameClient, before=save_human_los_cached_data, REQUIRE=watchedByPlr)]
def apply_human_los_bots_data(info : UpdateStageInfoAct;
                              squad_member__squad : EntityId)
  query(squad_member__squad) <| $ [es] (squad__allMembersHumanTargetsSync : EidList)
    for soldierEid in squad__allMembersHumanTargetsSync
      query(soldierEid) <| $ [es] (nodes_los__considerMapAsVisibleTime : float;
                                   var nodes_los__considerMapVisibleToTime : float&)
        nodes_los__considerMapVisibleToTime = info.curTime + nodes_los__considerMapAsVisibleTime
