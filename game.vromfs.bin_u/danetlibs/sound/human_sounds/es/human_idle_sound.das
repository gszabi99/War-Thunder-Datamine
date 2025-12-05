require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require danetlibs.renderer.includes.pufd_events
require HumanPhys
require DagorSystem


[es(tag=sound, on_appear, track=(human_net_phys__curMoveState, sleep_mode__isActivated))]
def human_idle_sound_is_idle(evt : Event;
                             var human_idle_sound__isActive : bool&;
                             human_net_phys__curMoveState : int = int(HUMoveState.EMS_SPRINT);
                             sleep_mode__isActivated : bool = true)
  human_idle_sound__isActive = sleep_mode__isActivated && (human_net_phys__curMoveState == int(HUMoveState.EMS_SPRINT) ||
                                                           human_net_phys__curMoveState == int(HUMoveState.EMS_RUN))


[es(tag=sound, on_appear, track=(human_idle_sound__isActive, sound_control__state, isAlive), REQUIRE=humanIdleSound)]
def human_idle_sound(evt : Event;
                     sound_control__state : int;
                     human_idle_sound__isActive : bool = false;
                     sound_tags : Object;
                     @shared_comp human_idle_sound__paths : Object;
                     var human_idle_sound__event : SoundEvent&;
                     is_watched_sound : bool;
                     transform : float3x4;
                     isAlive : bool)
  abandon(human_idle_sound__event)
  if have_sound(sound_control__state) && isAlive
    let path = human_idle_sound__isActive ? "activeState" : "idleState"
    human_idle_sound__event |> reset(sound_player_common::play_path(path, human_idle_sound__paths, sound_tags, is_watched_sound, transform[3], false))


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def human_idle_sound_update(evt : ParallelUpdateFrameDelayed;
                            human_idle_sound__event : SoundEvent;
                            transform : float3x4)
  if is_valid_handle_value(human_idle_sound__event)
    set_pos(human_idle_sound__event, transform[3])
