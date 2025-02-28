require ecs
require %game.events

[cpp_event(broadcast)]
struct UpdateAnimcharEvent
  curTime : float
  dt : float

[es(no_order)]
def animchar_es(info : UpdateStageInfoAct) // same name for save order of es
  broadcastEventImmediate([[UpdateAnimcharEvent curTime=info.curTime, dt=info.dt]]);
