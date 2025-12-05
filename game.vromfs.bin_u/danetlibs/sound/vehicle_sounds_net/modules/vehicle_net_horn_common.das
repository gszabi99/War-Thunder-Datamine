module vehicle_net_horn_common shared

require ecs
require vehicle


def get_player_seat(player : EntityId; seat_eids : EidList&) : EntityId
  var playerSeat = INVALID_ENTITY_ID
  for eid in seat_eids
    query(eid) <| $ [es] (seat__ownerEid : EntityId; seat__ownerControls : VehicleControlsState)
      if seat__ownerControls.canControlVehicle
        query(seat__ownerEid) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId)
          if possessedByPlr == player
            playerSeat = eid
  return playerSeat
