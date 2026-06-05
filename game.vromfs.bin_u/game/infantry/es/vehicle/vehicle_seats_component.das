require ecs
require ecs.common
require DagorSystem

[es(tag=server, on_appear)]
def init_seat_component(evt : Event;
                        eid : EntityId;
                        seat__id : int;
                        seat__vehicleEid : EntityId;
                        var seat__component : int&)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats, seat__id)
    if seat == null
      return

    let componentName = get_string(*seat, "seatComponent", "")
    if componentName == ""
      logerr("seatComponent is not set for {seat__vehicleEid} ({getEntityTemplateName(seat__vehicleEid)})")
      return

    seat__component = int(ecs_hash(componentName))

    let seatComponentName = "seat__{componentName}"
    let seatComponentHash = ecs_hash(seatComponentName)
    setOptional(eid, "", seatComponentHash, true)
