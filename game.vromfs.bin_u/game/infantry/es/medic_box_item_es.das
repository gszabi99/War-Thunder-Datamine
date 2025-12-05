require ecs
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.human_weap_common
require DngHuman
require AnimatedPhys
require AnimV20
require PhysVars


[es(REQUIRE=medBox)]
def medic_box_item_init_es(evt : EventEntityRecreated;
                           placeable_item__ownerTeam : int;
                           placeable_item__ownerEid : EntityId;
                           var team : int&;
                           var buildByPlayer : EntityId&)
  team = placeable_item__ownerTeam
  buildByPlayer = get_Eid(placeable_item__ownerEid, "squad_member__playerEid") ?? INVALID_ENTITY_ID


[es(tag=gameClient, REQUIRE=(isRendinstDestr, medBox))]
def medic_box_item_init_client_es(evt : EventEntityRecreated;
                                  var animchar_render__enabled : bool&)
  animchar_render__enabled = true


[es(tag=gameClient)]
def medic_box_item_switch_to_another_weap(evt : CmdFinishPlacePlaceableItem;
                                          human_weap__gunEids : EidList;
                                          var human_net_phys : HumanActor)
  if has(evt.itemEid, "medBox")
    switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)


[es(tag=server, REQUIRE=human_weap__currentGunEid)]
def medic_box_set_opened_on_place(evt : CmdFinishPlacePlaceableItem)
  query(evt.itemEid) <| $ [es] (var medic_box__isOpen : bool&)
    medic_box__isOpen = true


[es(tag=gameClient, on_appear, track=medic_box__isOpen, after=custom_animvars_on_create_es)]
def medic_box_item_apply_animvars_on_open(evt : Event;
                                          eid : EntityId;
                                          medic_box__openedLidAngle : float;
                                          medic_box__isOpen : bool;
                                          useful_box__useCount : int;
                                          var customAnimcharVarValues : FloatList)
  let medboxLidAngle = medic_box__isOpen && useful_box__useCount > 0 ? medic_box__openedLidAngle : 0.0
  for i in iter_range(customAnimcharVarValues)
    customAnimcharVarValues[i] = medboxLidAngle
  sendEvent(eid, EventApplyCustomAnimcharVars())


[es(tag=gameClient, track=useful_box__useCount, before=apply_amimvars_for_empty_box_es, REQUIRE=medBox)]
def medic_box_item_update_animvars_on_use(evt : Event;
                                          useful_box__useCount : int;
                                          var customAnimcharVarValues : FloatList)
  if useful_box__useCount <= 0
    for i in iter_range(customAnimcharVarValues)
      customAnimcharVarValues[i] = 0.


[es(tag=gameClient, REQUIRE=medBox, after=custom_animvars_applyer_es)]
def medic_box_update_animchar_es(evt : EventApplyCustomAnimcharVars;
                                 var animchar : AnimcharBaseComponent;
                                 var animchar_node_wtm : AnimcharNodesMat44;
                                 var animchar_render__root_pos : vec4f&;
                                 var phys_vars : PhysVars;
                                 var anim_phys : AnimatedPhys)
  anim_phys_update(anim_phys, animchar, phys_vars)
  animchar_act(animchar, 0., true)
  animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)
