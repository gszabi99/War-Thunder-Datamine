from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { getSkillCategoryByName } = require("%scripts/crew/crewSkills.nut")
let { getSkillListParameterRowsView, getSkillDescriptionView } = require("%scripts/crew/crewSkillParameters.nut")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getSelectedCrews } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
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

function getSkillCategoryTooltipView(skillCategory, crewUnitType, crewData, unit) {
  let headerLocId = $"crewSkillCategoryTooltip/{skillCategory.categoryName}"
  let view = {
    skillName = loc(headerLocId, getSkillCategoryName(skillCategory))
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, crewUnitType, crewData, unit)
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
      maxSkillCrewLevel = getSkillMaxCrewLevel()
      skillLevel = getSkillCrewLevel(skillItem, skillValue)
      availableStep = crewSkillValueToStep(skillItem, availValue)
      skillMaxValue = getCrewMaxSkillValue(skillItem)
      skillValue = skillValue
    })
  }

  return view
}

function getUnitWithCrewType(unitName) {
  let unit = getAircraftByName(unitName)
  let crewUnitType = (unit?.unitType ?? unitTypes.INVALID).crewUnitType
  return crewUnitType != CUT_INVALID ? { unit, crewUnitType } : null
}

function getSelectedCrewData() {
  let country = profileCountrySq.get()
  let crewCountryId = shopCountriesList.findindex(@(v) v == country) ?? -1
  let crewIdInCountry = getSelectedCrews(crewCountryId)
  return getCrew(crewCountryId, crewIdInCountry)
}

function fitSkillParamsTooltipWidth(infoWnd) {
  let tblObj = infoWnd.findObject("skill_params_tbl")
  let width = tblObj.getSize()[0]
  if (width != 0) {
    let tooltipPaddingX = to_pixels("@frameMediumPadding")
    infoWnd.findObject("skill_params_tooltip").width = width + 2 * tooltipPaddingX
  }
}

addTooltipTypes({
  SKILL_CATEGORY = { 
    isModalTooltip = true
    isCustomTooltipFill = true
    getTooltipId = function(categoryName, unitName = "", _p2 = null, _p3 = null) {
      return this._buildId(categoryName, { unitName = unitName })
    }
    fillTooltip = function(infoWnd, handler, categoryName, params) {
      let unitInfo = getUnitWithCrewType(params?.unitName ?? "")
      if (unitInfo == null)
        return false
      let skillCategory = getSkillCategoryByName(categoryName)
      if (skillCategory == null)
        return false
      let crew = getSelectedCrewData()
      if (crew == null)
        return false

      let view = getSkillCategoryTooltipView(skillCategory, unitInfo.crewUnitType, crew, unitInfo.unit)
      let data = handyman.renderCached("%gui/crew/crewSkillParametersTooltip.tpl", view)
      infoWnd.getScene().replaceContentFromText(infoWnd, data, data.len(), handler)
      fitSkillParamsTooltipWidth(infoWnd)
      return true
    }
  }

  CREW_SPECIALIZATION = { 
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

  BUY_CREW_SPEC = { 
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

  CREW_SKILL_MODAL = { 
    isModalTooltip = true
    isCustomTooltipFill = true
    getTooltipId = function(memberName, skillName = "", unitName = "", _p3 = null) {
      return this._buildId(memberName, { skillName, unitName })
    }
    fillTooltip = function(infoWnd, handler, memberName, params) {
      let { skillName = "", unitName = "" } = params
      let unitInfo = getUnitWithCrewType(unitName)
      if (unitInfo == null)
        return false
      let crew = getSelectedCrewData()
      if (crew == null)
        return false

      let difficulty = getCurrentShopDifficulty()
      let view = getSkillDescriptionView(
        crew, difficulty, memberName, skillName, unitInfo.crewUnitType, unitInfo.unit)
      let data = handyman.renderCached("%gui/crew/crewSkillParametersTooltip.tpl", view)
      infoWnd.getScene().replaceContentFromText(infoWnd, data, data.len(), handler)
      fitSkillParamsTooltipWidth(infoWnd)
      return true
    }
  }
})

return {
  getSkillCategoryName
}
