require ecs
require math.base
require DagorMath
require vehicle
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def ground_vehicle_brakes_sound(info : ParallelUpdateFrameDelayed;
                                vehicle_net_phys : VehiclePhysActor;
                                vehicle_sound_phys_state__isOnGround : bool;
                                var ground_vehicle_brakes_sound__brakes : float&;
                                var ground_vehicle_brakes_sound__event : SoundEvent&;
                                ground_vehicle_brakes_sound__brakesStart : float;
                                ground_vehicle_brakes_sound__speedFadeInOut : float2;
                                is_watched_sound : bool;
                                @shared_comp ground_vehicle_brakes_sound__path : Object;
                                sound_tags : Object;
                                transform : float3x4)

  assume currentState = vehicle_net_phys.phys.currentState
  assume event = ground_vehicle_brakes_sound__event

  let speed = abs(dot(float3(currentState.velocity), transform[0]))
  let speedFadeIn = cvt(speed, 0., ground_vehicle_brakes_sound__speedFadeInOut.x, 0., 1.)
  let speedFadeOut = cvt(speed, ground_vehicle_brakes_sound__speedFadeInOut.x, ground_vehicle_brakes_sound__speedFadeInOut.y, 1., 0.)

  let brakes = vehicle_sound_phys_state__isOnGround ? saturate(max(abs(currentState.leftSteeringBrake), abs(currentState.rightSteeringBrake))) : 0.
  ground_vehicle_brakes_sound__brakes = max(max(ground_vehicle_brakes_sound__brakes - info.dt, 0.), brakes * speedFadeOut * speedFadeIn)

  let shouldPlay = ground_vehicle_brakes_sound__brakes > ground_vehicle_brakes_sound__brakesStart && is_watched_sound

  var path = ""
  if !shouldPlay || get_option_path(ground_vehicle_brakes_sound__path, sound_tags, is_watched_sound, path)
    if event |> play_or_abandon(path, transform[3], shouldPlay)
      set_var(event, "brakes", ground_vehicle_brakes_sound__brakes)
