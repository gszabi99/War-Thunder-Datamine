local getMissionLocIdsArray = function(missionInfo) {
  local res = []
  local misInfoName = missionInfo?.name ?? ""

  if ((missionInfo?["locNameTeamA"].len() ?? 0) > 0)
    res = ::g_localization.getLocIdsArray(missionInfo, "locNameTeamA")
  else if ((missionInfo?.locName.len() ?? 0) > 0)
    res = ::g_localization.getLocIdsArray(missionInfo, "locName")
  else
    res.append($"missions/{misInfoName}")

  if ("".join(res.filter(@(id) id.len() > 1).map(@(id) ::loc(id))) == "") {
    local misInfoPostfix = missionInfo?.postfix ?? ""
    if (misInfoPostfix != "" && misInfoName.indexof(misInfoPostfix)) {
      local name = misInfoName.slice(0, misInfoName.indexof(misInfoPostfix))
      res.append(
        "[",
        $"missions/{misInfoPostfix}",
        "]",
        " ",
        $"missions/{name}"
      )
    }
    else
      res.append($"missions/{missionInfo?.name ?? ""}")
  }

  return res
}

return {
  getMissionLocIdsArray
}