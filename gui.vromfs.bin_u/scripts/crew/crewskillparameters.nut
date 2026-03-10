from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { calc_crew_parameters } = require("unitCalculcation")
let { getSortOrderBySkillParameterName, getMinSkillsUnitRepairRank, getSkillsNotAffectedByLeadership
} = require("%scripts/crew/crewSkills.nut")
let { get_game_params_blk, get_wpcost_blk } = require("blkGetters")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let { g_skill_parameters_type } = require("skillParametersType.nut")
let skillParametersColumnType = require("%scripts/crew/skillParametersColumnType.nut")

let parametersByCrewId = {}
let skillGroups = { 
  eyesight = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
  field_repair = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
  machine_gunner = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
}

function getParametersByCrewId(crewId, unitName) {
  local parameters = parametersByCrewId?[crewId][unitName]
  if (parameters == null) {
    



















    parameters = calc_crew_parameters(crewId,  null, unitName)
    if (!(crewId in parametersByCrewId))
      parametersByCrewId[crewId] <- {}
    parametersByCrewId[crewId][unitName] <- parameters
  }
  return parameters
}

function removeParametersByCrew(params) {
  let crewId = params.crew.id
  parametersByCrewId?.$rawdelete(crewId)
}

function onEventCrewSkillsChanged(params) {
  removeParametersByCrew(params)
}

function onEventQualificationIncreased(params) {
  removeParametersByCrew(params)
}

function onEventSignOut(_params) {
  parametersByCrewId.clear()
}

function getBaseDescriptionText(memberName, skillName, skillParamsList) {
  let hasDescNotes = skillName == "eyesight" && skillGroups.eyesight.contains(memberName)
  if (!hasDescNotes)
    return {
      text = loc($"crew/{memberName}/{skillName}/tooltip")
      descriptionNotes = null
    }

  let blk = get_game_params_blk()
  let detectDefaults = blk?.detectDefaults
  let defaultHearingDistance = blk?.tankAlwaysDetectedDistance ?? 0
  let hearingDistance =
    skillParamsList?.currentParametersByRequestType[skillParametersRequestType.CURRENT_VALUES].hearingDistance[0].value
      ?? defaultHearingDistance

  let descNotesLocParams = {
    targetingMul = detectDefaults?.distanceMultForTargetingView ?? 1.0
    binocularMul = detectDefaults?.distanceMultForBinocularView ?? 1.0
    distance = hearingDistance
  }

  return {
    text = loc("crew/eyesight/tank/tooltip")
    descriptionNotes = loc("crew/eyesight/tank/tooltip/descNotes", descNotesLocParams)
  }
}


function getColumnsTypesList(skillsList, crewUnitType) {
  let columnTypes = []
  foreach (columnType in skillParametersColumnType.types) {
    if (!columnType.checkCrewUnitType(crewUnitType))
      continue

    foreach (skill in skillsList)
      if (columnType.checkSkill(skill.memberName, skill.skillName)) {
        columnTypes.append(columnType)
        break
      }
  }
  return columnTypes
}

function getSkillListHeaderRow(crew, columnTypes, unit) {
  let res = {
    descriptionLabel = loc("crewSkillParameterTable/descriptionLabel")
    valueItems = []
    isHeader = true
  }

  let headerImageParams = {
    crew = crew
    unit = unit
  }
  foreach (columnType in columnTypes)
    res.valueItems.append({
      itemText = columnType.getHeaderText()
      itemImage = columnType.getHeaderImage(headerImageParams)
      imageSize = columnType.getHeaderImageSize().tostring()
      imageLegendText = columnType.getHeaderImageLegendText()
      hasSeparatorBefore = columnType.hasSeparatorBefore
      hasSeparatorAfter = columnType.hasSeparatorAfter
    })

  return res
}


