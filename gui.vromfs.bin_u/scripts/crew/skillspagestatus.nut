//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
::g_skills_page_status <-
{
  types = []
}

::g_skills_page_status.template <- {
  priority = 0
  minSteps = 0
  minSkillsRel = 0 //relative value of skills on this page from all skills available on page.
  style = ""
  icon = "#ui/gameuiskin#new_crew_skill_points.svg"
  color = "white"
  show = true
  wink = false
}

enums.addTypesByGlobalName("g_skills_page_status", {
  NONE = {
    show = false
  }
  ONE = {
    priority = 1
    minSteps = 1
    minSkillsRel = 0.1
    style = "show"
    color = "crewSkills_show"
  }
  HALF = {
    priority = 2
    minSteps = 2
    minSkillsRel = 0.5
    style = "ready"
    color = "crewSkills_ready"
  }
  MOST = {
    priority = 3
    minSteps = 2
    minSkillsRel = 0.7
    style = "full"
    color = "crewSkills_full"
    wink = true
  }
  /*
  FULL = {
    priority = 4
    minSteps = 5
    minSkillsRel = 1.0
    style = "full"
    color = "crewSkills_full"
    wink = true
  }
  */
})

::g_skills_page_status.getPageStatus <- function getPageStatus(crew, unit, page, crewUnitType, skillPoints) {
  local res = ::g_skills_page_status.NONE
  let items = getTblValue("items", page)
  if (!items || !items.len())
    return res

  let total = items.len()
  local allowedMax = 0  //amount of skills not maxed but allowed to max
  let allowedAmount = [] //only for not maxed
  foreach (item in items) {
    if (!item.isVisible(crewUnitType))
      continue

    let totalSteps = ::g_crew.getTotalSteps(item)
    let value = ::g_crew.getSkillNewValue(item, crew, unit)
    let curStep = ::g_crew.skillValueToStep(item, value)
    if (curStep >= totalSteps)
      continue

    let availValue = ::g_crew.getMaxAvailbleStepValue(item, value, skillPoints)
    let availStep = ::g_crew.skillValueToStep(item, availValue)

    if (totalSteps == availStep)
      allowedMax++
    else
      allowedAmount.append(availStep - curStep)
  }

  foreach (statusType in this.types) {
    if (res.priority >= statusType.priority)
      continue

    local checked = allowedMax
    foreach (allowed in allowedAmount)
      if (allowed >= statusType.minSteps)
        checked++

    if (statusType.minSkillsRel * total <= checked)
      res = statusType
  }
  return res
}
