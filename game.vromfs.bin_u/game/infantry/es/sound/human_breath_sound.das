require ecs
require app
require HumanPhys
require DngHuman
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require math
require math.base
require DagorMath
require gameLibs.pufd_events.pufd_events
require strings


[es(tag=sound, track=(is_watched_sound, sound_preset__isLoaded, human_voice_effect__isActive), REQUIRE=(is_watched_sound, sound_preset__isLoaded, human_voice_effect__isActive))]
def human_breath_sound_reset(evt : Event;
                             human_breath_sound__baseBreathShortness = 0.;
                             var human_breath_sound__isBreath : bool&;
                             var sound_event_group : SoundEventGroup&;
                             var human_breath_sound__breathShortness : float&)
  human_breath_sound__isBreath = false
  human_breath_sound__breathShortness = human_breath_sound__baseBreathShortness
  release_sound(sound_event_group, sound_hash("breath"))
  release_sound(sound_event_group, sound_hash("inhale"))
  release_sound(sound_event_group, sound_hash("breathOut"))


[es(tag=sound, REQUIRE=watchedByPlr, after=(update_sound_group_using_animchar_es, animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def human_breath_sound_update(info : ParallelUpdateFrameDelayed;

                              human_net_phys : HumanActor;
                              human_net_phys__states : int;
                              human_net_phys__curMoveState : int;

                              human_voice_effect__isActive : bool = false;
                              sound_preset__isLoaded : bool;

                              var human_breath_sound__isBreath : bool&;
                              var human_breath_sound__prevBreathShortness : float&;
                              var human_breath_sound__goodBreathNextTime : float&;

                              human_breath_sound__inhaleThreshold : float;
                              human_breath_sound__breathoutThreshold : float;
                              human_breath_sound__breathShortnessStart : float;
                              human_breath_sound__goodBreathDelay : float;
                              human_breath_sound__jumpDelay : float;
                              human_breath_sound__loHealthRel : float;

                              var human_breath_sound__breathShortness : float&;
                              human_breath_sound__baseBreathShortness = 0.;

                              human__totalMaxStamina : float;
                              sound_tags : Object;
                              var sound_event_group : SoundEventGroup&;
                              @shared_comp human_voice_sound__path : Object;
                              @shared_comp human_voice_sound__descs : Object;
                              human_speech__locale = "";
                              transform : float3x4;
                              hitpoints__hp : float;
                              hitpoints__maxHp : float)

  if human_voice_effect__isActive || !sound_preset__isLoaded
    return

  let isOnGround = (human_net_phys__states & int(StateFlag.ST_ON_GROUND)) != 0
  let isSprint = human_net_phys__curMoveState == int(HUMoveState.EMS_SPRINT)
  let isLowHealth = hitpoints__hp < human_breath_sound__loHealthRel * hitpoints__maxHp
  let curStamina = cvt(human_net_phys.phys.currentState.stamina, 0., human__totalMaxStamina, 0., 1.)
  var breathShortness = isLowHealth ? 1. : (1. - curStamina)
  if isSprint || breathShortness > human_breath_sound__prevBreathShortness
    human_breath_sound__goodBreathNextTime = max(human_breath_sound__goodBreathNextTime, info.curTime + human_breath_sound__goodBreathDelay)

  if !isOnGround
    human_breath_sound__goodBreathNextTime = max(human_breath_sound__goodBreathNextTime, info.curTime + human_breath_sound__jumpDelay)

  var isPoorBreath = breathShortness >= human_breath_sound__breathShortnessStart && info.curTime < human_breath_sound__goodBreathNextTime

  if human_breath_sound__breathShortness > 0.
    breathShortness = max(human_breath_sound__breathShortness, breathShortness)
    isPoorBreath = true 
  human_breath_sound__breathShortness = human_breath_sound__baseBreathShortness

  if isPoorBreath || isLowHealth
    if !human_breath_sound__isBreath
      human_breath_sound__isBreath = true
      play_voice("sprintBreath", human_voice_sound__path, human_voice_sound__descs, sound_tags, true, transform[3], sound_hash("breath"), sound_event_group, human_speech__locale)
    let handle = get_sound(sound_event_group, sound_hash("breath"))
    set_var(handle, "Stamina", (1. - saturate(breathShortness)) * 100.)
  elif human_breath_sound__isBreath
    human_breath_sound__isBreath = false
    reject_sound(sound_event_group, sound_hash("breath"))
    if max(human_breath_sound__prevBreathShortness, breathShortness) > human_breath_sound__breathoutThreshold
      play_voice("sprintBreathOut", human_voice_sound__path, human_voice_sound__descs, sound_tags, true, transform[3], sound_hash("breathOut"), sound_event_group, human_speech__locale)

  if isPoorBreath && human_breath_sound__prevBreathShortness < human_breath_sound__inhaleThreshold && breathShortness >= human_breath_sound__inhaleThreshold
    play_voice("inhale", human_voice_sound__path, human_voice_sound__descs, sound_tags, true, transform[3], sound_hash("inhale"), sound_event_group, human_speech__locale)

  human_breath_sound__prevBreathShortness = breathShortness
