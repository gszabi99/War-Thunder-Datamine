require ecs
require ecs.common
require DngHumanAnim
require %game.events
require WTCamera

[es(tag=render, REQUIRE_NOT=animchar__actOnDemand, before=(animchar_es, net_phys_update_es))]
def update_animchar_dtThreshold_es(info : ParallelUpdateFrameDelayed;
                                   animchar__visible : bool;
                                   var animchar__dtThreshold : float&;
                                   animchar__invisDtThreshold : float = 0.4;
                                   animchar__minDtThreshold : float = 0.0)
  animchar__dtThreshold = animchar__visible ? animchar__minDtThreshold : max(animchar__invisDtThreshold, animchar__minDtThreshold)


[es(tag=render, REQUIRE_NOT=attaches_list, before=update_animchar_visibility_es)]
def update_animchar_attaches_visibility_es(info : UpdateStageInfoAct;
                                           var animchar__visible : bool&;
                                           animchar_visbits : uint8;
                                           animchar__considerAsVisible : Tag const?;
                                           animchar_render__enabled : bool = true)
  if animchar__considerAsVisible != null 
    animchar__visible = true
    return

  if !animchar_render__enabled
    animchar__visible = false
    return

  animchar__visible = (int(animchar_visbits) & int(0x80)) != 0

[es(tag=render, before=(animchar_es, net_phys_update_es, update_animchar_dtThreshold_es))]
def update_animchar_visibility_es(info : UpdateStageInfoAct)
  let camPos = get_camera_orig_pos()
  query() <| $ [es] (var animchar__visible aka base_animchar__visible : bool&;
                     animchar_visbits : uint8;
                     animchar__considerAsVisible : Tag const?;
                     animchar_render__enabled : bool = true;
                     attaches_list : EidList;
                     transform : float3x4 const?;
                     animchar__considerAsVisibleDistance = -1.)
    if animchar__considerAsVisibleDistance > 0. && transform != null
      if length_sq((*transform)[3] - camPos) > animchar__considerAsVisibleDistance * animchar__considerAsVisibleDistance
        base_animchar__visible = false
        return

    if animchar__considerAsVisible != null 
      base_animchar__visible = true
      return

    if !animchar_render__enabled
      base_animchar__visible = false
      return

    base_animchar__visible = (int(animchar_visbits) & int(0x80)) != 0

    for attach in attaches_list
      if base_animchar__visible
        return
      query(attach) <| $ [es] (animchar__visible aka attach_animchar__visible : bool)
        base_animchar__visible ||= attach_animchar__visible
