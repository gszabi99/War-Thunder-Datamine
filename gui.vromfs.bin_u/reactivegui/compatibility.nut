//1.69.2.X
::apply_compatibilities({
  perform_cross_call = function (...) { return null }
})


//1.69.4.X
::apply_compatibilities({
  get_mission_time = function () { return 0 }
  get_time_speed = function () { return 1.0 }
  set_time_speed = function (...) {}
  is_game_paused = function () { return false }
})


//1.71.1.X
::apply_compatibilities({
  TRIGGER_GROUP_PRIMARY = 0
  TRIGGER_GROUP_SECONDARY = 1
  TRIGGER_GROUP_COAXIAL_GUN = 2
  TRIGGER_GROUP_MACHINE_GUN = 3
  TRIGGER_GROUP_SPECIAL_GUN = 4
  TRIGGER_GROUP_TORPEDOES = 5
  TRIGGER_GROUP_BOMBS = 6
  TRIGGER_GROUP_ROCKETS = 7
  TRIGGER_GROUP_MINE = 8
  TRIGGER_GROUP_SMOKE_GRENADE = 9
})

//1.77.0.X
::apply_compatibilities({
  get_platform = function() { return "win64" }
})

//1.79.0.X
::apply_compatibilities({
  GT_FOOTBALL = 1 << 27
})