function getParametersByRequestType(crewId, skillsList, difficulty, requestType, useSelectedParameters, unit) {
  let res = {}
  let fullParamsList = useSelectedParameters
                         ? requestType.getSelectedParameters(crewId, unit)
                         : requestType.getParameters(crewId, unit)

  foreach (skill in skillsList) {
    
    let skillParams = fullParamsList?[difficulty.crewSkillName][skill.memberName][skill.skillName]
    if (!skillParams)
      continue
    foreach (key, value in skillParams) {
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

function getTooltipText(memberName, skillName, crewUnitType, crew, difficulty, unit, skillParamsList) {
  let desc = getBaseDescriptionText(memberName, skillName, skillParamsList)
  let resArray = [desc.text]
  if (unit && unit.unitType.crewUnitType != crewUnitType) {
    let text = loc("crew/skillsWorkWithUnitsSameType")
    resArray.append(colorize("warningTextColor", text))
  }
  else if (crew && memberName == "groundService" && skillName == "repair") {
    let fullParamsList = skillParametersRequestType.CURRENT_VALUES.getParameters(crew.id, unit)
    let repairRank = fullParamsList?[difficulty.crewSkillName][memberName].repairRank.groundServiceRepairRank ?? 0
    if (repairRank != 0 && unit && unit.rank > repairRank) {
      let text = loc("crew/notEnoughRepairRank", {
                          rank = colorize("activeTextColor", get_roman_numeral(unit.rank))
                          level = colorize("activeTextColor",
                            getMinSkillsUnitRepairRank(unit.rank))
                         })
      resArray.append(colorize("warningTextColor", text))
    }
  }
  else if (memberName == "loader" && skillName == "loading_time_mult") {
    let wBlk = get_wpcost_blk()
    if (unit && wBlk?[unit.name].primaryWeaponAutoLoader) {
      let text = loc("crew/loader/loading_time_mult/tooltipauto")
      resArray.append(colorize("warningTextColor", text))
    }
  }

  return {
    text = "\n".join(resArray, true)
    descriptionNotes = desc.descriptionNotes
  }
}

function getSortedArrayByParamsTable(parameters, crewUnitType) {
  let res = []
  foreach (name, valuesArr in parameters) {
    if (crewUnitType != CUT_AIRCRAFT && name == "airfieldMinRepairTime")
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

function parseParameters(columnTypes,
  currentParametersByRequestType, selectedParametersByRequestType, crewUnitType) {
  let res = []
  let currentParameters = currentParametersByRequestType[skillParametersRequestType.CURRENT_VALUES]
  if (!u.isTable(currentParameters))
    return res

  let paramsArray = getSortedArrayByParamsTable(currentParameters, crewUnitType)
  foreach (_idx, paramData in paramsArray) {
    let parametersType = g_skill_parameters_type.getTypeByParamName(paramData.name)
    parametersType.parseColumns(paramData, columnTypes,
      currentParametersByRequestType, selectedParametersByRequestType, res)
  }
  return res
}

function filterSkillsList(skillsList, crewUnitType) {
  let res = []
  foreach (skill in skillsList) {
    if (!skill.isVisible(crewUnitType))
      continue

    let group = getTblValue(skill.skillName, skillGroups)
    if (group) {
      let resSkill = u.search(res,
        @(rs) skill.skillName == rs.skillName && isInArray(rs.memberName, group))
      if (resSkill)
        continue
    }
    res.append(skill)
  }
  return res
}

function getSkillParamsList(crew, difficulty, notFilteredSkillsList, crewUnitType, unit) {
  let skillsList = filterSkillsList(notFilteredSkillsList, crewUnitType)

  let columnTypes = getColumnsTypesList(skillsList, crewUnitType)

  
  let fullRequestsList = [skillParametersRequestType.CURRENT_VALUES] 
  foreach (columnType in columnTypes) {
    u.appendOnce(columnType.previousParametersRequestType, fullRequestsList, true)
    u.appendOnce(columnType.currentParametersRequestType, fullRequestsList, true)
  }

  
  let currentParametersByRequestType = {}
  let selectedParametersByRequestType = {}
  foreach (requestType in fullRequestsList) {
    currentParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, false, unit)
    selectedParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, true, unit)
  }
  return {columnTypes, currentParametersByRequestType, selectedParametersByRequestType}
}

function getSkillRowsViewInternal(skillParamsList, crew, crewUnitType, unit) {
  let res = parseParameters(skillParamsList.columnTypes,
    skillParamsList.currentParametersByRequestType, skillParamsList.selectedParametersByRequestType, crewUnitType)
  
  if (res.len()) {
    
    res.each(@(row, idx) row.__update({ isEven = idx % 2 == 0 }))
    res.insert(0, getSkillListHeaderRow(crew, skillParamsList.columnTypes, unit))
  }

  return res
}


function getSkillListParameterRowsView(crew, difficulty, skillsList, crewUnitType, unit) {
  let skillParamsList = getSkillParamsList(crew, difficulty, skillsList, crewUnitType, unit)
  return getSkillRowsViewInternal(skillParamsList, crew, crewUnitType, unit)
}

let collapseLeadershipParameterRows = @(parameterRows, hasNotes) [
  parameterRows[0]  
  {
    descriptionLabel = "".concat(loc("crewSkillParameter/allCrewSkills"), hasNotes ? "*" : "")
    valueItems = parameterRows[1].valueItems 
    isEven = true
  }
]

function getLeadershipNotes(crewUnitType) {
  let excludedSkills = getSkillsNotAffectedByLeadership(crewUnitType)
  if (excludedSkills.len() == 0)
    return ""

  let skillsList = excludedSkills.reduce(@(acc, skillName)
    "".concat(acc, "\n", colorize("commonTextColor", loc($"crew/{skillName}"))), "")
  return "".concat("*", loc("crewSkillParameter/except"), loc("ui/colon"), skillsList)
}

function getSkillDescriptionView(crew, difficulty, memberName, skillName, crewUnitType, unit) {
  let skillsList = [{
    memberName = memberName
    skillName = skillName
    isVisible = @(_) true
  }]
  let skillParamsList = getSkillParamsList(crew, difficulty, skillsList, crewUnitType, unit)
  let tooltip = getTooltipText(memberName, skillName, crewUnitType, crew, difficulty, unit, skillParamsList)
  local parameterRows = getSkillRowsViewInternal(skillParamsList, crew, crewUnitType, unit)
  local { descriptionNotes } = tooltip

  if (skillName == "leadership" && parameterRows.len() >= 2) {
    let leadershipNotes = getLeadershipNotes(crewUnitType)
    descriptionNotes = "\n".join([leadershipNotes, descriptionNotes], true)
    parameterRows = collapseLeadershipParameterRows(parameterRows, leadershipNotes != "")
  }

  let view = {
    skillName = loc($"crew/{skillName}")
    skillDescription = tooltip.text
    descriptionNotes

    
    parameterRows
    footnoteText = "".concat(loc("shop/all_info_relevant_to_current_game_mode"),
      loc("ui/colon"), difficulty.getLocName())
  }

  return view
}

subscriptions.addListenersWithoutEnv({
  CrewSkillsChanged = onEventCrewSkillsChanged
  QualificationIncreased = onEventQualificationIncreased
  SignOut = onEventSignOut
})

return {
  getParametersByCrewId
  getSkillListParameterRowsView
  getSkillDescriptionView
}