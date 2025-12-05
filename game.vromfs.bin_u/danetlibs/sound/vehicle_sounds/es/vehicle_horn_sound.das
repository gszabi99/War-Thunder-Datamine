require ecs
require ecs.common
require app 
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events
require vehicle_sounds_net.modules.vehicle_sounds_net_events
require vehicle_sounds_net.modules.vehicle_net_horn_common
require soundEvent
require soundHash
require player


[es(tag=sound, on_appear, track=(vehicle_horn_control__player, vehicle_horn_control__localPlayer, sound_preset__isLoaded))]
def vehicle_horn_sound_toggle(evt : Event;
                              vehicle_horn_control__player : EntityId;
                              vehicle_horn_control__localPlayer : EntityId;
                              sound_preset__isLoaded : bool;

                              vehicle_horn_sound__note : int;
                              var vehicle_horn_sound__event : SoundEvent&;
                              @shared_comp vehicle_horn_sound__path : Object;
                              sound_tags : Object;
                              is_watched_sound : bool;
                              transform : float3x4)
  let shouldPlay = sound_preset__isLoaded && (!!vehicle_horn_control__player || !!vehicle_horn_control__localPlayer)
  if vehicle_horn_sound__event.enabled != shouldPlay
    vehicle_horn_sound__event.enabled = shouldPlay
    abandon(vehicle_horn_sound__event)
    if vehicle_horn_sound__event.enabled
      vehicle_horn_sound__event |> reset(sound_player_common::play_path(vehicle_horn_sound__path, sound_tags, is_watched_sound, transform[3], false))
      set_var_optional(vehicle_horn_sound__event, "note", float(vehicle_horn_sound__note))


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_horn_sound_update(info : ParallelUpdateFrameDelayed;
                              vehicle_horn_sound__event : SoundEvent&;
                              transform : float3x4)
  if vehicle_horn_sound__event.enabled
    set_pos(vehicle_horn_sound__event, transform[3])



[es(tag=sound)]
def vehicle_local_horn_control_on_request(evt : CmdVehicleHornRequest;
                                          vehicle_seats__seatEids : EidList&;
                                          var vehicle_horn_control__localPlayer : EntityId&;
                                          var vehicle_horn_control__localSeat : EntityId&;
                                          var vehicle_horn_control__endTime : float&;
                                          vehicle_horn_control__maxDuration : float;
                                          isAlive : bool)
  if evt.player == get_local_player_eid()
    vehicle_horn_control__localPlayer = INVALID_ENTITY_ID
    vehicle_horn_control__localSeat = INVALID_ENTITY_ID
    if evt.enable && isAlive
      vehicle_horn_control__localSeat = get_player_seat(evt.player, vehicle_seats__seatEids)
      if !!vehicle_horn_control__localSeat
        vehicle_horn_control__localPlayer = evt.player
        vehicle_horn_control__endTime = get_sync_time() + vehicle_horn_control__maxDuration


[es(tag=sound, no_order)]
def vehicle_local_horn_control_update(info : ParallelUpdateFrameDelayed;
                                      vehicle_seats__seatEids : EidList&;
                                      var vehicle_horn_control__localPlayer : EntityId&;
                                      var vehicle_horn_control__localSeat : EntityId&;
                                      vehicle_horn_control__endTime : float;
                                      isAlive : bool)
  if !!vehicle_horn_control__localPlayer
    if !isAlive || info.curTime >= vehicle_horn_control__endTime || vehicle_horn_control__localSeat != get_player_seat(vehicle_horn_control__localPlayer, vehicle_seats__seatEids)
      vehicle_horn_control__localPlayer = INVALID_ENTITY_ID
      vehicle_horn_control__localSeat = INVALID_ENTITY_ID
