require ecs
require math.base
require DagorMath
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require gameLibs.pufd_events.pufd_events


def vertical_speed(velocity : float3; grav_dir : float3) : float
  let v = dot(velocity, grav_dir)
  return max(v, -v)


def horizontal_speed_sq(velocity : float3; grav_dir : float3) : float
  return length_sq(velocity - dot(velocity, grav_dir) * grav_dir)


[es(tag=sound, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es, vehicle_sound_speed_update, vehicle_sound_phys_state_update_es), before=sound_end_update_es)]
def plane_tracks_sound(evt : ParallelUpdateFrameDelayed;
                       vehicle_sound_phys_state__isOnGround : bool;
                       is_watched_sound : bool;
                       sound_tags : Object;
                       @shared_comp plane_tracks_sound__path : Object;
                       plane_tracks_sound__speedThresholds : float2;
                       var plane_tracks_sound__event : SoundEvent&;
                       vehicle_sound_speed_state__linearVelocity : float3;
                       transform : float3x4;
                       vehicle_sound_occlusion__blob : SoundOcclusionBlob&)

  assume contact = vehicle_sound_phys_state__isOnGround
  assume velocity = vehicle_sound_speed_state__linearVelocity
  assume speedThresholds = plane_tracks_sound__speedThresholds
  assume event = plane_tracks_sound__event

  let speedSq = contact ? horizontal_speed_sq(velocity, transform[1]) : 0.
  let shouldPlay = speedSq > max(0., square(event.enabled ? speedThresholds.x : speedThresholds.y))

  if event.enabled != shouldPlay
    event.enabled = shouldPlay
    event |> abandon()
    if event.enabled
      event |> reset(play_path(plane_tracks_sound__path, sound_tags, is_watched_sound, transform[3], false))
      attach_to_blob(event, vehicle_sound_occlusion__blob)
  if event.enabled
    set_pos(event, transform[3])
    set_var(event, "speed", sqrt(speedSq))


[es(tag=sound, track=is_watched_sound, REQUIRE=is_watched_sound)]
def plane_tracks_sound_reset(evt : Event;
                             var plane_tracks_sound__event : SoundEvent&)
  plane_tracks_sound__event |> abandon_play_or()


[es(tag=sound, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es, vehicle_sound_speed_update, vehicle_sound_phys_state_update_es), before=sound_end_update_es)]
def plane_tracks_touchdown_sound(evt : ParallelUpdateFrameDelayed;
                                 vehicle_sound_phys_state__isOnGround : bool;
                                 vehicle_sound_phys_state__gravityDir : float3;
                                 is_watched_sound : bool;
                                 sound_tags : Object;
                                 @shared_comp plane_tracks_touchdown_sound__path : Object;
                                 plane_tracks_touchdown_sound__forceToParam : float2;
                                 var plane_tracks_touchdown_sound__contactAt : float&;
                                 plane_tracks_touchdown_sound__contactDuration : float;
                                 var plane_tracks_touchdown_sound__maxForce : float&;
                                 var plane_tracks_touchdown_sound__maxSpeedSq : float&;
                                 var plane_tracks_touchdown_sound__startAt : float&;
                                 var plane_tracks_touchdown_sound__shouldStart : bool&;
                                 var plane_tracks_touchdown_sound__cooldownOnAppear : float&;
                                 plane_tracks_touchdown_sound__startDelay : float;
                                 vehicle_sound_speed_state__linearVelocity : float3;
                                 transform : float3x4;
                                 vehicle_sound_occlusion__blob : SoundOcclusionBlob&)

  if vehicle_sound_phys_state__isOnGround
    plane_tracks_touchdown_sound__contactAt = evt.curTime

  let contact = plane_tracks_touchdown_sound__contactAt >= 0. && evt.curTime <= plane_tracks_touchdown_sound__contactAt + plane_tracks_touchdown_sound__contactDuration
  if contact
    if plane_tracks_touchdown_sound__shouldStart

      if plane_tracks_touchdown_sound__cooldownOnAppear <= 0.
        let gravDir = vehicle_sound_phys_state__gravityDir
        plane_tracks_touchdown_sound__maxForce = max(plane_tracks_touchdown_sound__maxForce, vertical_speed(vehicle_sound_speed_state__linearVelocity, gravDir))
        plane_tracks_touchdown_sound__maxSpeedSq = max(plane_tracks_touchdown_sound__maxSpeedSq, horizontal_speed_sq(vehicle_sound_speed_state__linearVelocity, gravDir))

      if plane_tracks_touchdown_sound__startAt < 0.
        plane_tracks_touchdown_sound__startAt = evt.curTime + plane_tracks_touchdown_sound__startDelay
      if evt.curTime >= plane_tracks_touchdown_sound__startAt
        if plane_tracks_touchdown_sound__maxForce > plane_tracks_touchdown_sound__forceToParam.x
          var handle = play_path(plane_tracks_touchdown_sound__path, sound_tags, is_watched_sound, transform[3], false)
          attach_to_blob(handle, vehicle_sound_occlusion__blob)
          handle |> set_var("force", cvt(plane_tracks_touchdown_sound__maxForce, plane_tracks_touchdown_sound__forceToParam.x, plane_tracks_touchdown_sound__forceToParam.y, 0., 1.))
          handle |> set_var("speed", sqrt(plane_tracks_touchdown_sound__maxSpeedSq))
          handle |> abandon()
        plane_tracks_touchdown_sound__shouldStart = false
  else
    plane_tracks_touchdown_sound__maxForce = 0.
    plane_tracks_touchdown_sound__maxSpeedSq = 0.
    plane_tracks_touchdown_sound__startAt = -1.
    plane_tracks_touchdown_sound__shouldStart = true

  if plane_tracks_touchdown_sound__cooldownOnAppear > 0.
    plane_tracks_touchdown_sound__cooldownOnAppear -= evt.dt
