require ecs
require %game.events
require AnimV20

[cpp_event(broadcast)]
struct UpdateAnimcharEvent
  curTime : float
  dt : float

[es(after=before_animchar_update_sync, before=after_animchar_update_sync, tag=gameClient)] 
def animchar_es(info : ParallelUpdateFrameDelayed) 
  broadcastEventImmediate(UpdateAnimcharEvent(curTime = info.curTime, dt = info.dt))



[es(tag=(net, server), REQUIRE=animchar__onlyServerUpdate, REQUIRE_NOT=animchar__actOnDemand)]
def animchar_server_update_es(info : ParallelUpdateFrameDelayed;
                              transform : float3x4;
                              animchar__updatable : bool;
                              var animchar : AnimcharBaseComponent;
                              animchar__turnDir = false)
  if !animchar__updatable
    return

  var resultTm = transform
  if animchar__turnDir
    resultTm[0] = transform[2]
    resultTm[2] = -transform[0]
  animchar_set_tm(animchar, resultTm, true)
  animchar |> animchar_recalc_wtm()

[es(tag=(net, server), REQUIRE=animchar__onlyServerUpdate, REQUIRE_NOT=animchar__actOnDemand, on_event=ParallelUpdateFrameDelayed)]
def animchar_server_full_update_es(evt : Event;
                                   transform : float3x4;
                                   animchar__updatable : bool;
                                   human_anim__previousHeight : float;
                                   human_anim__diffToUpdateHeight = 0.2;
                                   var animchar : AnimcharBaseComponent;
                                   var human_anim__lastUpdatedDedHeight : float&;
                                   animchar__turnDir = false)
  if !animchar__updatable
    return
  if abs(human_anim__previousHeight - human_anim__lastUpdatedDedHeight) > human_anim__diffToUpdateHeight
    human_anim__lastUpdatedDedHeight = human_anim__previousHeight
    var resultTm = transform
    if animchar__turnDir
      resultTm[0] = transform[2]
      resultTm[2] = -transform[0]

    animchar_set_tm(animchar, resultTm, true)
    animchar_act(animchar, 1., true)


[es(tag=hangar, after=before_animchar_update_sync, before=after_animchar_update_sync, REQUIRE=(animchar__actOnDemand, hangar_weapon_placer))]
def menu_item_animchar_act(info : ParallelUpdateFrameDelayed;
                           eid aka gun_eid : EntityId;
                           transform : float3x4;
                           var animchar aka gun_animchar : AnimcharBaseComponent;
                           var animchar_node_wtm : AnimcharNodesMat44;
                           var animchar_render__root_pos : vec4f&;
                           animchar__turnDir = false)
  var resultTm = transform
  if animchar__turnDir
    resultTm[0] = transform[2]
    resultTm[2] = -transform[0]
  var attachmentIds : array<int>
  query() <| $ [es] (eid aka mod_eid : EntityId;
                     var animchar aka mod_animchar : AnimcharBaseComponent;
                     slot_attach__slotId : int;
                     animchar_attach__attachedTo : EntityId)
    if slot_attach__slotId >= 0 && animchar_attach__attachedTo == gun_eid
      attachmentIds.push(gun_animchar |> animchar_setAttachedChar(slot_attach__slotId, uint(mod_eid), unsafe(addr(mod_animchar)), false))

  animchar_set_tm(gun_animchar, resultTm, true)
  gun_animchar |> animchar_act(0.f, true)
  gun_animchar |> animchar_copy_nodes(animchar_node_wtm, animchar_render__root_pos)

  for attachmentId in attachmentIds
    if attachmentId >= 0
      gun_animchar |> animchar_releaseAttachment(attachmentId)
