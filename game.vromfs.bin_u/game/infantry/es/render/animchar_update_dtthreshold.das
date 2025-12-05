require ecs
require ecs.common
require DngHumanAnim
require %game.events
require WTCamera
require AnimV20


[es(tag=render, before=(animchar_es, net_phys_update_es), parallel_for=64)]
def update_animchar_dtThreshold_es(info : ParallelUpdateFrameDelayed;
                                   animchar__visible : bool;
                                   var animchar__dtThreshold : float&;
                                   animchar__invisDtThreshold : float = 0.4;
                                   animchar__minDtThreshold : float = 0.0;
                                   animchar__actWhenInvisible = false)
  animchar__dtThreshold = animchar__visible || animchar__actWhenInvisible ? animchar__minDtThreshold : max(animchar__invisDtThreshold, animchar__minDtThreshold)


[es(tag=render, before=(animchar_es, net_phys_update_es, update_animchar_dtThreshold_es), parallel_for=64)]
def update_animchar_visibility_es(info : UpdateStageInfoAct;
                                  var animchar__visible : bool&;
                                  var animchar__mainVisible : bool?;
                                  animchar__considerAsVisible : Tag const?;
                                  animchar_visbits : animchar_visbits_t;
                                  animchar_render__enabled : bool = true;
                                  transform : float3x4 const?;
                                  animchar__considerAsVisibleDistance = -1.)
  if !animchar_render__enabled
    animchar__visible = false
    return

  if animchar__considerAsVisible != null
    animchar__visible = true
    return

  if animchar__considerAsVisibleDistance > 0. && transform != null
    let camPos = get_camera_orig_pos()
    if length_sq((*transform)[3] - camPos) > animchar__considerAsVisibleDistance * animchar__considerAsVisibleDistance
      animchar__visible = false
      return

  animchar__visible = (int(animchar_visbits) & int(AnimcharVisbits.VISFLG_MAIN_CAMERA_RENDERED)) != 0
  if animchar__mainVisible != null
    *animchar__mainVisible = ((int(animchar_visbits) & 8 ) != 0)
