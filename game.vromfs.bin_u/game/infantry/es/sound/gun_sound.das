require ecs
require ecs.common
require ecs.safe
require soundEvent
require soundSystem
require soundHash
require DagorMath
require DagorSystem
require DaWeapons
require %game.events

require %appGame.wt_events
require DagorConsole
require %appGame.infantry.es.sound.gun_sound_common
require sound_utils.modules.sound_player_common
require app 
require Sound

let GRAIN_TTL_HERO = 5.
let GRAIN_TTL = 4.

def try_shot_loop(var sound_event : SoundEvent&; turret_owner : EntityId; pos : float3; shot_path, tags : Object; is_watched : bool; prefix = "")
  release(sound_event)
  let path = "{prefix}{make_gun_shot_sound_path_str(shot_path, tags, is_watched, false)}"
  var hasGroup = false
  query(turret_owner) <| $ [es] (var gun_owner_sound_event_group : SoundEventGroup&)
    hasGroup = true
    if !has_sound(gun_owner_sound_event_group, path, "")
      sound_event |> reset(sound_player_common::play_name_path_impl(path, "", pos, false))
      if get_num_sounds(gun_owner_sound_event_group) < get_max_capacity(gun_owner_sound_event_group)
        add_sound(gun_owner_sound_event_group, sound_hash(""), float3(0., 0., 0.), sound_event, 0)
      else
        sound_debug("gun_owner_sound_event_group max capacity reached ({get_num_sounds(gun_owner_sound_event_group)}), sound will flange")
  if !hasGroup
    sound_event |> reset(sound_player_common::play_name_path_impl(path, "", pos, false))


def is_oneshot(gun : Gun; firing_mode : uint)
  return gun_getFiringMode(gun, int(firing_mode)).modeType != EFiringModeType.EFM_AUTOMATIC


def abandon_shot_loop(var sound_event : SoundEvent&; turret__owner : EntityId)
  if is_valid_handle_value(sound_event)
    query(turret__owner) <| $ [es] (var gun_owner_sound_event_group : SoundEventGroup&)
      remove_sound(gun_owner_sound_event_group, sound_event)
    abandon(sound_event)


def get_smid_from_gun_owner(gun__owner : EntityId) : int
  var smid = 0
  query(gun__owner) <| $ [es] (human_steps_sound__smid : int)
    smid = human_steps_sound__smid
  return smid


def on_launch(launch_pos : float3;
              firing_mode : uint;
              gun : Gun;
              is_watched : bool;
              time_between_shots : float;
              force_oneshot, force_oneshot_enemy : bool;
              start_loop_with_n_oneshots : int;
              var num_shots_in_loop : int&;
              var sound_event : SoundEvent&;
              time_between_shots_mad : float2;
              var shot_loop_timeout : float&;
              gun__owner : EntityId;
              turret__owner : EntityId;
              shot_path : Object;
              tags : Object;
              gun_sound__prefix : string)

  if sound_event.enabled != is_watched
    abandon_shot_loop(sound_event, turret__owner)
    sound_event.enabled = is_watched

  let forceOneshot = is_watched ? force_oneshot : force_oneshot_enemy
  var isOneshot = forceOneshot || is_oneshot(gun, firing_mode)
  var isLoop = false

  
  if !isOneshot && is_watched && start_loop_with_n_oneshots > 0
    if num_shots_in_loop == -1
      num_shots_in_loop = start_loop_with_n_oneshots
    if num_shots_in_loop > 0
      --num_shots_in_loop
      isOneshot = true

  if isOneshot
    abandon_shot_loop(sound_event, turret__owner)
    let path = "{gun_sound__prefix}{make_gun_shot_sound_path_str(shot_path, tags, is_watched, true)}"
    var handle = sound_player_common::play_name_path(path, "", launch_pos, false)
    if is_watched
      set_var_optional(handle, "mat", float(get_smid_from_gun_owner(gun__owner)))
    abandon(handle)
  else
    isLoop = is_valid_handle_value(sound_event)
    if !is_valid_handle_value(sound_event)
      try_shot_loop(sound_event, turret__owner, launch_pos, shot_path, tags, is_watched, gun_sound__prefix)
    if is_valid_handle_value(sound_event)
      set_pos(sound_event, launch_pos)
      if is_watched
        set_var_optional(sound_event, "mat", float(get_smid_from_gun_owner(gun__owner)))

  
  shot_loop_timeout = (time_between_shots * time_between_shots_mad.x + time_between_shots_mad.y)


