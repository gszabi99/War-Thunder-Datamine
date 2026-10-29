from "%sqstd/platform.nut" import is_xboxone














return freeze([
  {
    id = "hangar_regular"
    isRegularHangar = true
    customPath = is_xboxone ? "config/hangar_xboxone.blk"
      : null
  }

  {
    id = "hangar_halloween"
    locId = "options/hangar_halloween"
    beginDate = "10-27 00:00:00"
    endDate = "11-01 00:00:00"
    customPath = is_xboxone ? "config/hangar_halloween_xboxone.blk"
      : null
  }

  {
    id = "hangar_winter"
    locId = "options/hangar_winter"
    beginDate = "12-10 00:00:00"
    endDate = "01-08 00:00:00"
    customPath = is_xboxone ? "config/hangar_winter_xboxone.blk"
      : null
  }

  {
    id = "hangar_14_years"
    locId = "options/hangar_birthday"
    beginDate = "11-01 00:00:00"
    endDate = "11-06 00:00:00"
  }

  {
    id = "hangar_lunar_ny"
    locId = "options/hangar_lunar_ny"
    beginDate = "02-06 00:00:00"
    endDate = "02-16 00:00:00"
  }







])
