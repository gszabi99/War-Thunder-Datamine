from "%globalScripts/logs.nut" import *
let regexp2 = require("regexp2")
let { loc, doesLocTextExist } = require("dagor.localize")
let { utf8Capitalize } = require("%sqstd/string.nut")

/**
 *  This script is shared between WT and WTM.
 *  And it should work in both daGUI and daRG.
**/

// Simple Unit Types (must be strings in lower case!)

let S_UNDEFINED = ""
let S_AIRCRAFT = "aircraft"
let S_HELICOPTER = "helicopter"
let S_TANK = "tank"
let S_SHIP = "ship"
let S_BOAT = "boat"
let S_SUBMARINE = "submarine"

// PartType

let preparePartType = [
  { pattern = regexp2(@"_l_|_r_"),   replace = "_" },
  { pattern = regexp2(@"[0-9]|dm$"), replace = "" },
  { pattern = regexp2(@"__+"),       replace = "_" },
  { pattern = regexp2(@"_+$"),       replace = "" },
]

function getPartType(name, xrayRemap) {
  if (name == "")
    return ""
  local partType = xrayRemap?[name] ?? name
  foreach (re in preparePartType)
    partType = re.pattern.replace(re.replace, partType)
  return partType
}

// PartName

function getPartNameLocText(partType, simUnitType) {
  local res = ""
  let locPrefixes = [ "armor_class/", "dmg_msg_short/", "weapons_types/" ]
  let checkKeys = [ partType ]
  let idxSeparator = partType.indexof("_")
  if (idxSeparator)
    checkKeys.append(partType.slice(0, idxSeparator))
  checkKeys.append("_".concat(simUnitType, partType))
  if (simUnitType == S_BOAT)
    checkKeys.append($"ship_{partType}")

  foreach (prefix in locPrefixes)
    foreach (key in checkKeys) {
      let locId = "".concat(prefix, key)
      res = doesLocTextExist(locId) ? loc(locId) : ""
      if (res != "")
        return utf8Capitalize(res)
    }

  return partType
}

return {
  // Simple Unit Types
  S_UNDEFINED
  S_AIRCRAFT
  S_HELICOPTER
  S_TANK
  S_SHIP
  S_BOAT
  S_SUBMARINE

  // PartType
  getPartType

  // PartName
  getPartNameLocText
}
