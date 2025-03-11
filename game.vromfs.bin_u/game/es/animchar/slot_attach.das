require ecs
require DagorMath
require DagorSystem
require AnimV20
require GeomNodeTree
require %game.events
require ecs.common

[event(broadcast)]            
struct SlotAttachUpdateEvent  
  dt : float

def slot_attach_init_tms_impl(dt : float;
                              slot_attach__slotId : int;
                              slot_attach__attachedTo : EntityId;
                              var attachmentAnimChar : AnimcharBaseComponent&;
                              disableUpdate : Tag const?;
                              var animchar_node_wtm : AnimcharNodesMat44?;
                              var animchar_render__root_pos : vec4f?;
                              animchar__visible : bool = true;
                              slot_attach__calcAnim : bool = true;
                              slot_attach__rotTm : float3x4 const?)
  let rotTm = slot_attach__rotTm ?? float3x4()
  if slot_attach__slotId < 0 || !slot_attach__attachedTo
    return
  var tmpTm : mat44f
  query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                            animchar__actOnDemand : Tag const?;
                                            animchar__updatable : bool = true)
    if animchar__updatable || animchar__actOnDemand != null
      let slotNodeWtm = animchar_getSlotNodeWtm(animchar, slot_attach__slotId)
      let slotNodeTm = animchar_getAttachmentTm(animchar, slot_attach__slotId)
      if slotNodeWtm != null && slotNodeTm != null
        if slot_attach__rotTm != null
          tmpTm = mat44f((float3x4(*slotNodeWtm) * *slot_attach__rotTm) * float3x4(*slotNodeTm))
          var attachTm : float3x4;
          attachTm[0] = float3(tmpTm.col0.x, tmpTm.col0.y, tmpTm.col0.z)
          attachTm[1] = float3(tmpTm.col1.x, tmpTm.col1.y, tmpTm.col1.z)
          attachTm[2] = float3(tmpTm.col2.x, tmpTm.col2.y, tmpTm.col2.z)
          attachTm = attachTm * rotTm
          let pos = tmpTm.col3
          tmpTm = mat44f(attachTm)
          tmpTm.col3 = pos
        else
          tmpTm = mat44f(float3x4(*slotNodeWtm) * float3x4(*slotNodeTm))

      let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
      animchar_setTmWithOfs(attachmentAnimChar, tmpTm, wtmOfs)
      if animchar__visible
        animchar_act(attachmentAnimChar, dt,  disableUpdate == null && slot_attach__calcAnim)
      else
        animchar_recalc_wtm(attachmentAnimChar)
      if (animchar_node_wtm != null && animchar_render__root_pos != null)
        animchar_copy_nodes(attachmentAnimChar, *animchar_node_wtm, *animchar_render__root_pos);

[es(after=visual_offset_updater_es, before=binocular_update_cockpit)]
def slot_attach_init_tms_es(info : ParallelUpdateFrameDelayed)
  
  query() <| $ [es(REQUIRE_NOT=animchar)] (slot_attach__slotId : int;
                                           slot_attach__attachedTo : EntityId;
                                           var transform : float3x4)
    if slot_attach__slotId < 0 || !slot_attach__attachedTo
      return
    query(slot_attach__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent;
                                              animchar__actOnDemand : Tag const?;
                                              animchar__updatable : bool = true)
      if !animchar__updatable && animchar__actOnDemand != null
        return
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        transform = float3x4(tmpTm)
        transform[3] += wtmOfs
  broadcastEventImmediate([[SlotAttachUpdateEvent dt=info.dt]]); 

[es(REQUIRE_NOT=(menuPoseTm, slot_attach__secondaryUpdate), REQUIRE=(slot_attach, slot_attach__slotName), parallel_for=4)]
def slot_attach_first_priority_update_es(info : SlotAttachUpdateEvent;
                                         slot_attach__slotId : int;
                                         slot_attach__attachedTo : EntityId;
                                         var animchar : AnimcharBaseComponent;
                                         disableUpdate : Tag const?;
                                         var animchar_node_wtm : AnimcharNodesMat44?;
                                         var animchar_render__root_pos : vec4f?;
                                         animchar__visible : bool = true;
                                         slot_attach__calcAnim : bool = true;
                                         slot_attach__rotTm : float3x4 const?)
  slot_attach_init_tms_impl(info.dt, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim,
                            slot_attach__rotTm);


