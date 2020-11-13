local { setUnits, getSlotItem, getCurPreset} = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")

local stepsSpecForFindBestCrew = [
  ::g_crew_spec_type.ACE.code,
  ::g_crew_spec_type.EXPERT.code,
  null
]

local function getBestPresetData(availableUnits, country, hasSlotbarByUnitsGroups) {
  local unitsArray = []
  local eDiff = ::DIFFICULTY_REALISTIC
  foreach (unitName, unitAmount in availableUnits) {
    if (!unitAmount)
      continue

    local unit = ::getAircraftByName(unitName)
    if (unit.canAssignToCrew(country) || hasSlotbarByUnitsGroups)
      unitsArray.append({ unit = unit, rank = unit.getBattleRating(eDiff) })
  }

  if (!unitsArray.len())
    return null

  unitsArray.sort(@(a, b) b.rank <=> a.rank || a.unit.name <=> b.unit.name)
  local countryCrews = ::get_crews_list_by_country(country)
  local trainCrewsData = {}
  local trainCrewsDataForGroups = []
  local usedUnits = []
  local unusedUnits = []
  local curCountryCrews = hasSlotbarByUnitsGroups
    ? getCurPreset().countryPresets?[country].units.map(@(u) u?.name)
    : ::get_crews_list_by_country(country).map(@(c) c?.aircraft)
  local hasChangeInPreset = false
  foreach (specValue in stepsSpecForFindBestCrew) {
    foreach (unitData in unitsArray) {
      local unit = unitData.unit
      if (usedUnits.indexof(unit) != null)
        continue

      local unitName = unit.name
      local unitType = unit.getCrewUnitType()
      local maxCrewLevel = ::g_crew.getMaxCrewLevel(unitType) || 1
      local availableCrews = []
      foreach (crew in countryCrews) {
        local crewId = crew.id
        if (crewId in trainCrewsData)
          continue

        local crewSpec = crew.trainedSpec?[unitName] ?? -1
        if ((specValue != null && crewSpec != specValue)
          || (crewSpec < 0 && !hasSlotbarByUnitsGroups))
          continue

        availableCrews.append({
          id = crewId
          spec = crewSpec
          level = ::g_crew.getCrewLevel(crew, unit, unitType).tofloat() / maxCrewLevel
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

      local bestCrew = availableCrews[0]
      trainCrewsData[bestCrew.id] <- unit
      trainCrewsDataForGroups.append({crew = bestCrew, unit = unit})
      if (bestCrew?.idInCountry == null || curCountryCrews?[bestCrew.idInCountry] != unit.name)
        hasChangeInPreset = true
    }
  }

  local idCountry = ::shopCountriesList.findindex(@(cName) cName == country)
  if (hasSlotbarByUnitsGroups && unusedUnits.len() > 0 && idCountry != null) {
    local emptyCrewId = countryCrews.len()
    foreach (unit in unusedUnits) {
      trainCrewsDataForGroups.append({crew = getSlotItem(idCountry, emptyCrewId), unit = unit})
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

local function generatePreset(availableUnits, country, hasSlotbarByUnitsGroups) {
  local bestPresetData = getBestPresetData(availableUnits, country, hasSlotbarByUnitsGroups)
  if (bestPresetData == null) {
    ::showInfoMsgBox(::loc("worldwar/noPresetUnits"))
    return
  }

  if (!bestPresetData.hasChangeInPreset) {
    ::showInfoMsgBox(::loc("generatePreset/current_preset_is_better"))
    return
  }

  local unusedUnits = bestPresetData.unusedUnits
  if (bestPresetData.trainCrewsData.len() == 0) {
    ::showInfoMsgBox("\n".join([::loc("worldwar/noPresetUnitsCrews"),
      ::colorize("userlogColoredText", ", ".join(unusedUnits.map(@(u) ::getUnitName(u)), true))]))
    return
  }

  local msgArray = ["\n".join([::loc("worldwar/addInPresetMsgText"),
    ::colorize("userlogColoredText", ", ".join(bestPresetData.usedUnits.map(@(u) ::getUnitName(u)), true))])]
  if (unusedUnits.len() > 0 && !hasSlotbarByUnitsGroups)
    msgArray.append("\n".join([::loc("worldwar/notAddInPresetMsgText"),
      ::colorize("userlogColoredText", ", ".join(unusedUnits.map(@(u) ::getUnitName(u)), true))]))
  msgArray.append(::colorize("warningTextColor", ::loc("worldwar/autoPresetWarningText")))

  msgBox("ask_apply_preset", "\n\n".join(msgArray),
    [
      ["yes", function() {
        if (hasSlotbarByUnitsGroups)
          setUnits(bestPresetData.trainCrewsDataForGroups)
        else
          ::batch_train_crew(
            ::get_crews_list_by_country(country).map(@(c) {crewId = c.id,
              airName = bestPresetData.trainCrewsData?[c.id].name ?? ""}),
            null, @() ::broadcastEvent("SlotbarPresetLoaded"))
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