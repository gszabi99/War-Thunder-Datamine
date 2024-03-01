from "%scripts/dagui_library.nut" import *

let { setUnits, getSlotItem, getCurPreset } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { batchTrainCrew } = require("%scripts/crew/crewActions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { getCrewLevel, getMaxCrewLevel } = require("%scripts/crew/crew.nut")

let stepsSpecForFindBestCrew = [
  ::g_crew_spec_type.ACE.code,
  ::g_crew_spec_type.EXPERT.code,
  null
]

function getBestPresetData(availableUnits, country, hasSlotbarByUnitsGroups) {
  let unitsArray = []
  let eDiff = DIFFICULTY_REALISTIC
  foreach (unitName, unitAmount in availableUnits) {
    if (!unitAmount)
      continue

    let unit = getAircraftByName(unitName)
    if (unit.canAssignToCrew(country) || hasSlotbarByUnitsGroups)
      unitsArray.append({ unit = unit, rank = unit.getBattleRating(eDiff) })
  }

  if (!unitsArray.len())
    return null

  unitsArray.sort(@(a, b) b.rank <=> a.rank || a.unit.name <=> b.unit.name)
  let countryCrews = getCrewsListByCountry(country)
  let trainCrewsData = {}
  let trainCrewsDataForGroups = []
  let usedUnits = []
  let unusedUnits = []
  let curCountryCrews = hasSlotbarByUnitsGroups
    ? getCurPreset().countryPresets?[country].units.map(@(u) u?.name)
    : getCrewsListByCountry(country).map(@(c) c?.aircraft)
  local hasChangeInPreset = false
  foreach (specValue in stepsSpecForFindBestCrew) {
    foreach (unitData in unitsArray) {
      let unit = unitData.unit
      if (usedUnits.indexof(unit) != null)
        continue

      let unitName = unit.name
      let unitType = unit.getCrewUnitType()
      let maxCrewLevel = getMaxCrewLevel(unitType) || 1
      let availableCrews = []
      foreach (crew in countryCrews) {
        let crewId = crew.id
        if (crewId in trainCrewsData)
          continue

        let crewSpec = crew.trainedSpec?[unitName] ?? -1
        if ((specValue != null && crewSpec != specValue)
          || (crewSpec < 0 && !hasSlotbarByUnitsGroups))
          continue

        availableCrews.append({
          id = crewId
          spec = crewSpec
          level = getCrewLevel(crew, unit, unitType).tofloat() / maxCrewLevel
          country = country
          idCountry = crew.idCountry
          idInCountry = crew.idInCountry
        })
      }
      if (availableCrews.len() == 0) {
        if (specValue == null)
          unusedUnits.append(unit)
        continue
      }

      usedUnits.append(unit)
      availableCrews.sort(@(a, b) b.level <=> a.level || b.spec <=> a.spec)

      let bestCrew = availableCrews[0]
      trainCrewsData[bestCrew.id] <- unit
      trainCrewsDataForGroups.append({ crew = bestCrew, unit = unit })
      if (bestCrew?.idInCountry == null || curCountryCrews?[bestCrew.idInCountry] != unit.name)
        hasChangeInPreset = true
    }
  }

  let idCountry = shopCountriesList.findindex(@(cName) cName == country)
  if (hasSlotbarByUnitsGroups && unusedUnits.len() > 0 && idCountry != null) {
    local emptyCrewId = countryCrews.len()
    foreach (unit in unusedUnits) {
      trainCrewsDataForGroups.append({ crew = getSlotItem(idCountry, emptyCrewId), unit = unit })
      usedUnits.append(unit)
      if (curCountryCrews?[emptyCrewId] != unit.name)
        hasChangeInPreset = true
      emptyCrewId++
    }
  }

  return {
    usedUnits = usedUnits
    unusedUnits = unusedUnits
    trainCrewsData = trainCrewsData
    trainCrewsDataForGroups = trainCrewsDataForGroups
    hasChangeInPreset = hasChangeInPreset
  }
}

function generatePreset(availableUnits, country, hasSlotbarByUnitsGroups) {
  let bestPresetData = getBestPresetData(availableUnits, country, hasSlotbarByUnitsGroups)
  if (bestPresetData == null) {
    showInfoMsgBox(loc("worldwar/noPresetUnits"))
    return
  }

  if (!bestPresetData.hasChangeInPreset) {
    showInfoMsgBox(loc("generatePreset/current_preset_is_better"))
    return
  }

  let unusedUnits = bestPresetData.unusedUnits
  if (bestPresetData.trainCrewsData.len() == 0) {
    showInfoMsgBox("\n".join([loc("worldwar/noPresetUnitsCrews"),
      colorize("userlogColoredText", ", ".join(unusedUnits.map(@(u) getUnitName(u)), true))]))
    return
  }

  let msgArray = ["\n".join([loc("worldwar/addInPresetMsgText"),
    colorize("userlogColoredText", ", ".join(bestPresetData.usedUnits.map(@(u) getUnitName(u)), true))])]
  if (unusedUnits.len() > 0 && !hasSlotbarByUnitsGroups)
    msgArray.append("\n".join([loc("worldwar/notAddInPresetMsgText"),
      colorize("userlogColoredText", ", ".join(unusedUnits.map(@(u) getUnitName(u)), true))]))
  msgArray.append(colorize("warningTextColor", loc("worldwar/autoPresetWarningText")))

  this.msgBox("ask_apply_preset", "\n\n".join(msgArray),
    [
      ["yes", function() {
        if (hasSlotbarByUnitsGroups)
          setUnits(bestPresetData.trainCrewsDataForGroups)
        else
          batchTrainCrew(
            getCrewsListByCountry(country).map(@(c) { crewId = c.id,
              airName = bestPresetData.trainCrewsData?[c.id].name ?? "" }),
            null, @() broadcastEvent("SlotbarPresetLoaded"))
        }
      ],
      ["no", @() null]
    ],
    "yes", { cancel_fn = @() null }
  )
}

return {
  getBestPresetData = getBestPresetData
  generatePreset = generatePreset
}