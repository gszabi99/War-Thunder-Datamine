require ecs
require %appGame.infantry.es.team_common
require %appGame.infantry.es.vehicle.vehicle_events


def get_restrict_to_team(vehicle_seats__seatEids : EidList)
  var restrictToTeam = TEAM_UNASSIGNED
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid : EntityId)
      query(seat__ownerEid) <| $ [es] (isAlive : bool = true; team : int = TEAM_UNASSIGNED)
        if isAlive
          restrictToTeam = team
    if restrictToTeam != TEAM_UNASSIGNED
      break
  return restrictToTeam

[es(tag=server, on_event=EventOnSeatOwnersChanged)]
def vehicle_restrict_to_team_seat_owner_changed(evt : Event;
                                                vehicle_seats__seatEids : EidList;
                                                vehicle_seats__autoDetectRestrictToTeam : bool;
                                                var vehicle_seats__restrictToTeam : int&)
  if vehicle_seats__autoDetectRestrictToTeam
    vehicle_seats__restrictToTeam = get_restrict_to_team(vehicle_seats__seatEids)
