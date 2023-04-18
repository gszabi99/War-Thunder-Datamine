//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { getSkillValue } = require("%scripts/crew/crewSkills.nut")
let { getSkillListParameterRowsView } = require("%scripts/crew/crewSkillParameters.nut")

let function getSkillCategoryName(skillCategory) {
  return loc($"crewSkillCategory/{skillCategory.categoryName}", skillCategory.categoryName)
}

let function getCategoryParameterRows(skillCategory, crewUnitType, crew, unit) {
  let difficulty = ::get_current_shop_difficulty()
  return getSkillListParameterRowsView(crew, difficulty, skillCategory.skillItems, crewUnitType, unit)
}

let function getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit) {
  let headerLocId = "crewSkillCategoryTooltip/" + skillCategory.categoryName
  let view = {
    tooltipText = loc(headerLocId, getSkillCategoryName(skillCategory) + ":")
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, crewUnitType, crewData, unit)
    headerItems = null
  }

  let crewSkillPoints = ::g_crew.getCrewSkillPoints(crewData)
  foreach (categorySkill in skillCategory.skillItems) {
    if (categorySkill.isVisible(crewUnitType))
      continue
    let skillItem = categorySkill.skillItem
    if (!skillItem)
      continue

    let memberName = loc("crew/" + categorySkill.memberName)
    let skillName = loc("crew/" + categorySkill.skillName)
    let skillValue = getSkillValue(crewData.id, unit, categorySkill.memberName, categorySkill.skillName)
    let availValue = ::g_crew.getMaxAvailbleStepValue(skillItem, skillValue, crewSkillPoints)
    view.skillRows.append({
      skillName = format("%s (%s)", skillName, memberName)
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

  return ::handyman.renderCached("%gui/crew/crewSkillParametersTooltip.tpl", view)
}

return {
  getSkillCategoryName
  getSkillCategoryTooltipContent
}
