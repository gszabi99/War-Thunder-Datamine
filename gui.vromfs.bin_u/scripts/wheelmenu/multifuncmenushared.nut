local function isMultifuncMenuAvailable() {
  return (::is_platform_pc  && ::has_feature("HudMultifuncMenu"))
      || (!::is_platform_pc && ::has_feature("HudMultifuncMenuOnConsoles"))
}

return {
  isMultifuncMenuAvailable = isMultifuncMenuAvailable
}
