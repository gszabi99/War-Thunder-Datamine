require ecs
require ecs.common
require ecs.safe
require soundEvent
require soundSystem
require DagorMath
require DagorSystem
require DaWeapons
require %game.events
require DagorConsole



def is_oneshot(gun : Gun; firing_mode : uint)
  return gun_getFiringMode(gun, int(firing_mode)).modeType != EFiringModeType.EFM_AUTOMATIC


def on_launch(launch_pos : float3;
              firing_mode : uint;
              gun : Gun;
              time_between_shots : float;
              var sound_event : SoundEvent&;
              time_between_shots_mad : float2;
              var shot_loop_timeout : float&;
              shot_path : string)
  if shot_path == ""
    return
  if is_oneshot(gun, firing_mode)
    oneshot(shot_path, launch_pos)
    sound_event |> abandon()
  else
    sound_event |> play(shot_path, launch_pos)

  shot_loop_timeout = (time_between_shots * time_between_shots_mad.x + time_between_shots_mad.y)

[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_shot(evt : EventShot;
                      gun : Gun;
                      var gun_sound__event : SoundEvent&;
                      var gun_sound__shotLoopTimeout : float&;
                      gun__timeBetweenShots : float = 0.;
                      gun_sound__netTimeBetweenShotsMad : float2;
                      gun_sound__shotPath : string;
                      gun_sound__isEnabled : bool)
  if !gun_sound__isEnabled
    return
  on_launch(evt.launchDesc.tm[3],
            evt.launchDesc.firingMode,
            gun,
            gun__timeBetweenShots,
            gun_sound__event,
            gun_sound__netTimeBetweenShotsMad, 
            gun_sound__shotLoopTimeout,
            gun_sound__shotPath)

[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_net_shot(evt : CmdNetShot;
                          gun : Gun;
                          var gun_sound__event : SoundEvent&;
                          var gun_sound__shotLoopTimeout : float&;
                          gun__timeBetweenShots : float = 0.;
                          gun_sound__netTimeBetweenShotsMad : float2;
                          gun_sound__shotPath : string;
                          gun_sound__isEnabled : bool)
  if !gun_sound__isEnabled
    return
  on_launch(evt.tm[3],
            evt.firingMode,
            gun,
            gun__timeBetweenShots,
            gun_sound__event,
            gun_sound__netTimeBetweenShotsMad,
            gun_sound__shotLoopTimeout,
            gun_sound__shotPath)

def is_shooting(gun_sound__shotLoopTimeout : float)
  return gun_sound__shotLoopTimeout > 0.

[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_update(info : ParallelUpdateFrameDelayed;
                     gun : Gun;
                     var gun_sound__deltaTime : float4&;
                     var gun_sound__shotLoopTimeout : float&;
                     var gun_sound__event : SoundEvent&;
                     gun_sound__isEnabled : bool)

  if !is_playing(gun_sound__event)
    return
  set_pos(gun_sound__event, gun.curState.gunTm[3])

  if !gun_sound__isEnabled || !is_shooting(gun_sound__shotLoopTimeout)
    gun_sound__event |> abandon()

  gun_sound__deltaTime.w = gun_sound__deltaTime.z
  gun_sound__deltaTime.z = gun_sound__deltaTime.y
  gun_sound__deltaTime.y = gun_sound__deltaTime.x
  gun_sound__deltaTime.x = info.dt
  gun_sound__shotLoopTimeout -= min(min(min(gun_sound__deltaTime.x, gun_sound__deltaTime.y), gun_sound__deltaTime.z), gun_sound__deltaTime.w)
