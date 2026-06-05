require ecs
require ecs.common
require %appGame.infantry.es.vehicle.vehicle_seats_common
require DagorSystem

[es(tag=server, after=create_vehicle_seats, on_appear)]
def init_vehicle_seats_order(evt : Event; eid : EntityId; @shared_comp vehicle_seats__seats : Array; vehicle_seats__seatEids : EidList)
  if has(eid, "vehicle_seats__seatsProvideOrder")
    for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
      query(seatEid) <| $ [es] (var seats_order__seatNo : int&)
        seats_order__seatNo = seatNo
    return

  let seatsAmount = length(vehicle_seats__seats)
  var priority = 0
  find_query() <| $ [es] (vehicleSeatsOrder : Array)
    for item in vehicleSeatsOrder
      let orderDesc = get_ecs_object(item)
      if orderDesc == null
        continue

      let orderDescMultiple = get_bool(*orderDesc, "multiple") ?? false
      let orderDescSeatName = get_string(*orderDesc, "name", "")
      if orderDescSeatName == ""
        continue

      if orderDescMultiple
        var seatNo = -1
        while find_next_seat_no(orderDescSeatName, vehicle_seats__seats, seatNo)
          assert(priority < seatsAmount)
          setOptional(vehicle_seats__seatEids[priority++], "seats_order__seatNo", seatNo)
      else
        let seatNo = find_seat_no(orderDescSeatName, vehicle_seats__seats)
        if seatNo >= 0
          assert(priority < seatsAmount)
          setOptional(vehicle_seats__seatEids[priority++], "seats_order__seatNo", seatNo)
    return true

  if priority == seatsAmount
    return

  var rest : array<int>
  reserve(rest, seatsAmount - priority)

  for seatNo in range(seatsAmount)
    let idx = find_index_if(each(vehicle_seats__seatEids)) <| $(seatEid)
      return (get_int(seatEid, "seats_order__seatNo") ?? -1) == seatNo
    if idx < 0
      push(rest, seatNo)

  for seatNo in rest
    let seatEid = vehicle_seats__seatEids[priority]
    let seat = get_ecs_object(vehicle_seats__seats[priority++])
    if seat == null
      continue
    query(seatEid) <| $ [es] (var seats_order__seatNo : int&)
      seats_order__seatNo = seatNo

  assert(priority == seatsAmount)



[es(tag=server, after=init_vehicle_seats_order, on_appear)]
def init_seats_order_no(evt : Event; eid : EntityId; vehicle_seats__seatEids : EidList)
  for seatNo, seatEid in iter_range(vehicle_seats__seatEids), vehicle_seats__seatEids
    query(seatEid) <| $ [es] (var seat__orderNo : int&)
      seat__orderNo = find_seat_order_no(seatNo, vehicle_seats__seatEids)
      if seat__orderNo < 0
        logerr("Order is unknown for seat! {eid} ({getEntityTemplateName(eid)})")