[es(tag=sound, on_appear)]
def gun_sound_on_appear(evt : Event;
                        sound_tags : Object;
                        var gun_sound__hasGrain : bool&;
                        gun_sound__prefix : string;
                        @shared_comp gun_sound__shotPath : Object)
  let path = "{gun_sound__prefix}{make_gun_shot_sound_grain_path_str(gun_sound__shotPath, sound_tags, true)}"
  gun_sound__hasGrain = has(path, "")


def on_shot_grain(launch_pos : float3;
                  is_oneshot : bool;
                  is_watched : bool;
                  var sound_event : SoundEvent&;
                  var grain_TTL : float&;
                  gun__owner : EntityId;
                  turret__owner : EntityId;
                  time_between_shots : float;
                  time_between_shots_mad : float2;
                  var shot_loop_timeout : float&;
                  shot_path : Object;
                  tags : Object;
                  gun_sound__prefix : string)
  if sound_event.enabled != is_watched
    abandon_shot_loop(sound_event, turret__owner)
    sound_event.enabled = is_watched

  grain_TTL = is_watched ? GRAIN_TTL_HERO : GRAIN_TTL
  if !is_valid_handle_value(sound_event)
    let path = "{gun_sound__prefix}{make_gun_shot_sound_grain_path_str(shot_path, tags, is_watched)}"
    sound_event |> play(path)
    sound_event.abandonOnReset = true

  if is_valid_handle_value(sound_event)
    set_pos(sound_event, launch_pos)
    if is_watched
      set_var_optional(sound_event, "mat", float(get_smid_from_gun_owner(gun__owner)))

  set_var_optional(sound_event, "on_shot", 1.)
  shot_loop_timeout = (time_between_shots * time_between_shots_mad.x + time_between_shots_mad.y)

  if !is_watched || is_oneshot
    shot_loop_timeout = time_between_shots / 3.

[es(tag=sound, on_event=EventStopShoot, REQUIRE=gunSound)]
def gun_sound_on_stop_shot(evt : Event;
                           gun_sound__event : SoundEvent;
                           gun_sound__hasGrain : bool)
  if gun_sound__hasGrain && is_valid_handle_value(gun_sound__event)
    set_var_optional(gun_sound__event, "on_shot", 0.)


