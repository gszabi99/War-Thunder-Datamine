from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { search } = require("%sqStdLibs/helpers/u.nut")
let platform = require("%scripts/clientState/platform.nut")
let helpTypes = require("%scripts/controls/help/controlsHelpTypes.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { CONTROL_HELP_PATTERN } = require("%scripts/controls/controlsConsts.nut")

let tabGroups = [
  {
    title = "#controls/help/aircraft_simpleControls"
    list = [
      helpTypes.IMAGE_AIRCRAFT_NORMAL
      helpTypes.IMAGE_AIRCRAFT_AAM
      helpTypes.IMAGE_AIRCRAFT_ATGM
      helpTypes.CONTROLLER_AIRCRAFT
      helpTypes.KEYBOARD_AIRCRAFT
      helpTypes.RADAR_AIRCRAFT
      helpTypes.RWR_AIRCRAFT
    ]
  }
  {
    title = "#controls/help/tank_simpleControls"
    list = [
      helpTypes.IMAGE_TANK_OLD
      helpTypes.IMAGE_TANK_MODERN
      helpTypes.CONTROLLER_TANK
      helpTypes.KEYBOARD_TANK
      helpTypes.RADAR_GROUND
    ]
  }
  {
    title = "#controls/help/ship_simpleControls"
    list = [
      helpTypes.IMAGE_SHIP
      helpTypes.CONTROLLER_SHIP
      helpTypes.KEYBOARD_SHIP
    ]
  }
  {
    title = "#hotkeys/ID_SUBMARINE_CONTROL_HEADER"
    list = [
      helpTypes.IMAGE_SUBMARINE
      helpTypes.CONTROLLER_SUBMARINE
      helpTypes.KEYBOARD_SUBMARINE
    ]
  }
  {
    title = "#hotkeys/ID_HELICOPTER_CONTROL_HEADER"
    list = [
      helpTypes.IMAGE_HELICOPTER
      helpTypes.CONTROLLER_HELICOPTER
      helpTypes.KEYBOARD_HELICOPTER
      helpTypes.RADAR_HELICOPTER
      helpTypes.RWR_HELICOPTER
    ]
  }









  {
    title = "#hotkeys/ID_UCAV_CONTROL_HEADER"
    list = [
      helpTypes.IMAGE_UCAV
    ]
  }
  {
    title = "#event/war2077"
    list = [
      helpTypes.IMAGE_WARFARE2077
    ]
  }
  {
    title = "#missions/arachis_Dom"
    list = [
      helpTypes.IMAGE_ARACHIS
    ]
  }
  {
    title = "#mission_objectives"
    list = [
      helpTypes.MISSION_OBJECTIVES
    ]
  }
  {
    title = platform.isPlatformXbox ? "#presets/xboxone/thrustmaster_hotasOne" : "#presets/ps4/thrustmaster_hotas4"
    list = [
      helpTypes.HOTAS4_COMMON
    ]
  }
]

function getTabs(contentSet) {
  let res = []
  foreach (group in tabGroups) {
    let filteredGroup = group.list.filter(@(t) t.needShow(contentSet))
    if (filteredGroup.len() > 0)
      res.append(group.__merge({ list = filteredGroup }))
  }
  return res
}

function getPreferableType(contentSet) {
  if (contentSet == HELP_CONTENT_SET.LOADING)
    return helpTypes.MISSION_OBJECTIVES

  let unit = getPlayerCurUnit()
  let unitTag = unit?.isSubmarine() ? "submarine"
    : (unit?.tags ?? []).contains("type_strike_ucav") ? "ucav"




    : null

  foreach (pattern in [
    CONTROL_HELP_PATTERN.SPECIAL_EVENT,
    CONTROL_HELP_PATTERN.HOTAS4,
    CONTROL_HELP_PATTERN.MISSION,
    CONTROL_HELP_PATTERN.IMAGE,
    CONTROL_HELP_PATTERN.RWR,
    CONTROL_HELP_PATTERN.RADAR,
    CONTROL_HELP_PATTERN.GAMEPAD,
    CONTROL_HELP_PATTERN.KEYBOARD_MOUSE,
  ]) {
    let helpType = search(helpTypes.types, @(t) t.helpPattern == pattern
      && t.needShow(contentSet)
      && t.showByUnit(unit, unitTag))
    if (helpType)
      return helpType
  }

  return helpTypes.IMAGE_AIRCRAFT_NORMAL
}

return {
  getTabs = getTabs
  getPreferableType = getPreferableType
}