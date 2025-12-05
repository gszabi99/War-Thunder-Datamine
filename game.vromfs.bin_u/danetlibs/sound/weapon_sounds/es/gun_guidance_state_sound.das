require ecs
require app 
require sound_utils.modules.sound_player_common
require soundEvent
require soundSystem
require GuidanceLock
require DagorSystem


def gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath : string;
                                   gun_guidance_state_sound__activePath : string;
                                   gun_guidance_state_sound__trackingPath : string;
                                   var gun_guidance_state_sound__event : SoundEvent&;
                                   var gun_guidance_state_sound__guidanceState : int&;
                                   var gun_guidance_state_sound__isWatched : bool&;
                                   guidance_state : int;
                                   is_watched_sound : bool)

  if gun_guidance_state_sound__guidanceState != guidance_state || gun_guidance_state_sound__isWatched != is_watched_sound
    gun_guidance_state_sound__guidanceState = guidance_state
    gun_guidance_state_sound__isWatched = is_watched_sound
    abandon(gun_guidance_state_sound__event)

    if guidance_state == int(GuidanceLockState.RESULT_WARMING_UP)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__warmingUpPath, is_watched_sound), get_listener_pos()))
    elif guidance_state == int(GuidanceLockState.RESULT_LOCKING)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__activePath, is_watched_sound), get_listener_pos()))
    elif guidance_state == int(GuidanceLockState.RESULT_TRACKING)
      gun_guidance_state_sound__event |> reset(soundEvent::play(apply_watched_prefix(gun_guidance_state_sound__trackingPath, is_watched_sound), get_listener_pos()))





















[es(tag=sound, track=(gun__guidanceState, gun__owner), on_event=EventOnMasterSoundPresetLoaded)]
def gun_guidance_state_sound_track_gun(evt : Event;
                                       eid aka gun_eid : EntityId;
                                       gun_guidance_state_sound__warmingUpPath : string;
                                       gun_guidance_state_sound__activePath : string;
                                       gun_guidance_state_sound__trackingPath : string;
                                       var gun_guidance_state_sound__event : SoundEvent&;
                                       var gun_guidance_state_sound__guidanceState : int&;
                                       var gun_guidance_state_sound__isWatched : bool&;
                                       gun__guidanceState : int;
                                       gun__owner : EntityId)

  var guidanceState = int(GuidanceLockState.RESULT_INVALID)
  var isWatchedSound = false

  if sound_banks_is_master_preset_loaded()
    query(gun__owner) <| $ [es] (is_watched_sound, human_net_phys__isAiming : bool;
                                 human_weap__gunEids : EidList;
                                 human_weap__curGunSlot : int;
                                 human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
      let selectedGunEid = human_weap__curGunSlot >= 0 && !human_attached_gun__attachedGunEid ? human_weap__gunEids[human_weap__curGunSlot] : human_attached_gun__attachedGunEid
      if selectedGunEid == gun_eid && human_net_phys__isAiming
        guidanceState = gun__guidanceState
        isWatchedSound = is_watched_sound

  gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath,
                                 gun_guidance_state_sound__activePath,
                                 gun_guidance_state_sound__trackingPath,
                                 gun_guidance_state_sound__event,
                                 gun_guidance_state_sound__guidanceState,
                                 gun_guidance_state_sound__isWatched,
                                 guidanceState,
                                 isWatchedSound)



[es(tag=sound, on_appear, track=(is_watched_sound, human_net_phys__isAiming, human_weap__curGunSlot, human_weap__gunEids, human_attached_gun__attachedGunEid))]
def gun_guidance_state_sound_track_human(evt : Event;
                                         eid aka human_eid : EntityId;
                                         is_watched_sound, human_net_phys__isAiming : bool;
                                         human_weap__gunEids : EidList;
                                         human_weap__curGunSlot : int;
                                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  if !sound_banks_is_master_preset_loaded()
    return
  let selectedGunEid = human_weap__curGunSlot >= 0 && !human_attached_gun__attachedGunEid ? human_weap__gunEids[human_weap__curGunSlot] : human_attached_gun__attachedGunEid

  query() <| $ [es] (eid aka gun_eid : EntityId;
                     gun_guidance_state_sound__warmingUpPath : string;
                     gun_guidance_state_sound__activePath : string;
                     gun_guidance_state_sound__trackingPath : string;
                     var gun_guidance_state_sound__event : SoundEvent&;
                     var gun_guidance_state_sound__guidanceState : int&;
                     var gun_guidance_state_sound__isWatched : bool&;
                     gun__guidanceState : int;
                     gun__owner : EntityId)

    if gun__owner == human_eid

      gun_guidance_state_sound_track(gun_guidance_state_sound__warmingUpPath,
                                     gun_guidance_state_sound__activePath,
                                     gun_guidance_state_sound__trackingPath,
                                     gun_guidance_state_sound__event,
                                     gun_guidance_state_sound__guidanceState,
                                     gun_guidance_state_sound__isWatched,
                                     selectedGunEid == gun_eid && human_net_phys__isAiming ? gun__guidanceState : int(GuidanceLockState.RESULT_INVALID),
                                     is_watched_sound)

