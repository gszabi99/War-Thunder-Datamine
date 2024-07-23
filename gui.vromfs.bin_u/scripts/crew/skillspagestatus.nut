from "%scripts/dagui_library.nut" import *

let { getCrewTotalSteps, getCrewSkillNewValue, crewSkillValueToStep,
  getNextCrewSkillStepCost
} = require("%scripts/crew/crew.nut")

function getPageStatus(crew, unit, page, crewUnitType, skillPoints) {
  local needShowAdvice = false
  local avalibleSkills = []
  let items = getTblValue("items", page)
  if (!items || !items.len())
    return {needShowAdvice, avalibleSkills}

  local maxStepCost = 0
  foreach (item in items) {
    if (!item.isVisible(crewUnitType))
      continue

    let crewSkillValue = getCrewSkillNewValue(item, crew, unit)
    let totalSteps = getCrewTotalSteps(item)
    let curStep = crewSkillValueToStep(item, crewSkillValue)
    if (curStep == totalSteps)
      continue

    let stepCost = getNextCrewSkillStepCost(item, crewSkillValue, 1)
    if ((page.id != "gunner" || item.name != "members") && (page.id != "groundService" || item.name != "repairRank"))
      maxStepCost = max(maxStepCost, stepCost)

    if (stepCost <= skillPoints)
      avalibleSkills.append(item.name)
  }
  needShowAdvice = (maxStepCost > 0) && (maxStepCost <= skillPoints)
  let iconColor = needShowAdvice ? "crewPageIconGold"
   : avalibleSkills.len() > 0 ? "crewPageIconSilver"
   : "white"
  return {needShowAdvice, avalibleSkills,
    icon = "#ui/gameuiskin#new_crew_skill_points.svg", iconColor}
}

return {
  getPageStatus
}