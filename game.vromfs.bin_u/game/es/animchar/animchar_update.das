require ecs
require %game.events
require GeomNodeTree
require AnimV20
require DagorMath
require %dasGameLibs.math.base

[cpp_event(broadcast)]
struct UpdateAnimcharEvent
  curTime : float
  dt : float

[es(no_order, tag=gameClient)]
def animchar_es(info : ParallelUpdateFrameDelayed) 
  broadcastEventImmediate([[UpdateAnimcharEvent curTime=info.curTime, dt=info.dt]]);


[es(tag=(net, server))]
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

[es(tag=(net, server), on_event=ParallelUpdateFrameDelayed)]
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
