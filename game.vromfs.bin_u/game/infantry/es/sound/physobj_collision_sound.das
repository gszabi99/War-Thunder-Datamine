require ecs
require %game.events
require soundEvent
require soundSystem
require math.base
require DagorMath


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE_NOT=disableUpdate)]
def phys_obj_collision_sound(info : ParallelUpdateFrameDelayed;
                             proj__velocity : float3 = float3();
                             proj__prevVelocity : float3 = float3();
                             proj__omega : float3 = float3();
                             proj__prevOmega : float3 = float3();
                             proj__atTick : int = int();
                             proj__prevAtTick : int = int();
                             proj__timeStep : float = float();
                             phys_obj_collision_sound__enabled : bool;
                             phys_obj_collision_sound__path : string;
                             phys_obj_collision_sound__threshold : float2 const&;
                             phys_obj_collision_sound__omegaMul : float;
                             phys_obj_collision_sound__maxRange : float;
                             phys_obj_collision_sound__interval : float;
                             phys_obj_collision_sound__offset : float3;
                             var phys_obj_collision_sound__numSounds : int&;
                             var phys_obj_collision_sound__time : float&;
                             var phys_obj_collision_sound__maxImpulse : float&;
                             var phys_obj_collision_sound__event : SoundEvent&;
                             transform : float3x4)
  if !phys_obj_collision_sound__enabled || !should_play(transform[3], phys_obj_collision_sound__maxRange)
    if is_valid_handle_value(phys_obj_collision_sound__event)
      release(phys_obj_collision_sound__event)
      phys_obj_collision_sound__maxImpulse = 0.
    return

  phys_obj_collision_sound__time += info.dt
  if phys_obj_collision_sound__time < 0.
    return

  let dt = float(max(proj__atTick - proj__prevAtTick, 1)) * proj__timeStep
  var diffSq = length_sq((proj__omega - proj__prevOmega) * phys_obj_collision_sound__omegaMul)
  if length_sq(proj__velocity) < length_sq(proj__prevVelocity)
    diffSq = max(diffSq, length_sq(proj__velocity - proj__prevVelocity))
  if diffSq > square(phys_obj_collision_sound__threshold.x * dt)
    let impulse = safediv(sqrt(diffSq), dt)
    if !is_valid_handle_value(phys_obj_collision_sound__event) || phys_obj_collision_sound__time > phys_obj_collision_sound__interval
      if phys_obj_collision_sound__numSounds > 0
        --phys_obj_collision_sound__numSounds
        abandon(phys_obj_collision_sound__event)
        if sound_banks_is_master_preset_loaded()
          phys_obj_collision_sound__event |> play(phys_obj_collision_sound__path, transform[3] + phys_obj_collision_sound__offset)
        phys_obj_collision_sound__maxImpulse = 0.
        phys_obj_collision_sound__time = 0.

    phys_obj_collision_sound__maxImpulse = max(phys_obj_collision_sound__maxImpulse, impulse)

  if is_valid_handle_value(phys_obj_collision_sound__event)
    set_pos(phys_obj_collision_sound__event, transform[3] + phys_obj_collision_sound__offset)
    if phys_obj_collision_sound__threshold.y > phys_obj_collision_sound__threshold.x
      let f = cvt(phys_obj_collision_sound__maxImpulse, phys_obj_collision_sound__threshold.x, phys_obj_collision_sound__threshold.y, 0.0, 1.0)
      set_var_optional(phys_obj_collision_sound__event, "force", f)
    if phys_obj_collision_sound__time > phys_obj_collision_sound__interval
      abandon(phys_obj_collision_sound__event)
      phys_obj_collision_sound__maxImpulse = 0.
      phys_obj_collision_sound__time = 0.


[es(tag=sound, on_appear, REQUIRE=disableUpdate)]
def phys_obj_collision_sound_disable(evt : Event;
                                     var phys_obj_collision_sound__time : float&;
                                     var phys_obj_collision_sound__maxImpulse : float&;
                                     var phys_obj_collision_sound__event : SoundEvent&)
  phys_obj_collision_sound__time = 0.
  phys_obj_collision_sound__maxImpulse = 0.
  release(phys_obj_collision_sound__event)
