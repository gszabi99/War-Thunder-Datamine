require ecs
require ecs.safe
require ecs.common
require player
require vehicle
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear, on_event=EventOnSeatOwnersChanged, track=(vehicleCameraType, sound_preset__isLoaded), REQUIRE=vehicleWithWatched)]
def vehicle_inside_sound_enabled(evt : Event;
                                 sound_preset__isLoaded : bool;
                                 @shared_comp vehicle_inside_sound_enabled__forSeats : StringList;
                                 vehicle_inside_sound_enabled__ifCommanderCameraType : bool;
                                 vehicleCameraType = int(VehicleCameraType.VEHICLE_CAMERA_NONE);

                                 @shared_comp vehicle_seats__seats : Array;
                                 vehicle_seats__seatEids : EidList;
                                 var vehicle_inside_sound_enabled : bool&)
  if !sound_preset__isLoaded
    vehicle_inside_sound_enabled = false
    return

  if vehicleCameraType == int(VehicleCameraType.VEHICLE_CAMERA_COMMANDER) && !vehicle_inside_sound_enabled__ifCommanderCameraType
    vehicle_inside_sound_enabled = false
    return

  if empty(vehicle_inside_sound_enabled__forSeats)
    vehicle_inside_sound_enabled = true
    return

  vehicle_inside_sound_enabled = false
  query(get_local_player_eid()) <| $ [es] (possessed : EntityId)
    for i in iter_range(vehicle_seats__seatEids)
      let seatEid = vehicle_seats__seatEids[i]
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
        if !!seat__ownerEid && seat__ownerEid == possessed
          let seatName = get_ecs_object(vehicle_seats__seats[i])?.name ?? ""
          vehicle_inside_sound_enabled ||= find_index(vehicle_inside_sound_enabled__forSeats, seatName) >= 0


[es(tag=sound, on_disappear, REQUIRE=vehicleWithWatched)]
def vehicle_inside_snapshot_sound_on_disappear(evt : Event;
                                               var vehicle_inside_sound_enabled : bool&)
  vehicle_inside_sound_enabled = false


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, REQUIRE=vehicleWithWatched, after=(animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def vehicle_inside_snapshot_sound(evt : Event;
                                  var vehicle_inside_snapshot_sound__event : SoundEvent&;
                                  vehicle_inside_snapshot_sound__path : string;
                                  vehicle_inside_sound_enabled : bool;
                                  transform : float3x4)
  if vehicle_inside_snapshot_sound__event |> play_or_abandon(vehicle_inside_snapshot_sound__path, transform[3], vehicle_inside_sound_enabled)
    set_pos(vehicle_inside_snapshot_sound__event, transform[3])


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, REQUIRE=vehicleWithWatched, after=(animchar_before_render_es, sound_begin_update_es), before=sound_end_update_es)]
def vehicle_inside_vibration_sound(evt : Event;
                                   var vehicle_inside_vibration_sound__event : SoundEvent&;
                                   vehicle_inside_vibration_sound__path : string;
                                   vehicle_inside_sound_enabled : bool;
                                   vehicle_sound_speed_state__speed : float;
                                   transform : float3x4)
  if vehicle_inside_vibration_sound__event |> play_or_abandon(vehicle_inside_vibration_sound__path, transform[3], vehicle_inside_sound_enabled)
    set_pos(vehicle_inside_vibration_sound__event, transform[3])
    set_var(vehicle_inside_vibration_sound__event, "speed", vehicle_sound_speed_state__speed)


[es(tag=sound, on_disappear, REQUIRE=vehicleWithWatched)]
def vehicle_inside_snapshot_sound_on_not_watched(evt : Event;
                                                 var vehicle_inside_snapshot_sound__event : SoundEvent&)
  abandon_play_or(vehicle_inside_snapshot_sound__event)


[es(tag=sound, on_disappear, REQUIRE=vehicleWithWatched)]
def vehicle_inside_vibration_sound_on_not_watched(evt : Event;
                                                  var vehicle_inside_vibration_sound__event : SoundEvent&)
  abandon_play_or(vehicle_inside_vibration_sound__event)
