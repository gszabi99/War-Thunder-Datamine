require ecs
require app
require math
require DagorMath


def calc_fire_size(time : float; start_time : float; spread_time : float; full_force_time : float; fade_time : float; scale : float) : float
  let maxSpreadTime = start_time + spread_time
  if time < maxSpreadTime
    return scale * cvt(time, start_time, maxSpreadTime, 0.0, 1.0)
  let fadeStartTime = maxSpreadTime + full_force_time
  if time < fadeStartTime
    return scale
  return scale * cvt(time, fadeStartTime, fadeStartTime + fade_time, 1.0, 0.0)

[es(tag=server, on_appear)]
def fire_source_init_start_time(evt : Event; var fire_source__startTime : float&)
  fire_source__startTime = get_sync_time()

[es(tag=server, no_order)]
def fire_source_progress(info : UpdateStageInfoAct;
                         eid : EntityId;
                         var sphere_zone__radius : float&;
                         fire_source__startTime : float;
                         fire_source__fullForceTime : float;
                         fire_source__spreadTime : float = 0.0;
                         fire_source__fadeTime : float = 0.0;
                         dmgzone__maxRadius : float = 1.0)
  let duration = fire_source__spreadTime + fire_source__fullForceTime + fire_source__fadeTime
  let time = info.curTime
  if time > fire_source__startTime + duration
    destroyEntity(eid)
  else
    sphere_zone__radius = calc_fire_size(time, fire_source__startTime,
        fire_source__spreadTime, fire_source__fullForceTime, fire_source__fadeTime, dmgzone__maxRadius)

[es(tag=render, no_order)]
def fire_source_effect(info : UpdateStageInfoAct;
                       var effect__scale : float&;
                       fire_source__startTime : float;
                       fire_source__effectScale : float;
                       fire_source__fullForceTime : float;
                       fire_source__spreadTime : float = 0.0;
                       fire_source__fadeTime : float = 0.0;
                       dmgzone__maxRadius : float = 1.0;
                       fire_source__effectMinScale : float = 0.0)
  let zone_size = calc_fire_size(info.curTime, fire_source__startTime,
      fire_source__spreadTime, fire_source__fullForceTime, fire_source__fadeTime, dmgzone__maxRadius)
  effect__scale = max(fire_source__effectMinScale, zone_size * fire_source__effectScale)
