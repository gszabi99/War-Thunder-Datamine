local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local { calc_crew_parameters } = ::require_native("unitCalculcation")
local { getSortOrderBySkillParameterName, getMinSkillsUnitRepairRank } = require("scripts/crew/crewSkills.nut")

local parametersByCrewId = {}
local skillGroups = { //skills which have completely the same parameters for different members
  eyesight = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
  field_repair = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
  machine_gunner = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
}

local function getParametersByCrewId(crewId, unitName) {
  local parameters = parametersByCrewId?[crewId][unitName]
  if (parameters == null) {
    /*local values =
    {
      pilot = {
        gForceTolerance = 10,
        hearing = 10,
        vitality = 10,
        endurance = 10,
        eyesight = 10,
      },
      gunner = {
        accuracy = 10,
        eyesight = 10,
        hearing = 10,
        vitality = 10,
        gForceTolerance = 10,
        endurance = 10,
        density = 10,
      },
      specialization = 1,
    };*/
    parameters = calc_crew_parameters(crewId, /*values*/null, unitName)
    if (!(crewId in parametersByCrewId))
      parametersByCrewId[crewId] <- {}
    parametersByCrewId[crewId][unitName] <- parameters
  }
  return parameters
}

local function removeParametersByCrew(params) {
  local crewId = params.crew.id
  if (crewId in parametersByCrewId)
    delete parametersByCrewId[crewId]
}

local function onEventCrewSkillsChanged(params) {
  removeParametersByCrew(params)
}

local function onEventQualificationIncreased(params) {
  removeParametersByCrew(params)
}

local function onEventSignOut(params) {
  parametersByCrewId.clear()
}

local function getBaseDescriptionText(memberName, skillName, crew) {
  local locId = ::format("crew/%s/%s/tooltip", memberName, skillName)
  local locParams = null

  if (skillName == "eyesight"
    && ::isInArray(memberName, ["driver", "tank_gunner", "commander", "loader", "radio_gunner"])) {
    locId = "crew/eyesight/tank/tooltip"

    local blk = ::dgs_get_game_params()
    local detectDefaults = blk?.detectDefaults
    locParams = {
      targetingMul = ::getTblValue("distanceMultForTargetingView", detectDefaults, 1.0)
      binocularMul = ::getTblValue("distanceMultForBinocularView", detectDefaults, 1.0)
    }
  }

  return ::loc(locId, locParams)
}

local function getTooltipText(memberName, skillName, crewUnitType, crew, difficulty, unit) {
  local resArray = [getBaseDescriptionText(memberName, skillName, crew)]
  if (unit && unit.unitType.crewUnitType != crewUnitType) {
    local text = ::loc("crew/skillsWorkWithUnitsSameType")
    resArray.append(::colorize("warningTextColor", text))
  }
  else if (crew && memberName == "groundService" && skillName == "repair") {
    local fullParamsList = ::g_skill_parameters_request_type.CURRENT_VALUES.getParameters(crew.id, unit)
    local repairRank = fullParamsList?[difficulty.crewSkillName][memberName].repairRank.groundServiceRepairRank ?? 0
    if (repairRank!=0 && unit && unit.rank > repairRank)
    {
      local text = ::loc("crew/notEnoughRepairRank", {
                          rank = ::colorize("activeTextColor", ::get_roman_numeral(unit.rank))
                          level = ::colorize("activeTextColor",
                            getMinSkillsUnitRepairRank(unit.rank))
                         })
      resArray.append(::colorize("warningTextColor", text))
    }
  }
  else if (memberName == "loader" && skillName == "loading_time_mult")
  {
    local wBlk = ::get_wpcost_blk()
    if (unit && wBlk?[unit.name].primaryWeaponAutoLoader)
    {
      local text = ::loc("crew/loader/loading_time_mult/tooltipauto")
      resArray.append(::colorize("warningTextColor", text))
    }
  }

  return ::g_string.implode(resArray, "\n")
}

//skillsList = [{ memberName = "", skillName = "" }]
local function getColumnsTypesList(skillsList, crewUnitType) {
  local columnTypes = []
  foreach (columnType in ::g_skill_parameters_column_type.types) {
    if (!columnType.checkCrewUnitType(crewUnitType))
      continue

    foreach(skill in skillsList)
      if (columnType.checkSkill(skill.memberName, skill.skillName))
      {
        columnTypes.append(columnType)
        break
      }
  }
  return columnTypes
}

local function getSkillListHeaderRow(crew, columnTypes, unit) {
  local res = {
    descriptionLabel = ::loc("crewSkillParameterTable/descriptionLabel")
    valueItems = []
  }

  local headerImageParams = {
    crew = crew
    unit = unit
  }
  foreach (columnType in columnTypes)
    res.valueItems.append({
      itemText = columnType.getHeaderText()
      itemImage = columnType.getHeaderImage(headerImageParams)
      imageSize = columnType.imageSize.tostring()
      imageLegendText = columnType.getHeaderImageLegendText()
    })
  res.valueItems.append({
    itemDummy = true
  })

  return res
}