def gun_sound_on_shot(pos : float3;
                      firing_mode : uint;
                      gun : Gun;
                      gun__timeBetweenShots : float = 0.;
                      is_watched : bool;
                      gun_sound__hasGrain : bool;
                      gun_sound__forceOneshot : bool;
                      gun_sound__forceOneshotEnemy : bool;
                      gun_sound__startLoopWithNOneshots : int;
                      var gun_sound__numShotsInLoop : int&;
                      var gun_sound__event : SoundEvent&;
                      gun_sound__playerTimeBetweenShotsMad : float2;
                      var gun_sound__shotLoopTimeout : float&;
                      var gun_sound__grainTTL : float&;
                      gun__owner : EntityId;
                      turret__owner = INVALID_ENTITY_ID;
                      @shared_comp gun_sound__shotPath : Object;
                      sound_tags : Object;
                      gun_sound__prefix = "")
  if sound_banks_is_master_preset_loaded()
    if gun_sound__hasGrain
      on_shot_grain(pos,
                    is_oneshot(gun, firing_mode),
                    is_watched,
                    gun_sound__event,
                    gun_sound__grainTTL,
                    gun__owner,
                    turret__owner,
                    gun__timeBetweenShots,
                    gun_sound__playerTimeBetweenShotsMad,
                    gun_sound__shotLoopTimeout,
                    gun_sound__shotPath,
                    sound_tags,
                    gun_sound__prefix)
    else
      on_launch(pos,
                firing_mode,
                gun,
                is_watched,
                gun__timeBetweenShots,
                gun_sound__forceOneshot,
                gun_sound__forceOneshotEnemy,
                gun_sound__startLoopWithNOneshots,
                gun_sound__numShotsInLoop,
                gun_sound__event,
                gun_sound__playerTimeBetweenShotsMad,
                gun_sound__shotLoopTimeout,
                gun__owner,
                turret__owner,
                gun_sound__shotPath,
                sound_tags,
                gun_sound__prefix)


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_net_shot(evt : CmdNetShot;
                          gun : Gun;
                          gun__timeBetweenShots : float = 0.;
                          gun_sound__hasGrain : bool;
                          gun_sound__forceOneshot : bool;
                          var gun_sound__shootHistory : Point4List&;
                          var gun_sound__lastFiringMode : int&;
                          gun_sound__forceOneshotEnemy : bool;
                          gun_sound__startLoopWithNOneshots : int;
                          var gun_sound__numShotsInLoop : int&;
                          var gun_sound__event : SoundEvent&;
                          gun_sound__playerTimeBetweenShotsMad : float2;
                          var gun_sound__shotLoopTimeout : float&;
                          var gun_sound__grainTTL : float&;
                          gun__owner : EntityId;
                          turret__owner = INVALID_ENTITY_ID;
                          @shared_comp gun_sound__shotPath : Object;
                          sound_tags : Object;
                          gun_sound__prefix = "")

  let isWatched = is_watched_gun_sound(gun__owner)
  if !isWatched
    let delay = get_sound_speed_delay(evt.tm[3])
    if delay > 0.1f
      gun_sound__shootHistory |> push(float4(get_sync_time() + delay, evt.tm[3].x, evt.tm[3].y, evt.tm[3].z))
      gun_sound__lastFiringMode = int(evt.firingMode)
      return

  gun_sound_on_shot(evt.tm[3],
                    evt.firingMode,
                    gun,
                    gun__timeBetweenShots,
                    isWatched,
                    gun_sound__hasGrain,
                    gun_sound__forceOneshot,
                    gun_sound__forceOneshotEnemy,
                    gun_sound__startLoopWithNOneshots,
                    gun_sound__numShotsInLoop,
                    gun_sound__event,
                    gun_sound__playerTimeBetweenShotsMad,
                    gun_sound__shotLoopTimeout,
                    gun_sound__grainTTL,
                    gun__owner,
                    turret__owner,
                    gun_sound__shotPath,
                    sound_tags,
                    gun_sound__prefix)


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_shot_evt(evt : EventShot;
                          gun : Gun;
                          gun__timeBetweenShots : float = 0.;
                          gun_sound__hasGrain : bool;
                          var gun_sound__shootHistory : Point4List&;
                          var gun_sound__lastFiringMode : int&;
                          gun_sound__forceOneshot : bool;
                          gun_sound__forceOneshotEnemy : bool;
                          gun_sound__startLoopWithNOneshots : int;
                          var gun_sound__numShotsInLoop : int&;
                          var gun_sound__event : SoundEvent&;
                          gun_sound__playerTimeBetweenShotsMad : float2;
                          var gun_sound__shotLoopTimeout : float&;
                          var gun_sound__grainTTL : float&;
                          gun__owner : EntityId;
                          turret__owner = INVALID_ENTITY_ID;
                          @shared_comp gun_sound__shotPath : Object;
                          sound_tags : Object;
                          gun_sound__prefix = "")
  let isWatched = is_watched_gun_sound(gun__owner)
  if !isWatched
    let delay = get_sound_speed_delay(evt.launchDesc.tm[3])
    if delay > 0.1f
      gun_sound__shootHistory |> push(float4(get_sync_time() + delay, evt.launchDesc.tm[3].x, evt.launchDesc.tm[3].y, evt.launchDesc.tm[3].z))
      gun_sound__lastFiringMode = int(evt.launchDesc.firingMode)
      return

  gun_sound_on_shot(evt.launchDesc.tm[3],
                    evt.launchDesc.firingMode,
                    gun,
                    gun__timeBetweenShots,
                    isWatched,
                    gun_sound__hasGrain,
                    gun_sound__forceOneshot,
                    gun_sound__forceOneshotEnemy,
                    gun_sound__startLoopWithNOneshots,
                    gun_sound__numShotsInLoop,
                    gun_sound__event,
                    gun_sound__playerTimeBetweenShotsMad,
                    gun_sound__shotLoopTimeout,
                    gun_sound__grainTTL,
                    gun__owner,
                    turret__owner,
                    gun_sound__shotPath,
                    sound_tags,
                    gun_sound__prefix)


