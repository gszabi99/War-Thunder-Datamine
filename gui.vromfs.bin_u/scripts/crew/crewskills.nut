const DEFAULT_MAX_SKILL_LEVEL = 50

local skillCategories = []
local skillCategoryByName = {}
local skillsLoaded = false
local maxSkillValueByMemberAndSkill = {}
local skillParameterInfo = {} //skillName = { measureType = <string>, sortOrder = <int> }

local function createCategory(categoryName) {
  local category = {
    categoryName = categoryName
    skillItems = []
    crewUnitTypeMask = 0
  }
  skillCategories.append(category)
  skillCategoryByName[categoryName] <- category
  return category
}

local function loadSkills() {
  ::load_crew_skills_once()
  local skillsBlk = ::get_skills_blk()
  skillCategories.clear()
  skillCategoryByName.clear()
  maxSkillValueByMemberAndSkill.clear()
  local calcBlk = skillsBlk?.crew_skills_calc
  if (calcBlk == null)
    return
  foreach (memberName, memberBlk in calcBlk)
  {
    if (!::u.isDataBlock(memberBlk))
      continue

    maxSkillValueByMemberAndSkill[memberName] <- {}
    foreach (skillName, skillBlk in memberBlk)
    {
      if (!::u.isDataBlock(skillBlk))
        continue // Not actually a skill blk.
      local skillItem = ::g_crew.getSkillItem(memberName, skillName)
      if (!skillItem)
        continue

      //!!FIX ME: need to full use the same skillItems as in g_crew instead of duplicate code
      // Max skill value
      local maxSkillValue = skillBlk?.max_skill_level ?? DEFAULT_MAX_SKILL_LEVEL
      maxSkillValueByMemberAndSkill[memberName][skillName] <- maxSkillValue

      // Skill category
      local categoryName = skillBlk?.skill_category
      if (categoryName == null)
        continue

      local skillCategory = skillCategoryByName?[categoryName]
      if (skillCategory == null)
        skillCategory = createCategory(categoryName)

      local categorySkill = {
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
  local typesBlk = skillsBlk?.measure_type_by_skill_parameter
  if (typesBlk != null)
  {
    local sortOrder = 0
    foreach (parameterName, typeName in typesBlk)
      skillParameterInfo[parameterName] <- {
        measureType = ::g_measure_type.getTypeByName(typeName, true)
        sortOrder = ++sortOrder
      }
  }
}

local function updateSkills() {
  if (!skillsLoaded)
  {
    skillsLoaded = true
    loadSkills()
  }
}

local function getSkillCategories() {
  updateSkills()
  return skillCategories
}

local function getSkillCategoryByName(categoryName) {
  updateSkills()
  return skillCategoryByName?[categoryName]
}

local function getSkillParameterInfo(parameterName) {
  updateSkills()
  return skillParameterInfo?[parameterName]
}

local function getMeasureTypeBySkillParameterName(parameterName) {
  return getSkillParameterInfo(parameterName)?.measureType ?? ::g_measure_type.UNKNOWN
}

local function getSortOrderBySkillParameterName(parameterName) {
  return getSkillParameterInfo(parameterName)?.sortOrder ?? 0
}

local function getSkillValue(crewId, unit, memberName, skillName) {
  local unitCrewData = ::g_unit_crew_cache.getUnitCrewDataById(crewId, unit)
  return unitCrewData?[memberName][skillName] ?? 0
}

local function getSkillCategoryCrewLevel(crewData, unit, skillCategory, crewUnitType) {
  local res = 0
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (!categorySkill.isVisible(crewUnitType))
      continue

    local value = getSkillValue(crewData.id, unit, categorySkill.memberName, categorySkill.skillName)
    res += ::g_crew.getSkillCrewLevel(categorySkill.skillItem, value)
  }
  return res
}

local function getSkillCategoryMaxCrewLevel(skillCategory, crewUnitType) {
  local crewLevel = 0
  foreach (categorySkill in skillCategory.skillItems)
    if (categorySkill.isVisible(crewUnitType))
      crewLevel += ::g_crew.getSkillMaxCrewLevel(categorySkill.skillItem)
  return crewLevel
}

local function getMaxSkillValue(memberName, skillName) {
  updateSkills()
  return maxSkillValueByMemberAndSkill?[memberName][skillName] ?? 0
}

local function categoryHasNonGunnerSkills(skillCategory) {
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.memberName != "gunner")
      return true
  return false
}

local function getCrewPoints(crewData) {
  return crewData?.skillPoints ?? 0
}

local function isAffectedBySpecialization(memberName, skillName) {
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return skillItem?.useSpecializations ?? false
}

local function isAffectedByLeadership(memberName, skillName) {
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return skillItem?.useLeadership ?? false
}

local function getMinSkillsUnitRepairRank(unitRank) {
  local repairRanksBlk = ::get_skills_blk()?.repair_ranks
  if (!repairRanksBlk)
    return -1
  for(local i = 1; ; i++)
  {
    local rankValue = repairRanksBlk?["rank" + i]
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
  getSkillValue = getSkillValue
  getSkillCategoryCrewLevel = getSkillCategoryCrewLevel
  getSkillCategoryMaxCrewLevel = getSkillCategoryMaxCrewLevel
  getMaxSkillValue = getMaxSkillValue
  categoryHasNonGunnerSkills = categoryHasNonGunnerSkills
  getCrewPoints = getCrewPoints
  isAffectedBySpecialization = isAffectedBySpecialization
  isAffectedByLeadership = isAffectedByLeadership
  getMinSkillsUnitRepairRank = getMinSkillsUnitRepairRank
}
