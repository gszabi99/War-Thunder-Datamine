module human_vehicle_common shared


def is_hold_gun_mode_allowed(human_is_in_vehicle : bool;
                             human_is_in_vehicle_hidden : bool;
                             seat_is_passenger : bool;
                             seat_is_hold_gun_mode_allowed : bool;
                             seat_is_in_hatch : bool;
                             seat_can_control_turrets : bool)
  return (human_is_in_vehicle
    && seat_is_hold_gun_mode_allowed
    && (seat_is_in_hatch || (seat_is_passenger && !human_is_in_vehicle_hidden && !seat_can_control_turrets)))
