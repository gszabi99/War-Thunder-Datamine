from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { getSkillCategoryByName } = require("%scripts/crew/crewSkills.nut")
let { getSkillListParameterRowsView } = require("%scripts/crew/crewSkillParameters.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getCrewById, getSelectedCrews } = require("%scripts/slotbar/slotbarState.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getCrewSkillPoints, getMaxAvailbleCrewStepValue, crewSkillValueToStep, getSkillMaxCrewLevel,
  getCrewTotalSteps, getSkillCrewLevel, getCrewMaxSkillValue, getCrew, getCrewSkillValue
} = require("%scripts/crew/crew.nut")
let { crewSpecTypes, getCrewSpecTypeByCode, getSpecTypeByCrewAndUnit
} = require("%scripts/crew/crewSpecType.nut")

function getSkillCategoryName(skillCategory) {
  return loc($"crewSkillCategory/{skillCategory.categoryName}", skillCategory.categoryName)
}

function getCategoryParameterRows(skillCategory, crewUnitType, crew, unit) {
  let difficulty = getCurrentShopDifficulty()
  return getSkillListParameterRowsView(crew, difficulty, skillCategory.skillItems, crewUnitType, unit)
}

function getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit) {
  let headerLocId = $"crewSkillCategoryTooltip/{skillCategory.categoryName}"
  let view = {
    tooltipText = loc(headerLocId, "".concat(getSkillCategoryName(skillCategory), ":"))
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, crewUnitType, crewData, unit)
    headerItems = null
  }

  let crewSkillPoints = getCrewSkillPoints(crewData)
  foreach (categorySkill in skillCategory.skillItems) {
    if (categorySkill.isVisible(crewUnitType))
      continue
    let skillItem = categorySkill.skillItem
    if (!skillItem)
      continue

    let memberName = loc($"crew/{categorySkill.memberName}")
    let skillName = loc($"crew/{categorySkill.skillName}")
    let skillValue = getCrewSkillValue(crewData.id, unit, categorySkill.memberName, categorySkill.skillName)
    let availValue = getMaxAvailbleCrewStepValue(skillItem, skillValue, crewSkillPoints)
    view.skillRows.append({
      skillName = format("%s (%s)", skillName, memberName)
      totalSteps = getCrewTotalSteps(skillItem)
      maxSkillCrewLevel = getSkillMaxCrewLevel(skillItem)
      skillLevel = getSkillCrewLevel(skillItem, skillValue)
      availableStep = crewSkillValueToStep(skillItem, availValue)
      skillMaxValue = getCrewMaxSkillValue(skillItem)
      skillValue = skillValue
    })
  }

  //use header items for legend
  if (view.parameterRows.len())
    view.headerItems <- view.parameterRows[0].valueItems

  return handyman.renderCached("%gui/crew/crewSkillParametersTooltip.tpl", view)
}

addTooltipTypes({
  SKILL_CATEGORY = { //by categoryName, unitTypeName
    getTooltipId = function(categoryName, unitName = "", _p2 = null, _p3 = null) {
      return this._buildId(categoryName, { unitName = unitName })
    }
    getTooltipContent = function(categoryName, params) {
      let unit = getAircraftByName(params?.unitName ?? "")
      let crewUnitType = (unit?.unitType ?? unitTypes.INVALID).crewUnitType
      let skillCategory = getSkillCategoryByName(categoryName)
      let country = profileCountrySq.get()
      let crewCountryId = shopCountriesList.findindex(@(v) v==country) ?? -1
      let crewIdInCountry = getSelectedCrews(crewCountryId)
      let crewData = getCrew(crewCountryId, crewIdInCountry)
      if (skillCategory != null && crewUnitType != CUT_INVALID && crewData != null)
        return getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit)
      return ""
    }
  }

  CREW_SPECIALIZATION = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, _p3 = null) {
      return this._buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params) {
      let crew = getCrewById(to_integer_safe(crewIdStr, -1))
      let unit = getAircraftByName(getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = getCrewSpecTypeByCode(getTblValue("specTypeCode", params, -1))
      if (specType == crewSpecTypes.UNKNOWN)
        specType = getSpecTypeByCrewAndUnit(crew, unit)
      if (specType == crewSpecTypes.UNKNOWN)
        return ""

      return specType.getTooltipContent(crew, unit)
    }
  }

  BUY_CREW_SPEC = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, _p3 = null) {
      return this._buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params) {
      let crew = getCrewById(to_integer_safe(crewIdStr, -1))
      let unit = getAircraftByName(getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = getCrewSpecTypeByCode(getTblValue("specTypeCode", params, -1))
      if (specType == crewSpecTypes.UNKNOWN)
        specType = getSpecTypeByCrewAndUnit(crew, unit).getNextType()
      if (specType == crewSpecTypes.UNKNOWN)
        return ""

      return specType.getBtnBuyTooltipContent(crew, unit)
    }
  }
})

return {
  getSkillCategoryName
}
