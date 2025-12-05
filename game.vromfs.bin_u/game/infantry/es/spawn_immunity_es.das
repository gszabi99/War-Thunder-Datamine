require ecs
require app
require math
require math.base
require %game.events

[es]
def spawn_immunity_es(info : ParallelUpdateFrameDelayed;
                      var hitpoints__dmgMult : float&;
                      var spawn_immunity__timer : float&;
                      transform : float3x4;
                      spawn_immunity__posInited : bool;
                      spawn_immunity__initialPos : float3 const&;
                      spawn_immunity__immuneDistance : float = 5.0f)
  if spawn_immunity__timer < 0.0f || !spawn_immunity__posInited
    return

  spawn_immunity__timer -= info.dt

  if spawn_immunity__timer < 0.0f
    hitpoints__dmgMult = 1.0f
    return

  let distSq = distance_sq(spawn_immunity__initialPos, transform[3])
  if distSq < square(spawn_immunity__immuneDistance)
    hitpoints__dmgMult = 0.0f
  else
    hitpoints__dmgMult = 1.0f
    spawn_immunity__timer = -1.f

[es(on_event=(EventUnitRespawn, EventUnitSpawned), after=human_init_tm)]
def spawn_immunity_init_es(evt : Event;
                           var spawn_immunity__initialPos : float3&;
                           var spawn_immunity__posInited : bool&;
                           transform : float3x4)
  spawn_immunity__initialPos = transform[3]
  spawn_immunity__posInited = true

