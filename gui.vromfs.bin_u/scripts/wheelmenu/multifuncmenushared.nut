local function isMultifuncMenuAvailable() {
  return (::is_platform_pc  && ::has_feature("HudMultifuncMenu"))
      || (!::is_platform_pc && ::has_feature("HudMultifuncMenuOnConsoles"))
}

local function isWheelmenuAxisConfigurable() {
  return ::has_feature("WheelmenuCustomAxis") && ::get_axis_index("wheelmenu_x") != -1
}

return {
  isMultifuncMenuAvailable = isMultifuncMenuAvailable
  isWheelmenuAxisConfigurable = isWheelmenuAxisConfigurable
}
