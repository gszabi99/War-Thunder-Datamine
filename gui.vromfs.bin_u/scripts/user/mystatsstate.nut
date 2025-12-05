from "%scripts/dagui_natives.nut" import stat_get_value_time_played
from "%scripts/dagui_library.nut" import *
let { get_game_settings_blk } = require("blkGetters")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

let newPlayersBattles = {}
let unitTypeByNewbieEventId = {}

function getClassFlags(unitType) {
  if (unitType == ES_UNIT_TYPE_AIRCRAFT)
    return CLASS_FLAGS_AIRCRAFT
  if (unitType == ES_UNIT_TYPE_TANK)
    return CLASS_FLAGS_TANK
  if (unitType == ES_UNIT_TYPE_SHIP)
    return CLASS_FLAGS_SHIP
  if (unitType == ES_UNIT_TYPE_HELICOPTER)
    return CLASS_FLAGS_HELICOPTER
  if (unitType == ES_UNIT_TYPE_BOAT)
    return CLASS_FLAGS_BOAT
  return (1 << EUCT_TOTAL) - 1
}

function getSummaryFromProfile(func, unitType = null, diff = null, mode = 1  ) {
  local res = 0.0
  let classFlags = getClassFlags(unitType)
  for (local i = 0; i < EUCT_TOTAL; ++i)
    if (classFlags & (1 << i)) {
      if (diff != null)
        res += func(diff, i, mode)
      else
        for (local d = 0; d < 3; ++d)
          res += func(d, i, mode)
    }
  return res
}

function getTimePlayed(unitType = null, diff = null) {
  return getSummaryFromProfile(stat_get_value_time_played, unitType, diff)
}


function isNewbieEventId(eventName) {
  foreach (config in newPlayersBattles)
    foreach (evData in config.battles)
      if (eventName == evData.event)
        return true
  return false
}

function getUnitTypeByNewbieEventId(eventId) {
  return unitTypeByNewbieEventId?[eventId] ?? ES_UNIT_TYPE_INVALID
}

function onEventInitConfigs(_) {
  let settingsBlk = get_game_settings_blk()
  let blk = settingsBlk?.newPlayersBattles
  if (!blk)
    return

  foreach (unitType in unitTypes.types) {
    let data = {
      minKills = 0
      battles = []
      additionalUnitTypes = []
    }

    let list = blk % unitType.lowerName
    foreach (ev in list) {
      if (!ev.event)
        continue

      unitTypeByNewbieEventId[ev.event] <- unitType.esUnitType
      let kills = ev?.kills ?? 1
      data.battles.append({
        event       = ev?.event
        kills       = kills
        timePlayed  = ev?.timePlayed ?? 0
        unitRank    = ev?.unitRank ?? 0
      })
      data.minKills = max(data.minKills, kills)
    }

    let additionalUnitTypesBlk = blk?.additionalUnitTypes[unitType.lowerName]
    if (additionalUnitTypesBlk)
      data.additionalUnitTypes = additionalUnitTypesBlk % "type"
    if (data.minKills)
      newPlayersBattles[unitType.esUnitType] <- data
  }
}

addListenersWithoutEnv({
  InitConfigs = onEventInitConfigs
  ScriptsReloaded = onEventInitConfigs
}, g_listener_priority.LOGIN_PROCESS)

return {
  getTimePlayed
  isNewbieEventId
  getUnitTypeByNewbieEventId
  getNewPlayersBattlesConfig = @() freeze(newPlayersBattles)
}