//skillsList = [{ memberName = "", skillName = "" }]
local function getParametersByRequestType(crewId, skillsList, difficulty, requestType, useSelectedParameters, unit) {
  local res = {}
  local fullParamsList = useSelectedParameters
                         ? requestType.getSelectedParameters(crewId, unit)
                         : requestType.getParameters(crewId, unit)

  foreach(skill in skillsList) {
    // Leaving data only related to selected difficulty, member and skill.
    local skillParams = fullParamsList?[difficulty.crewSkillName][skill.memberName][skill.skillName]
    if (!skillParams)
      continue
    foreach(key, value in skillParams) {
      if (!(key in res))
        res[key] <- []
      res[key].append({
        memberName = skill.memberName
        skillName = skill.skillName
        value = value
      })
    }
  }
  return res
}

local function getSortedArrayByParamsTable(parameters, crewUnitType) {
  local res = []
  foreach(name, valuesArr in parameters) {
    if (crewUnitType != ::CUT_AIRCRAFT && name == "airfieldMinRepairTime")
      continue
    res.append({
      name = name
      valuesArr = valuesArr
      sortOrder = getSortOrderBySkillParameterName(name)
    })
  }

  res.sort(function(a, b) {
    if (a.sortOrder != b.sortOrder)
      return a.sortOrder > b.sortOrder ? 1 : -1
    return 0
  })
  return res
}

local function parseParameters(columnTypes,
  currentParametersByRequestType, selectedParametersByRequestType, crewUnitType)
{
  local res = []
  local currentParameters = currentParametersByRequestType[::g_skill_parameters_request_type.CURRENT_VALUES]
  if (!::u.isTable(currentParameters))
    return res

  local paramsArray = getSortedArrayByParamsTable(currentParameters, crewUnitType)
  foreach (idx, paramData in paramsArray)
  {
    local parametersType = ::g_skill_parameters_type.getTypeByParamName(paramData.name)
    parametersType.parseColumns(paramData, columnTypes,
      currentParametersByRequestType, selectedParametersByRequestType, res)
  }
  return res
}

local function filterSkillsList(skillsList) {
  local res = []
  foreach(skill in skillsList) {
    local group = ::getTblValue(skill.skillName, skillGroups)
    if (group) {
      local resSkill = ::u.search(res, (@(skill, group) function(resSkill) {
                         return skill.skillName == resSkill.skillName && ::isInArray(resSkill.memberName, group)
                       })(skill, group))
      if (resSkill)
        continue
    }

    res.append(skill)
  }
  return res
}

//skillsList = [{ memberName = "", skillName = "" }]
local function getSkillListParameterRowsView(crew, difficulty, notFilteredSkillsList, crewUnitType, unit)
{
  local skillsList = filterSkillsList(notFilteredSkillsList)

  local columnTypes = getColumnsTypesList(skillsList, crewUnitType)

  //preparing full requestsList
  local fullRequestsList = [::g_skill_parameters_request_type.CURRENT_VALUES] //required for getting params list
  foreach(columnType in columnTypes) {
    ::u.appendOnce(columnType.previousParametersRequestType, fullRequestsList, true)
    ::u.appendOnce(columnType.currentParametersRequestType, fullRequestsList, true)
  }

  //collect parameters by request types
  local currentParametersByRequestType = {}
  local selectedParametersByRequestType = {}
  foreach (requestType in fullRequestsList) {
    currentParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, false, unit)
    selectedParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, true, unit)
  }

  // Here goes generation of skill parameters cell values.
  local res = parseParameters(columnTypes,
    currentParametersByRequestType, selectedParametersByRequestType, crewUnitType)
  // If no parameters added then hide table's header.
  if (res.len()) // Nothing but header row.
    res.insert(0, getSkillListHeaderRow(crew, columnTypes, unit))

  return res
}

local function getSkillDescriptionView(crew, difficulty, memberName, skillName, crewUnitType, unit) {
  local skillsList = [{
    memberName = memberName
    skillName = skillName
  }]

  local view = {
    skillName = ::loc("crew/" + skillName)
    tooltipText = getTooltipText(memberName, skillName, crewUnitType, crew, difficulty, unit)

    // First item in this array is table's header.
    parameterRows = getSkillListParameterRowsView(crew, difficulty, skillsList, crewUnitType, unit)
    footnoteText = ::loc("shop/all_info_relevant_to_current_game_mode")
      + ::loc("ui/colon") + difficulty.getLocName()
  }

  if (!view.parameterRows.len())
    return view

  //use header items for legend
  view.headerItems <- view.parameterRows[0].valueItems

  //getprogressbarFrom a first row (it the same for all rows, so we showing it in a top of tooltip
  local firstRow = ::getTblValue(1, view.parameterRows)
  view.progressBarValue <- ::getTblValue("progressBarValue", firstRow)
  view.progressBarSelectedValue <- ::getTblValue("progressBarSelectedValue", firstRow)

  return view
}

subscriptions.addListenersWithoutEnv({
  CrewSkillsChanged = onEventCrewSkillsChanged
  QualificationIncreased = onEventQualificationIncreased
  SignOut = onEventSignOut
})

return {
  getParametersByCrewId = getParametersByCrewId
  getSkillListParameterRowsView = getSkillListParameterRowsView
  getSkillDescriptionView = getSkillDescriptionView
}