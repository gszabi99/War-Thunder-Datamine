require ecs
require GamePhys
require %game.events

[es(on_appear)]
def ballistic_phys_init_es(evt : Event; var ballistic_phys__velocity : float3&; start_vel : float3)
  ballistic_phys__velocity = start_vel

[es(no_order)]
def ballistic_phys_es(info : ParallelUpdateFrameDelayed; var transform : float3x4; var ballistic_phys__velocity : float3&)
  let accel = float3(0.0, -gravity(), 0.0)
  transform[3] += ballistic_phys__velocity * info.dt + accel * info.dt * info.dt * 0.5
  ballistic_phys__velocity += accel * info.dt

