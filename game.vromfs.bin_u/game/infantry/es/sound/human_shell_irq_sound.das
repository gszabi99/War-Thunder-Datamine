require ecs
require soundEvent
require soundHash
require DaWeaponProps
require PropsManager
require common_sounds.modules.common_sounds_events
require %game.events
require sound_utils.modules.sound_player_common


[es(tag=sound)]
def human_shell_irq_sound(evt : CmdSoundIrq;
                          human_weap__grenadeThrower : EntityId;
                          grenade_thrower__soundPrefix = "infantry/";
                          is_watched_sound : bool;
                          transform : float3x4)
  if evt.irqType == sound_hash("grenadeActivate")
    query(human_weap__grenadeThrower) <| $ [es] (gun__curShellId : PropsId)
      let shellSoundProps = shell_sound_try_get_props(gun__curShellId)
      if shellSoundProps != null
        let path : string = is_watched_sound ? (*shellSoundProps).activateHero : (*shellSoundProps).activateEnemy
        if !empty(path)
          oneshot("{grenade_thrower__soundPrefix}{path}", transform[3])