def is_shooting(gun_sound__shotLoopTimeout : float)
  return gun_sound__shotLoopTimeout > 0.

[es(tag=sound, REQUIRE=gunSound, after=sound_begin_update_es, before=sound_end_update_es)]
def gun_sound_update(info : ParallelUpdateFrameDelayed;
                     gun : Gun;
                     gun__timeBetweenShots : float = 0.;
                     gun_sound__forceOneshot : bool;
                     gun_sound__forceOneshotEnemy : bool;
                     gun_sound__startLoopWithNOneshots : int;
                     gun_sound__playerTimeBetweenShotsMad : float2;
                     gun__owner : EntityId;
                     @shared_comp gun_sound__shotPath : Object;
                     sound_tags : Object;
                     gun_sound__prefix = "";
                     var gun_sound__shotLoopTimeout : float&;
                     var gun_sound__deltaTime : float4&;
                     var gun_sound__shootHistory : Point4List&;
                     gun_sound__lastFiringMode : int;
                     var gun_sound__numShotsInLoop : int&;
                     gun_sound__hasGrain : bool;
                     var gun_sound__event : SoundEvent&;
                     var gun_sound__grainTTL : float&;
                     gun__overheat : float = 0.;
                     turret__owner = INVALID_ENTITY_ID)
  if !sound_banks_is_master_preset_loaded()
    return

  let historySize = length(gun_sound__shootHistory)
  if historySize > 0
    let lastEvent = gun_sound__shootHistory[0]
    if lastEvent.x <= info.curTime
      gun_sound__shootHistory |> erase(0)
      gun_sound_on_shot(float3(lastEvent.y, lastEvent.z, lastEvent.w),
                        uint(gun_sound__lastFiringMode),
                        gun,
                        gun__timeBetweenShots,
                        false, 
                        gun_sound__hasGrain,
                        gun_sound__forceOneshot,
                        gun_sound__forceOneshotEnemy,
                        gun_sound__startLoopWithNOneshots,
                        gun_sound__numShotsInLoop,
                        gun_sound__event,
                        gun_sound__playerTimeBetweenShotsMad,
                        gun_sound__shotLoopTimeout,
                        gun_sound__grainTTL,
                        gun__owner,
                        turret__owner,
                        gun_sound__shotPath,
                        sound_tags,
                        gun_sound__prefix)



  if is_valid_handle_value(gun_sound__event)
    set_var_optional(gun_sound__event, "heat", gun__overheat)
    if !is_shooting(gun_sound__shotLoopTimeout)
      if gun_sound__hasGrain
        set_var_optional(gun_sound__event, "on_shot", 0.)
      else
        abandon_shot_loop(gun_sound__event, turret__owner)

  if gun_sound__numShotsInLoop != -1 && !is_shooting(gun_sound__shotLoopTimeout)
    gun_sound__numShotsInLoop = -1

  if gun_sound__hasGrain
    if (gun_sound__grainTTL > 0.)
      gun_sound__grainTTL -= info.dt
    elif is_valid_handle_value(gun_sound__event)
      abandon_shot_loop(gun_sound__event, turret__owner)

  gun_sound__deltaTime.w = gun_sound__deltaTime.z
  gun_sound__deltaTime.z = gun_sound__deltaTime.y
  gun_sound__deltaTime.y = gun_sound__deltaTime.x
  gun_sound__deltaTime.x = info.dt
  gun_sound__shotLoopTimeout -= min(min(min(gun_sound__deltaTime.x, gun_sound__deltaTime.y), gun_sound__deltaTime.z), gun_sound__deltaTime.w)


