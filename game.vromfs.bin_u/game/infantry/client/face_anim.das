require ecs
require AnimV20
require PhysVars
require DagorSystem
require DagorRandom
require %appGame.infantry.es.animchar.attach_common


[es(on_appear, tag=gameClient)]
def headgen_init_random_anim_state(evt : Event;
                                   eid : EntityId;
                                   @shared_comp face_gen__randomAnimStateNames : StringList;
                                   var animchar : AnimcharBaseComponent&)
  let animStatesCount = length(face_gen__randomAnimStateNames)
  if animStatesCount <= 0
    return

  var seed = int(uint(eid))
  let randomAnimStateNum = _rnd_int(seed, 0, animStatesCount - 1)

  assume stateName = face_gen__randomAnimStateNames[randomAnimStateNum]
  let stateId = *animchar.animGraph |> anim_graph_getStateIdx("{stateName}")
  if stateId < 0
    logerr("Could not find state {stateName} for {eid}<{getEntityTemplateName(eid)}>")
    return

  *animchar.animGraph |> anim_graph_enqueueState(*animchar.animState, stateId)
  
  let actTime = 1.0 / 60.0
  animchar |> animchar_act(actTime, true)


[es(tag=gameClient, on_event=EventEntityDied)]
def face_anim_disable_on_death(evt : Event; attaches_list : EidList)
  for eid in attaches_list
    query(eid) <| $ [es] (face_anim__stateOnDeath : string; var animchar : AnimcharBaseComponent&)
      let stateId = *animchar.animGraph |> anim_graph_getStateIdx(face_anim__stateOnDeath)
      if stateId < 0
        logerr("Could not find face_anim__stateOnDeath state {face_anim__stateOnDeath} for {eid}<{getEntityTemplateName(eid)}>")
        return
      *animchar.animGraph |> anim_graph_enqueueState(*animchar.animState, stateId)


[es(tag=(server, gameClient), on_appear, track=animchar_attach__attachedTo, REQUIRE=isAttachableHead, REQUIRE_NOT=skeleton_attach__skipRemapNodes)]
def face_in_menu_skip_remap(evt : Event;
                            eid : EntityId;
                            animchar_attach__attachedTo : EntityId)
  let baseParentEid = find_base_attach_parent(animchar_attach__attachedTo)
  let parentInMenu = get_bool(baseParentEid, "menuChar") ?? false
  let headOverrideBipBones = get_bool(baseParentEid, "headAnimOverrideBipBones") ?? false
  if !parentInMenu
    return
  if !headOverrideBipBones
    return
  addSubTemplate(eid, "menu_head_skip_remap_nodes")


[es(tag=gameClient, on_appear, before=anim_phys_init_es, REQUIRE=isAttachableHead)]
def init_eye_direction_state(evt : Event;
                             attachable_head__eyesLookDistanceVarName : string;
                             attachable_head__eyesLookDistance : float3;
                             var attachable_head__eyesLookDistanceVarId : int&;
                             var phys_vars : PhysVars)
  attachable_head__eyesLookDistanceVarId = registerVar(phys_vars, attachable_head__eyesLookDistanceVarName, attachable_head__eyesLookDistance.x)


[es(tag=gameClient, track=attachable_head__eyesLookDistance)]
def update_eye_direction_state(evt : Event;
                               attachable_head__eyesLookDistance : float3;
                               attachable_head__eyesLookDistanceVarId : int;
                               var phys_vars : PhysVars)
  phys_vars |> setVar(attachable_head__eyesLookDistanceVarId, attachable_head__eyesLookDistance.x)
