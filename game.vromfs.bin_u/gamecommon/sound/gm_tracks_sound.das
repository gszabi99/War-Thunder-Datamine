require ecs
require math.base
require DagorSystem
require DagorConsole
require Unit
require IGroundModel
require HeavyVehicleModel
require soundEvent
require %game.events
require %game.sound.sound_events
require Sound


[es(on_appear, tag=sound)]
def gm_sub_vechicle_track_sound_init_es(evt : Event;
                                        var gm_sub_vechicle_track_sound__cached_params : FloatList&)
  gm_sub_vechicle_track_sound__cached_params |> resize(8)

def set_param_cached(sound_event : SoundEvent;
                     name : string;
                     new_val : float;
                     var cached_val : float&;
                     threshold : float)
  if !is_equal_float(cached_val, new_val, threshold)
    sound_event |> set_var_optional(name, new_val)
    cached_val = new_val

[es(tag=sound)]
def gm_sub_vechicle_track_sound_update_es(act : ParallelUpdateFrameDelayed;
                                          unit__ref : UnitRef;
                                          gm_sub_vechicle_track_sound__event_name : das_string;
                                          gm_sub_vechicle_track_sound__idx : int;
                                          var gm_sub_vechicle_track_sound__event : SoundEvent&;
                                          var gm_sub_vechicle_track_sound__cached_params : FloatList&;
                                          gm_sub_vechicle_track_sound__pos : float3)
  let unit = unit__ref.unit
  let gm = unit |> as_gm()
  let hv = unit |> as_hv()
  if gm == null || hv == null
    return

  let trackSpd = hv.getTrackSpd
  let isMoving = !is_equal_float(trackSpd.x, 0.f) || !is_equal_float(trackSpd.y, 0.f);
  let newPos = *hv |> getSubVehiclePos(gm_sub_vechicle_track_sound__idx)

  if isMoving
    if !is_playing(gm_sub_vechicle_track_sound__event)
      gm_sub_vechicle_track_sound__event |> play(string(gm_sub_vechicle_track_sound__event_name), newPos)
  else
    abandon(gm_sub_vechicle_track_sound__event)

  if is_playing(gm_sub_vechicle_track_sound__event)

    let swim = gm.swimEffectIntensity
    let speed = cvt(max(trackSpd.x, trackSpd.y), 0.f, 10.f, 0.f, 100.f)
    let visible = gm.isVisibleFromHero ? 1. : 0.
    let intense = speed / 100.f

    if length_sq(newPos - gm_sub_vechicle_track_sound__pos) > 0.09
      gm_sub_vechicle_track_sound__event |> set_pos(newPos)
    set_param_cached(gm_sub_vechicle_track_sound__event, "swim", swim, gm_sub_vechicle_track_sound__cached_params[0], 0.5)
    set_param_cached(gm_sub_vechicle_track_sound__event, "speed", speed, gm_sub_vechicle_track_sound__cached_params[1], 5.0)
    set_param_cached(gm_sub_vechicle_track_sound__event, "is_visible", visible, gm_sub_vechicle_track_sound__cached_params[2], 0.5)
    set_param_cached(gm_sub_vechicle_track_sound__event, "intense", intense, gm_sub_vechicle_track_sound__cached_params[3], 0.1)

  elif is_valid_event(gm_sub_vechicle_track_sound__event)
    release(gm_sub_vechicle_track_sound__event)

