from "%scripts/dagui_library.nut" import *

let { get_game_settings_blk } = require("blkGetters")
let DataBlock = require("DataBlock")


function isDynamicCountryAllowed(country) {
  let sBlk = get_game_settings_blk()
  let list = sBlk?.dynamicCountries

  if (!list || !list.paramCount())
    return true
  return list?[country] == true
}

function getMissionTeamCountries(layout) {
  local res = null
  if (!layout)
    return res

  let lblk = DataBlock()
  lblk.load(layout)
  let mBlk = lblk?.mission_settings.mission
  if (!mBlk)
    return res

  let checkDynamic = mBlk?.type == "dynamic"

  res = []
  foreach (cTag in ["country_allies", "country_axis"]) {
    local c = mBlk?[cTag] ?? "ussr"
    if (!checkDynamic || isDynamicCountryAllowed(c))
      c = $"country_{c}"
    else
      c = null
    res.append(c)
  }
  return res
}

return {
  isDynamicCountryAllowed
  getMissionTeamCountries
}