[es(tag=sound, REQUIRE=gunSound)]
def gun_sound_on_irq(evt : CmdSoundIrq;
                     animchar_bbox : bbox3f;
                     gun__owner : EntityId;
                     sound_tags : Object;
                     @shared_comp sound_irqs : Object;
                     sound_max_irq_dist = 40.;
                     gun_sound__prefix = "")
  if sound_banks_is_master_preset_loaded()
    let isWatched = is_watched_gun_sound(gun__owner)
    let world_pos = get_gun_sound_pos(animchar_bbox)
    if isWatched || should_play(world_pos, sound_max_irq_dist)
      query(gun__owner) <| $ [es] (var sound_event_group : SoundEventGroup&; transform : float3x4)
        let handle = sound_player_common::play_path(evt.irq, sound_irqs, sound_tags, isWatched, world_pos, false, gun_sound__prefix)
        if is_valid_handle_value(handle)
          let local_pos = inverse(transform) * world_pos
          add_sound(sound_event_group, sound_hash(""), local_pos, handle, 4)
          if evt.irqType == sound_hash("matUnderFeet")
            set_var(handle, "mat", float(get_smid_from_gun_owner(gun__owner)))


def gun_irq_sim(a, b : float;
                irqs : Array;
                gun__owner : EntityId;
                animchar_bbox : bbox3f;
                sound_tags : Object;
                is_watched : bool;
                gun_sound__prefix = "")
  for it in irqs
    let obj = get_ecs_object(it)
    let relPos = obj?.relPos ?? .0
    if relPos >= a && relPos < b
      query(gun__owner) <| $ [es] (var sound_event_group : SoundEventGroup&)
        let handle = sound_player_common::play_path(*obj, sound_tags, is_watched, get_gun_sound_pos(animchar_bbox), false, 0., gun_sound__prefix)
        if is_valid_handle_value(handle)
          add_sound(sound_event_group, sound_hash(""), handle)
          if has(*obj, "matUnderFeet")
            set_var(handle, "mat", float(get_smid_from_gun_owner(gun__owner)))


[es(tag=sound)]
def gun_bolt_action_sound_update(info : ParallelUpdateFrameDelayed&;

                                 gun : Gun;
                                 var gun_bolt_action_sound__time : float&;
                                 @shared_comp gun_bolt_action_sound__irqs : Array;

                                 sound_tags : Object;

                                 gun__owner : EntityId;
                                 animchar_bbox : bbox3f;
                                 sound_max_irq_dist = 40.;
                                 gun_sound__prefix = "")

  let cur = gun |> gun_lerpBoltActionTime(info.curTime)
  assume prev = gun_bolt_action_sound__time

  if prev == cur
    return

  if sound_banks_is_master_preset_loaded()

    let isWatched = is_watched_gun_sound(gun__owner)
    if isWatched || should_play(get_gun_sound_pos(animchar_bbox), sound_max_irq_dist)

      if prev < cur
        gun_irq_sim(prev, cur, gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched, gun_sound__prefix)
      else
        gun_irq_sim(prev, 2., gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched, gun_sound__prefix)
        if cur > 0.
          gun_irq_sim(0., cur, gun_bolt_action_sound__irqs, gun__owner, animchar_bbox, sound_tags, isWatched, gun_sound__prefix)

  prev = cur


[es(tag=sound, on_event=EventOnSoundPresetLoaded, REQUIRE=gunSound)]
def gun_sound_on_unloaded(evt : Event;
                          var gun_sound__numShotsInLoop : int&;
                          var gun_sound__event : SoundEvent&;
                          var gun_sound__shotLoopTimeout : float&;
                          var gun_sound__deltaTime : float4&)
  if !sound_banks_is_master_preset_loaded()
    gun_sound__numShotsInLoop = -1
    release_immediate(gun_sound__event)
    gun_sound__shotLoopTimeout = 0.
    gun_sound__deltaTime = float4(1., 1., 1., 1.)


[es(tag=sound, after=(animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def gun_owner_sound_event_group_update(info : ParallelUpdateFrameDelayed;
                                       var gun_owner_sound_event_group : SoundEventGroup&)
  if sound_banks_is_master_preset_loaded()
    update_sounds(gun_owner_sound_event_group)


[es(tag=sound, on_event=EventOnSoundPresetLoaded)]
def gun_owner_sound_event_group_on_unloaded(evt : Event;
                                            var gun_owner_sound_event_group : SoundEventGroup&)
  if !sound_banks_is_master_preset_loaded()
    release_all_sounds(gun_owner_sound_event_group)


