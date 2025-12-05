require ecs
require app 
require vehicle_sounds_net.modules.vehicle_sounds_net_events
require vehicle_sounds_net.modules.vehicle_net_horn_common
require danetlibs.renderer.includes.pufd_events
require vehicle
require DngNet


[es(tag=server)]
def vehicle_net_horn_control_on_request(evt : CmdVehicleHornRequest;
                                        vehicle_seats__seatEids : EidList&;
                                        var vehicle_horn_control__player : EntityId&;
                                        var vehicle_horn_control__seat : EntityId&;
                                        var vehicle_horn_control__endTime : float&;
                                        vehicle_horn_control__maxDuration : float;
                                        isAlive : bool)
  if !vehicle_horn_control__player || evt.player == vehicle_horn_control__player
    vehicle_horn_control__player = INVALID_ENTITY_ID
    vehicle_horn_control__seat = INVALID_ENTITY_ID
    if evt.enable && isAlive
      vehicle_horn_control__seat = get_player_seat(evt.player, vehicle_seats__seatEids)
      if !!vehicle_horn_control__seat
        vehicle_horn_control__player = evt.player
        vehicle_horn_control__endTime = get_sync_time() + vehicle_horn_control__maxDuration


[es(tag=server, no_order)]
def vehicle_net_horn_control_update(info : ParallelUpdateFrameDelayed;
                                    vehicle_seats__seatEids : EidList&;
                                    var vehicle_horn_control__player : EntityId&;
                                    var vehicle_horn_control__seat : EntityId&;
                                    vehicle_horn_control__endTime : float;
                                    isAlive : bool)
  if !!vehicle_horn_control__player
    if !isAlive || info.curTime >= vehicle_horn_control__endTime || vehicle_horn_control__seat != get_player_seat(vehicle_horn_control__player, vehicle_seats__seatEids)
      vehicle_horn_control__player = INVALID_ENTITY_ID
      vehicle_horn_control__seat = INVALID_ENTITY_ID
