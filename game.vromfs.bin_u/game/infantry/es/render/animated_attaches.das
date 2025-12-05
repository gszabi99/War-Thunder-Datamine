require ecs
require AnimV20
require math.base
require %game.events

[es(no_order)]
def animated_visible_attachments_act_animchar_es(info : ParallelUpdateFrameDelayed)
  find_query() <| $ [es] (transform aka camera_transform : float3x4;
                          camera__active : bool)
    if camera__active
      let camPos = camera_transform[3]
      query() <| $ [es(REQUIRE=animchar_attaches__animated, REQUIRE_NOT=(transform, animchar__actOnDemand))] (animchar__visible : bool;
                                                                                                              animchar__updatable : bool;
                                                                                                              animchar_render__root_pos : vec4f;
                                                                                                              animchar_attaches__disableAnimDistance = 5.f;
                                                                                                              var animchar : AnimcharBaseComponent)
        if !animchar__visible || !animchar__updatable
          return
        let attachRenderPos = animchar_render__root_pos.xyz
        if length_sq(attachRenderPos - camPos) < square(animchar_attaches__disableAnimDistance)
          animchar_act(animchar, info.dt, true)
      return true
    return false


[es(tag=(server, gameClient), REQUIRE=animchar_attaches__animated, on_appear, track=animchar_attach__attachedTo)]
def menu_attach_update_tag(evt : Event;
                           animchar_attach__attachedTo : EntityId;
                           eid : EntityId;
                           animchar__menuDisableUpdateDistance = 1000.f;
                           var animchar_attaches__disableAnimDistance : float?)
  let parentInMenu = get_bool(animchar_attach__attachedTo, "menuChar") ?? false
  if !parentInMenu
    return

  if animchar_attaches__disableAnimDistance != null
    *animchar_attaches__disableAnimDistance = animchar__menuDisableUpdateDistance
  else
    addSubTemplate(eid, "animated_attaches_update_disabler") <| $(var init)
      set(init, "animchar_attaches__disableAnimDistance", animchar__menuDisableUpdateDistance)
