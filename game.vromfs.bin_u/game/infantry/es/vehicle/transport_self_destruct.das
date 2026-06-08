require ecs
require DagorMath
require app
require net
require Unit
require %game.events
require %game.unit.unit_events
require %appGame.infantry.es.vehicle.vehicle_events
require %appGame.infantry.es.vehicle.vehicle_seats_common


[es(tag=server, on_appear, on_event=(EventUnitSpawned, EventUnitRespawn))]
def transport_self_destruct_init_es(evt : Event;
                                    unit__ref : UnitRef;
                                    var transport__homeTm : float3x4&)
  transport__homeTm = unit__ref.unit.unitTm


[es(tag=server, on_event=EventOnSeatOwnersChanged)]
def transport_self_destruct_track_es(evt : Event;
                                     transform : float3x4;
                                     vehicle_seats__seatEids : EidList;
                                     transport__homeTm : float3x4;
                                     transport__selfDestructDelay : float;
                                     transport__homeDistThreshold : float;
                                     var transport__abandonTimer : float&)
  let abandoned = !is_vehicle_with_crew(vehicle_seats__seatEids) && length(transform[3] - transport__homeTm[3]) > transport__homeDistThreshold
  transport__abandonTimer = abandoned ? get_sync_time() + transport__selfDestructDelay : -1.


[es(tag=server, no_order)]
def transport_self_destruct_update_es(info : UpdateStageInfoAct;
                                      isAlive : bool;
                                      var unit__ref : UnitRef;
                                      var transport__abandonTimer : float&)
  if transport__abandonTimer < 0.
    return
  if !isAlive
    transport__abandonTimer = -1.
    return
  if get_sync_time() < transport__abandonTimer
    return
  *unit__ref.unit |> doBailout()
  transport__abandonTimer = -1.
