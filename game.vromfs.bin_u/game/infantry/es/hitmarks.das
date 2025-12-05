require ecs
require %appGame.wt_events
require GeomNodeTree
require AnimV20


[es(tag=gameClient, on_appear)]
def human_hitmark_init_es(evt : Event; var human__hitmarkEid : EntityId&)
  human__hitmarkEid = createEntity("hud_human_hitmark")

[es(tag=gameClient, on_disappear)]
def human_hitmark_destroy_es(evt : Event; human__hitmarkEid : EntityId)
  destroyEntity(human__hitmarkEid)

def private set_hitmark_position(human__hitmarkEid : EntityId; position : float3)
  query(human__hitmarkEid) <| $ [es] (var ui__node_pos : float3&)
    ui__node_pos = position

[es(tag=gameClient, on_appear)]
def gun_hitmark_position_init_es(evt : Event;
                                 animchar : AnimcharBaseComponent;
                                 gun_scope_hitmark__NodeName : string;
                                 var gun_scope_hitmark__nodeId : int&)
  gun_scope_hitmark__nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_scope_hitmark__NodeName)

[es(tag=gameClient, no_order, REQUIRE=hero)]
def human_hitmark_position_update_es(evt : UpdateStageInfoAct;
                                     camera__aimPosition : float;
                                     human__hitmarkEid : EntityId;
                                     human_weap__currentGunEid : EntityId)
  if camera__aimPosition < 1.0
    set_hitmark_position(human__hitmarkEid, float3())
  else
    
    
    let isScopeFound = find_query() <| $ [es(REQUIRE=gunScope)] (eid aka scope_eid : EntityId; animchar_attach__attachedTo : EntityId)
      if animchar_attach__attachedTo == human_weap__currentGunEid
        query(scope_eid) <| $ [es] (gun_scope_hitmark__nodeId : int; animchar : AnimcharBaseComponent)
          if gun_scope_hitmark__nodeId >= 0
            let pos = *animchar.nodeTree |> geomtree_getNodeWpos(gun_scope_hitmark__nodeId)
            set_hitmark_position(human__hitmarkEid, pos)
        return true
      return false

    
    if !isScopeFound
      query(human_weap__currentGunEid) <| $ [es] (weapon_frontsight_node__nodeIdx : int; animchar : AnimcharBaseComponent)
        if weapon_frontsight_node__nodeIdx >= 0
          let pos = *animchar.nodeTree |> geomtree_getNodeWpos(weapon_frontsight_node__nodeIdx)
          set_hitmark_position(human__hitmarkEid, pos)
