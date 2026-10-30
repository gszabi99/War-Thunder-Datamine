import "io" as io
from "%scripts/unit/unitsData.nut" import getAllUnits, unitPackedFieldNames
import "%scripts/unit/unit.nut" as Unit
import "%scripts/unit/unitTypesList.nut" as unitTypes
import "packed" as packed
from "dagor.system" import DBGLEVEL
from "console" import register_command
from "dagor.workcycle" import defer
from "string" import format
from "%sqstd/underscore.nut" import isDataBlock
from "%scripts/unit/unitClassType.nut" import unitClassType, getUnitClassTypeByExpClass
from "%scripts/difficulty.nut" import g_difficulty
from "%appGlobals/ranks_common_shared.nut" import EDifficulties, isUnitSpecial
from "%scripts/unit/unitInfo.nut" import getUnitName, getUnitCountry, getUnitCountryIcon, getUnitReqExp, getUnitExp,
  getUnitRealCost, getUnitCost, image_for_air, getUnitTypeTextByUnit, getBattleTypeByUnit
from "%scripts/unit/unitShopInfo.nut" import isUnitGift
from "%scripts/dagui_library.nut" import *
if (DBGLEVEL <= 0)
  return

const MAX_DEPTH = 12
const UNITS_PER_STEP = 10

function dumpRec(v, stack) {
  if (packed.is_view(v))
    return dumpRec(packed.unpack(v), stack)
  let t = type(v)
  if (t == "null" || t == "bool" || t == "integer")
    return $"{v}"
  if (t == "float")
    return format("%.9gf", v)
  if (t == "string")
    return "".concat("\"", v.escape(), "\"")
  if (t != "table" && t != "array" && t != "instance")
    return t
  if (v instanceof Unit)
    return $"Unit({v.name})"
  if (unitTypes.types.contains(v))
    return $"unitType({v.typeName})"
  if (unitClassType.types.contains(v))
    return $"expClass({v.name})"
  if (isDataBlock(v))
    return "".concat("blk{", v.formatAsString().escape(), "}")
  if (stack.contains(v))
    return "<cycle>"
  if (stack.len() >= MAX_DEPTH)
    return "<deep>"

  stack.append(v)
  let items = []
  if (t == "array")
    foreach (e in v)
      items.append(dumpRec(e, stack))
  else {
    foreach (key, val in v)
      if (type(val) != "function")
        items.append($"{dumpRec(key, stack)}={dumpRec(val, stack)}")
    items.sort()
  }
  stack.pop()
  let brackets = t == "array" ? ["[", "]"] : t == "instance" ? ["inst{", "}"] : ["{", "}"]
  return "".concat(brackets[0], ", ".join(items), brackets[1])
}

let dumpValue = @(v) dumpRec(v, [])

function getFieldNames() {
  let res = Unit.getRareFieldNames().extend(unitPackedFieldNames)
  foreach (key, val in Unit)
    if (type(val) != "function" && key != "rareFields")
      res.append(key)
  return res.sort()
}

let difficulties = g_difficulty.types.filter(@(d) d.diffCode >= 0)

