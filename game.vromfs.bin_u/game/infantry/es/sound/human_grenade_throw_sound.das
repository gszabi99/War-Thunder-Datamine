require ecs
require soundEvent
require PropsManager
require %game.events
require DaWeaponProps
require sound_utils.modules.sound_player_common

[es(tag=sound)]
def human_grenade_throw_sound(evt : EventOnGrenadeThrow;
                              grenade_thrower__soundPrefix = "infantry/";
                              is_watched_sound : bool;
                              transform : float3x4)
  let shellSoundProps = shell_sound_try_get_props(props_unpack_from_net(evt.gun_props_id))
  if shellSoundProps != null
    let path : string = is_watched_sound ? (*shellSoundProps).grenadeThrowHero : (*shellSoundProps).grenadeThrowEnemy
    if !empty(path)
      oneshot("{grenade_thrower__soundPrefix}{path}", transform[3])