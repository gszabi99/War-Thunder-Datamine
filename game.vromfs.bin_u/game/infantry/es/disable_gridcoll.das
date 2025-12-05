require ecs
require %game.unit.unit_events
require GridCollision

[es(on_appear, track=isInVehicleHidden)]
def gridcoll_set_in_vehicle_es(evt : Event; isInVehicleHidden : bool; var grid_obj__hidden : int&)
  if isInVehicleHidden
    grid_obj__hidden |= int(GridHideFlag.EGH_IN_VEHICLE)
  else
    grid_obj__hidden &= ~int(GridHideFlag.EGH_IN_VEHICLE)

[es]
def unit_in_grid_became_delayed_es(evt : EventUnitDelayedStatusChanged;
                                   var grid_obj__hidden : int&)
  if evt.isDelayed
    grid_obj__hidden |= int(GridHideFlag.EGH_HIDDEN_POS)
  else
    grid_obj__hidden &= ~int(GridHideFlag.EGH_HIDDEN_POS)

[es(on_appear, after=grid_obj_hide_es)]
def unit_in_grid_create_es(evt : Event;
                           active : bool;
                           var grid_obj__hidden : int&)
  if !active
    grid_obj__hidden |= int(GridHideFlag.EGH_HIDDEN_POS)

[es(on_appear, REQUIRE=(deadEntity, human), REQUIRE_NOT=shootingRangeDummy)]
def collision_disabled_for_dead_human_es(evt : Event; var grid_obj__hidden : int&)
  grid_obj__hidden |= int(GridHideFlag.EGH_GAME_EFFECT)