let unitGetters = [
  ["isAir", @(u) u.isAir()],
  ["isTank", @(u) u.isTank()],
  ["isShip", @(u) u.isShip()],
  ["isBoat", @(u) u.isBoat()],
  ["isShipOrBoat", @(u) u.isShipOrBoat()],
  ["isSubmarine", @(u) u.isSubmarine()],
  ["isHelicopter", @(u) u.isHelicopter()],
  ["isHuman", @(u) u.isHuman()],
  ["isWalker", @(u) u.isWalker()],
  ["hasWpCostBlk", @(u) u.getUnitWpCostBlk() != null],
  ["isUsable", @(u) u.isUsable()],
  ["isRented", @(u) u.isRented()],
  ["isBroken", @(u) u.isBroken()],
  ["isResearched", @(u) u.isResearched()],
  ["isInResearch", @(u) u.isInResearch()],
  ["getRepairCost", @(u) u.getRepairCost()],
  ["getCrewTotalCount", @(u) u.getCrewTotalCount()],
  ["getCrewUnitType", @(u) u.getCrewUnitType()],
  ["getExp", @(u) u.getExp()],
  ["isBought", @(u) u.isBought()],
  ["isUsableSlaveUnit", @(u) u.isUsableSlaveUnit()],
  ["getEndRecentlyReleasedTime", @(u) u.getEndRecentlyReleasedTime()],
  ["getOperatorCountry", @(u) u.getOperatorCountry()],
  ["getEconomicRank", @(u) array(EDifficulties.TOTAL).map(@(_, ediff) u.getEconomicRank(ediff))],
  ["getBattleRating", @(u) array(EDifficulties.TOTAL).map(@(_, ediff) u.getBattleRating(ediff))],
  ["getCostRepairPerMin", @(u) difficulties.map(@(d) u.getCostRepairPerMin(d))],
  ["getWpRewardMulList", @(u) difficulties.map(@(d) u.getWpRewardMulList(d))],
  ["tostring", @(u) u.tostring()],
  ["typeof", @(u) typeof u],
  ["isEmpty", @(u) u.isEmpty()],
  ["isEqual", @(u) [u.isEqual(u), u.isEqual(null), u.isEqual(Unit({ name = u.name }))]],
  ["canAssignToCrew", @(u) u.canAssignToCrew(getUnitCountry(u))],
  ["canUseByPlayer", @(u) u.canUseByPlayer()],
  ["isVisibleInShop", @(u) u.isVisibleInShop()],
  ["getSkins", @(u) u.getSkins()],
  ["getSkinBlockById", @(u) u.getSkinBlockById("default")],
  ["getPreviewSkinId", @(u) u.getPreviewSkinId()],
  ["getSpawnScore", @(u) u.getSpawnScore()],
  ["getMinimumSpawnScore", @(u) u.getMinimumSpawnScore()],
  ["canPreview", @(u) u.canPreview()],
  ["isDepthChargeAvailable", @(u) u.isDepthChargeAvailable()],
  ["getNVDSights", @(u) u.getNVDSights("")],
  ["getDefaultWeapon", @(u) u.getDefaultWeapon()],
  ["getEntitlements", @(u) u.getEntitlements()],
  ["isSlave", @(u) u.isSlave()],
  ["getUnlockImage", @(u) u.getUnlockImage()],
  ["isSquadronVehicle", @(u) u.isSquadronVehicle()],
  ["getOpenCost", @(u) u.getOpenCost()],
  ["getWeapons", @(u) u.getWeapons()],
  ["getModifications", @(u) u.getModifications()],
  ["sameUnitType", @(u) u.unitType == unitTypes.getByEsUnitType(u.esUnitType)],
  ["sameExpClass", @(u) u.expClass == getUnitClassTypeByExpClass(u.expClass.getExpClass())],
  ["getUnitName", @(u) getUnitName(u)],
  ["getUnitCountry", @(u) getUnitCountry(u)],
  ["getUnitCountryIcon", @(u) getUnitCountryIcon(u, true)],
  ["getUnitReqExp", @(u) getUnitReqExp(u)],
  ["getUnitExp", @(u) getUnitExp(u)],
  ["getUnitRealCost", @(u) getUnitRealCost(u)],
  ["getUnitCost", @(u) getUnitCost(u)],
  ["image_for_air", @(u) image_for_air(u)],
  ["getUnitTypeTextByUnit", @(u) getUnitTypeTextByUnit(u)],
  ["getBattleTypeByUnit", @(u) getBattleTypeByUnit(u)],
  ["isUnitSpecial", @(u) isUnitSpecial(u)],
  ["isUnitGift", @(u) isUnitGift(u)],
]

function callGetter(getter, unit) {
  try {
    return dumpValue(getter(unit))
  }
  catch (e) {
    return $"ERR {dumpValue(e)}"
  }
}

function writeFields(file, unit, fieldNames, section) {
  file.writestring($"== {section} {unit.name}\n")
  foreach (key in fieldNames)
    file.writestring($"f {key} = {dumpValue(unit[key])}\n")
}

function writeGetters(file, unit) {
  file.writestring($"== getters {unit.name}\n")
  foreach (getter in unitGetters)
    file.writestring($"g {getter[0]} = {callGetter(getter[1], unit)}\n")
}

function runSteps(steps, onDone) {
  local idx = 0
  local next = null
  next = function() {
    if (idx >= steps.len())
      return onDone()
    steps[idx]()
    idx++
    defer(next)
  }
  next()
}

function addUnitSteps(steps, names, writeUnit) {
  for (local i = 0; i < names.len(); i += UNITS_PER_STEP) {
    let chunk = names.slice(i, i + UNITS_PER_STEP)
    steps.append(@() chunk.each(writeUnit))
  }
}

function dumpUnits(fileName) {
  let units = getAllUnits()
  let names = units.keys().sort()
  let fieldNames = getFieldNames()
  let file = io.file(fileName, "wt")
  file.writestring($"units {names.len()}\n")
  foreach (name in names)
    if (units[name].name != name)
      file.writestring($"bad key {name} -> {units[name].name}\n")

  let steps = []
  addUnitSteps(steps, names, @(name) writeFields(file, units[name], fieldNames, "fields"))
  addUnitSteps(steps, names, @(name) writeGetters(file, units[name]))
  addUnitSteps(steps, names, @(name) writeFields(file, units[name], fieldNames, "after_getters"))
  runSteps(steps, function() {
    file.writestring("end\n")
    file.close()
    console_print($"{names.len()} units dumped to {fileName}")
  })
}

register_command(dumpUnits, "debug.dump_units")
