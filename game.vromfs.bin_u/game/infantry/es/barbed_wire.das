require app
require ecs
require PhysMat
require PhysVars
require AnimV20
require AnimatedPhys

require %appGame.wt_events


[es(tag=server, on_appear)]
def barbwire_mat_damage_init(evt : Event; barbwire_damage__matName : string; var barbwire_damage__matId : int&)
  barbwire_damage__matId = get_material_id(barbwire_damage__matName)

[es(on_appear, before=anim_phys_init_es)]
def init_barbedwire_state_id(evt : Event;
                             var barbwire_anim__stateVarId : int&;
                             var phys_vars : PhysVars&)
  barbwire_anim__stateVarId = registerVar(phys_vars, "barbed_wire_state", 0.f)

[es(tag=server, REQUIRE=human_weap__currentGunEid)]
def unroll_barbedwire_on_place_server(evt : CmdFinishPlacePlaceableItem)
  query(evt.itemEid) <| $ [es] (var barbwire_anim__stateVarValue : float&)
    barbwire_anim__stateVarValue = 1.0

[es(tag=gameClient, track=barbwire_anim__stateVarValue)]
def unroll_barbedwire_on_place_client(evt : Event;
                                      placeable_item__deployDuration : float;
                                      barbwire_anim__stateVarValue : float;
                                      barbwire_anim__stateVarId : int;
                                      var placeable_item__deployEndTime : float&;
                                      var phys_vars : PhysVars&)
  placeable_item__deployEndTime = get_sync_time() + placeable_item__deployDuration
  phys_vars |> setVar(barbwire_anim__stateVarId, barbwire_anim__stateVarValue)



[es(tag=render, no_order, REQUIRE=barbwire)]
def unroll_barbedwire_on_place_update(info : UpdateStageInfoAct;
                                      placeable_item__deployEndTime : float;
                                      var animchar : AnimcharBaseComponent;
                                      var animchar_node_wtm : AnimcharNodesMat44;
                                      var animchar_render__root_pos : vec4f&;
                                      var phys_vars : PhysVars;
                                      var anim_phys : AnimatedPhys)
  if info.curTime > placeable_item__deployEndTime
    return
  anim_phys_update(anim_phys, animchar, phys_vars)
  animchar_act(animchar, info.dt, true)
  animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)