[es(after=slot_attach_first_priority_update_es, REQUIRE_NOT=menuPoseTm, REQUIRE=(slot_attach, slot_attach__secondaryUpdate, slot_attach__slotName))]
def slot_attach_secondary_priority_update_es(info : SlotAttachUpdateEvent;
                                             slot_attach__slotId : int;
                                             slot_attach__attachedTo : EntityId;
                                             var animchar : AnimcharBaseComponent;
                                             disableUpdate : Tag const?;
                                             var animchar_node_wtm : AnimcharNodesMat44?;
                                             var animchar_render__root_pos : vec4f?;
                                             animchar__visible : bool = true;
                                             slot_attach__calcAnim : bool = true;
                                             slot_attach__rotTm : float3x4 const?)
  slot_attach_init_tms_impl(info.dt, slot_attach__slotId, slot_attach__attachedTo, animchar, disableUpdate,
                            animchar_node_wtm, animchar_render__root_pos, animchar__visible, slot_attach__calcAnim,
                            slot_attach__rotTm);


def remove_from_eid_list(attach_eid : EntityId; var list : EidList&)
  let it = list |> find_index(attach_eid)
  if it >= 0
    list |> erase(it)

[es(on_appear)]
def slot_attach_on_load_es(evt : Event;
                           slot_attach__slotName : string;
                           var slot_attach__slotId : int&)
  if slot_attach__slotId < 0
    slot_attach__slotId = animchar_addSlotId(slot_attach__slotName)

def attach_to_parent_impl(eid : EntityId; slot_attach__attachedTo : EntityId; slot_attach__inAttachedList : EntityId) : bool
  var result = false
  query(slot_attach__attachedTo) <| $ [es] (var attaches_list : EidList&)
    result = true
    if slot_attach__inAttachedList != slot_attach__attachedTo
      var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
      if prevAttachedList != null
        remove_from_eid_list(eid, *prevAttachedList)

    if attaches_list |> find_index(eid) < 0
      attaches_list |> push(eid)
    if slot_attach__inAttachedList != slot_attach__attachedTo
      setOptional(eid, "slot_attach__inAttachedList", slot_attach__attachedTo)
    if !has(eid, "attachedToParent")
      addSubTemplate(eid, "attached_to_parent")
  return result

[es(tag=gameClient, on_event=CmdInitSlotAttach)]
def slot_attach_init_es(evt : Event;
                        eid : EntityId;
                        slot_attach__attachedTo : EntityId;
                        slot_attach__inAttachedList : EntityId)
  if !attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)
    logerr("Could not slot attach <{getEntityTemplateName(eid)}> to <{getEntityTemplateName(slot_attach__attachedTo)}>")

[es(tag=gameClient, no_order, REQUIRE_NOT=attachedToParent)]
def attach_to_parent_es(info : UpdateStageInfoAct;
                        eid : EntityId;
                        slot_attach__attachedTo : EntityId;
                        slot_attach__inAttachedList : EntityId)
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(on_appear)]
def attach_to_parent_on_create_es(evt : Event;
                                  eid : EntityId;
                                  slot_attach__attachedTo : EntityId;
                                  slot_attach__inAttachedList : EntityId)
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(REQUIRE=attaches_list, on_event=EventEntityCreated)]
def attach_on_parent_create_es(evt : Event;
                               eid aka attached_to_eid : EntityId)
  query() <| $ [es] (eid aka attach_eid : EntityId; slot_attach__attachedTo : EntityId; slot_attach__inAttachedList : EntityId)
    if attached_to_eid == slot_attach__attachedTo
      attach_to_parent_impl(attach_eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(REQUIRE=slot_attach__attachedTo, on_event=EventEntityDestroyed)]
def detach_from_parent_es(evt : Event;
                          eid : EntityId;
                          var slot_attach__inAttachedList : EntityId&)
  var attaches_list = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if attaches_list != null
    remove_from_eid_list(eid, *attaches_list)
  slot_attach__inAttachedList = INVALID_ENTITY_ID

[es(REQUIRE=slot_attach__attachedTo, on_event=EventComponentsDisappear)]
def slot_attached_to_disappear_es(evt : Event;
                                  eid : EntityId;
                                  slot_attach__inAttachedList : EntityId)
  var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if prevAttachedList != null
    remove_from_eid_list(eid, *prevAttachedList)
    removeSubTemplate(eid, "attached_to_parent")

[es(track=slot_attach__attachedTo)]
def track_attach_es(evt : Event;
                    eid : EntityId;
                    slot_attach__inAttachedList : EntityId;
                    slot_attach__attachedTo : EntityId)
  var prevAttachedList = getRW_ecs_EidList(slot_attach__inAttachedList, "attaches_list")
  if prevAttachedList != null
    remove_from_eid_list(eid, *prevAttachedList)
    removeSubTemplate(eid, "attached_to_parent")
  attach_to_parent_impl(eid, slot_attach__attachedTo, slot_attach__inAttachedList)

[es(on_event=CmdSlotDetach)]
def detach_anim_es(evt : Event; var slot_attach__attachedTo : EntityId&; var slot_attach__slotId : int&)
  slot_attach__attachedTo = INVALID_ENTITY_ID
  slot_attach__slotId = -1
