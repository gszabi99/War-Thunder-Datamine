local { getSkillValue } = require("scripts/crew/crewSkills.nut")
local { getSkillListParameterRowsView } = require("scripts/crew/crewSkillParameters.nut")

local function getSkillCategoryName(skillCategory) {
  return ::loc($"crewSkillCategory/{skillCategory.categoryName}", skillCategory.categoryName)
}

local function getCategoryParameterRows(skillCategory, crewUnitType, crew, unit) {
  local difficulty = ::get_current_shop_difficulty()
  return getSkillListParameterRowsView(crew, difficulty, skillCategory.skillItems, crewUnitType, unit)
}

local function getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit) {
  local headerLocId = "crewSkillCategoryTooltip/" + skillCategory.categoryName
  local view = {
    tooltipText = ::loc(headerLocId, getSkillCategoryName(skillCategory) + ":")
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, crewUnitType, crewData, unit)
    headerItems = null
  }

  local crewSkillPoints = ::g_crew.getCrewSkillPoints(crewData)
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (categorySkill.isVisible(crewUnitType))
      continue
    local skillItem = categorySkill.skillItem
    if (!skillItem)
      continue

    local memberName = ::loc("crew/" + categorySkill.memberName)
    local skillName = ::loc("crew/" + categorySkill.skillName)
    local skillValue = getSkillValue(crewData.id, unit, categorySkill.memberName, categorySkill.skillName)
    local availValue = ::g_crew.getMaxAvailbleStepValue(skillItem, skillValue, crewSkillPoints)
    view.skillRows.append({
      skillName = ::format("%s (%s)", skillName, memberName)
      totalSteps = ::g_crew.getTotalSteps(skillItem)
      maxSkillCrewLevel = ::g_crew.getSkillMaxCrewLevel(skillItem)
      skillLevel = ::g_crew.getSkillCrewLevel(skillItem, skillValue)
      availableStep = ::g_crew.skillValueToStep(skillItem, availValue)
      skillMaxValue = ::g_crew.getMaxSkillValue(skillItem)
      skillValue = skillValue
    })
  }

  //use header items for legend
  if (view.parameterRows.len())
    view.headerItems <- view.parameterRows[0].valueItems

  return ::handyman.renderCached("gui/crew/crewSkillParametersTooltip", view)
}

return {
  getSkillCategoryName
  getSkillCategoryTooltipContent
}
