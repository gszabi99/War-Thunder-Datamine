local u = require("sqStdLibs/helpers/u.nut")
local platform = require("scripts/clientState/platform.nut")
local helpTypes = require("scripts/controls/help/controlsHelpTypes.nut")

local tabGroups = [
  {
    title = "#controls/help/aircraft_simpleControls"
    list = [
      helpTypes.IMAGE_AIRCRAFT
      helpTypes.CONTROLLER_AIRCRAFT
      helpTypes.KEYBOARD_AIRCRAFT
      helpTypes.RADAR_AIRBORNE
    ]
  }
  {
    title = "#controls/help/tank_simpleControls"
    list = [
      helpTypes.IMAGE_TANK
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
      helpTypes.RADAR_AIRBORNE
    ]
  }
  {
    title = "#mission_objectives"
    list = [
      helpTypes.MISSION_OBJECTIVES
    ]
  }
  {
    title = platform.isPlatformXboxOne? "#presets/xboxone/thrustmaster_hotasOne" : "#presets/ps4/thrustmaster_hotas4"
    list = [
      helpTypes.HOTAS4_COMMON
    ]
  }
]

::getTabs <- function getTabs(contentSet)
{
  local res = []
  foreach (group in tabGroups)
  {
    local filteredGroup = group.list.filter(@(t) t.needShow(contentSet))
    if (filteredGroup.len() > 0)
      res.append(group.__update({list = filteredGroup}))
  }
  return res
}

::getPrefferableType <- function getPrefferableType(contentSet)
{
  if (contentSet == HELP_CONTENT_SET.LOADING)
    return helpTypes.MISSION_OBJECTIVES

  local unit = ::get_player_cur_unit()
  local unitTag = ::is_submarine(unit) ? "submarine" : null

  foreach (pattern in [
    CONTROL_HELP_PATTERN.HOTAS4,
    CONTROL_HELP_PATTERN.MISSION,
    CONTROL_HELP_PATTERN.IMAGE,
    CONTROL_HELP_PATTERN.GAMEPAD,
    CONTROL_HELP_PATTERN.KEYBOARD_MOUSE,
    CONTROL_HELP_PATTERN.RADAR,
  ])
  {
    local helpType = ::u.search(helpTypes.types, @(t) t.helpPattern == pattern
      && t.needShow(contentSet)
      && t.showByUnit(unit, unitTag))
    if (helpType)
      return helpType
  }

  return helpTypes.IMAGE_AIRCRAFT
}

return {
  getTabs = getTabs
  getPrefferableType = getPrefferableType
}