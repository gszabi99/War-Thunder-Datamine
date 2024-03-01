//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { get_skills_blk } = require("blkGetters")
let { measureType, getMeasureTypeByName } = require("%scripts/measureType.nut")
let { getCrewSkillValue, getCrewSkillItem, getSkillCrewLevel, getSkillMaxCrewLevel
} = require("%scripts/crew/crew.nut")

const DEFAULT_MAX_SKILL_LEVEL = 50

let skillCategories = []
let skillCategoryByName = {}
local skillsLoaded = false
let maxSkillValueByMemberAndSkill = {}
let skillParameterInfo = {} //skillName = { measureType = <string>, sortOrder = <int> }

function createCategory(categoryName) {
  let category = {
    categoryName = categoryName
    skillItems = []
    crewUnitTypeMask = 0
  }
  skillCategories.append(category)
  skillCategoryByName[categoryName] <- category
  return category
}

function loadSkills() {
  ::load_crew_skills_once()
  let skillsBlk = get_skills_blk()
  skillCategories.clear()
  skillCategoryByName.clear()
  maxSkillValueByMemberAndSkill.clear()
  let calcBlk = skillsBlk?.crew_skills_calc
  if (calcBlk == null)
    return
  foreach (memberName, memberBlk in calcBlk) {
    if (!u.isDataBlock(memberBlk))
      continue

    maxSkillValueByMemberAndSkill[memberName] <- {}
    foreach (skillName, skillBlk in memberBlk) {
      if (!u.isDataBlock(skillBlk))
        continue // Not actually a skill blk.
      let skillItem = getCrewSkillItem(memberName, skillName)
      if (!skillItem)
        continue

      //!!FIX ME: need to full use the same skillItems as in g_crew instead of duplicate code
      // Max skill value
      let maxSkillValue = skillBlk?.max_skill_level ?? DEFAULT_MAX_SKILL_LEVEL
      maxSkillValueByMemberAndSkill[memberName][skillName] <- maxSkillValue

      // Skill category
      let categoryName = skillBlk?.skill_category
      if (categoryName == null)
        continue

      local skillCategory = skillCategoryByName?[categoryName]
      if (skillCategory == null)
        skillCategory = createCategory(categoryName)

      let categorySkill = {
        memberName = memberName
        skillName = skillName
        skillItem = skillItem
        isVisible = function(crewUnitType) { return skillItem.isVisible(crewUnitType) }
      }
      skillCategory.crewUnitTypeMask = skillCategory.crewUnitTypeMask | skillItem.crewUnitTypeMask
      skillCategory.skillItems.append(categorySkill)
    }
  }

  skillParameterInfo.clear()
  let typesBlk = skillsBlk?.measure_type_by_skill_parameter
  if (typesBlk != null) {
    local sortOrder = 0
    foreach (parameterName, typeName in typesBlk)
      skillParameterInfo[parameterName] <- {
        measureType = getMeasureTypeByName(typeName, true)
        sortOrder = ++sortOrder
      }
  }
}

function updateSkills() {
  if (!skillsLoaded) {
    skillsLoaded = true
    loadSkills()
  }
}

function getSkillCategories() {
  updateSkills()
  return skillCategories
}

function getSkillCategoryByName(categoryName) {
  updateSkills()
  return skillCategoryByName?[categoryName]
}

function getSkillParameterInfo(parameterName) {
  updateSkills()
  return skillParameterInfo?[parameterName]
}

function getMeasureTypeBySkillParameterName(parameterName) {
  if ( parameterName.indexof("weapons/") == 0 ) {
    return getMeasureTypeBySkillParameterName("airGunReloadTime")
  }
  return getSkillParameterInfo(parameterName)?.measureType ?? measureType.UNKNOWN
}

function getSortOrderBySkillParameterName(parameterName) {
  return getSkillParameterInfo(parameterName)?.sortOrder ?? 0
}

function getSkillCategoryCrewLevel(crewData, unit, skillCategory, crewUnitType) {
  local res = 0
  foreach (categorySkill in skillCategory.skillItems) {
    if (!categorySkill.isVisible(crewUnitType))
      continue

    let value = getCrewSkillValue(crewData.id, unit, categorySkill.memberName, categorySkill.skillName)
    res += getSkillCrewLevel(categorySkill.skillItem, value)
  }
  return res
}

function getSkillCategoryMaxCrewLevel(skillCategory, crewUnitType) {
  local crewLevel = 0
  foreach (categorySkill in skillCategory.skillItems)
    if (categorySkill.isVisible(crewUnitType))
      crewLevel += getSkillMaxCrewLevel(categorySkill.skillItem)
  return crewLevel
}

function getMaxSkillValue(memberName, skillName) {
  updateSkills()
  return maxSkillValueByMemberAndSkill?[memberName][skillName] ?? 0
}

function categoryHasNonGunnerSkills(skillCategory) {
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.memberName != "gunner")
      return true
  return false
}

function getCrewPoints(crewData) {
  return crewData?.skillPoints ?? 0
}

function isAffectedBySpecialization(memberName, skillName) {
  let skillItem = getCrewSkillItem(memberName, skillName)
  return skillItem?.useSpecializations ?? false
}

function isAffectedByLeadership(memberName, skillName) {
  let skillItem = getCrewSkillItem(memberName, skillName)
  return skillItem?.useLeadership ?? false
}

function getMinSkillsUnitRepairRank(unitRank) {
  let repairRanksBlk = get_skills_blk()?.repair_ranks
  if (!repairRanksBlk)
    return -1
  for (local i = 1; ; i++) {
    let rankValue = repairRanksBlk?["rank" + i]
    if (!rankValue)
      break
    if (rankValue >= unitRank)
      return i
  }
  return -1
}

return {
  getSkillCategories = getSkillCategories
  getSkillCategoryByName = getSkillCategoryByName
  getMeasureTypeBySkillParameterName = getMeasureTypeBySkillParameterName
  getSortOrderBySkillParameterName = getSortOrderBySkillParameterName
  getSkillCategoryCrewLevel = getSkillCategoryCrewLevel
  getSkillCategoryMaxCrewLevel = getSkillCategoryMaxCrewLevel
  getMaxSkillValue = getMaxSkillValue
  categoryHasNonGunnerSkills = categoryHasNonGunnerSkills
  getCrewPoints = getCrewPoints
  isAffectedBySpecialization = isAffectedBySpecialization
  isAffectedByLeadership = isAffectedByLeadership
  getMinSkillsUnitRepairRank = getMinSkillsUnitRepairRank
}
