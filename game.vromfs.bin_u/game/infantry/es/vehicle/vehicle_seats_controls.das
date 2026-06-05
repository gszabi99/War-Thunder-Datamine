require ecs
require IGroundModel
require Unit


[es(tag=server, track=vehicle__controlledByDriver)]
def vehicle_reset_controls_on_driver_exit(evt : Event;
                                          vehicle__controlledByDriver : EntityId;
                                          var unit__ref : UnitRef)
  let driverPresent = vehicle__controlledByDriver != INVALID_ENTITY_ID
  var gm = unit__ref.unit |> as_gm()
  if gm != null
    if driverPresent
      unblock_movement(*gm)
    else
      block_movement(*gm)
