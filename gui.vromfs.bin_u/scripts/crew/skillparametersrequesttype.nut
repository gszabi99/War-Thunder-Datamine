//-file:plus-string
from "%scripts/dagui_library.nut" import *
let enums = require("%sqStdLibs/helpers/enums.nut")
let { calc_crew_parameters } = require("unitCalculcation")
let { getMaxSkillValue } = require("%scripts/crew/crewSkills.nut")
let { crewSkillPages } = require("%scripts/crew/crew.nut")
let { get_skills_blk } = require("blkGetters")
let { cacheCrewData, getCachedCrewData } = require("%scripts/crew/crewShortCache.nut")
let { crewSpecTypes } = require("%scripts/crew/crewSpecType.nut")

let skillParametersRequestType = {
  types = []
}

skillParametersRequestType._getParameters <- function _getParameters(crewId, unit) {
  if (unit == null)
    return null

  let cacheUid = this.getCachePrefix() + "Current"
  local res = getCachedCrewData(crewId, unit, cacheUid)
  if (res)
    return res

  let values = this.getValues()
  res = calc_crew_parameters(crewId, values, unit.name)
  cacheCrewData(crewId, unit, cacheUid,  res)
  return res
}

skillParametersRequestType._getValues <- function _getValues() {
  return {}
}

skillParametersRequestType._getSelectedParameters <- function _getSelectedParameters(crewId, unit) {
  if (unit == null)
    return null
  let cacheUid = this.getCachePrefix() + "Selected"
  local res = getCachedCrewData(crewId, unit, cacheUid)
  if (res)
    return res

  let values = this.getValues()
  // Filling values request object with selected values if not set already.
  foreach (memberData in crewSkillPages) {
    let valueMemberName = memberData.id
    if (!(valueMemberName in values))
        values[valueMemberName] <- {}
    foreach (skillData in memberData.items) {
      let valueSkillName = skillData.name
      if (valueSkillName in values[valueMemberName])
        continue

      if ("newValue" in skillData)
        values[valueMemberName][valueSkillName] <- skillData.newValue
    }
  }
  res = calc_crew_parameters(crewId, values, unit.name)
  cacheCrewData(crewId, unit, cacheUid, res)
  return res
}

skillParametersRequestType._getCachePrefix <- function _getCachePrefix() {
  return $"skillParamRqst{this.typeName}"
}

skillParametersRequestType.template <- {
  getParameters = skillParametersRequestType._getParameters
  getValues = skillParametersRequestType._getValues
  getSelectedParameters = skillParametersRequestType._getSelectedParameters
  getCachePrefix = skillParametersRequestType._getCachePrefix
}

enums.addTypes(skillParametersRequestType, {

  CURRENT_VALUES = {}

  BASE_VALUES = {
    getValues = function () {
      let skillsBlk = get_skills_blk()
      let calcBlk = skillsBlk?.crew_skills_calc
      if (calcBlk == null)
        return {}

      let values = {}
      foreach (valueMemberName, memberBlk in calcBlk) {
        values[valueMemberName] <- {}
        foreach (valueSkillName, _skillBlk in memberBlk) {
          // Gunner's count is maxed-out as a base value.
          // Everything else is zero'ed.
          local value = 0
          if (valueMemberName == "gunner" && valueSkillName == "members")
            value = getMaxSkillValue("gunner", "members")
          values[valueMemberName][valueSkillName] <- value
        }
      }
      values.specialization <- crewSpecTypes.BASIC.code
      return values
    }
  }

  CURRENT_VALUES_NO_SPEC_AND_LEADERSHIP = {
    getValues = function () {
      return {
        specialization = crewSpecTypes.BASIC.code

        // This skill is same as leadership but related to aircraft unit type.
        gunner = { members = getMaxSkillValue("gunner", "members") }

        // This skill affects only tank unit type.
        commander = { leadership = 0 }

        // This skill affects only ship unit type.
        ship_commander = { leadership = 0 }
      }
    }
  }

  CURRENT_VALUES_NO_LEADERSHIP = {
    getValues = function () {
      return {
        // This skill is same as leadership but related to aircraft unit type.
        gunner = { members = getMaxSkillValue("gunner", "members") }

        // This skill affects only tank unit type.
        commander = { leadership = 0 }

        // This skill affects only ship unit type.
        ship_commander = { leadership = 0 }
      }
    }
  }

  MAX_VALUES = {
    getValues = function () {
      let skillsBlk = get_skills_blk()
      let calcBlk = skillsBlk?.crew_skills_calc
      if (calcBlk == null)
        return {}

      let values = {}
      foreach (valueMemberName, memberBlk in calcBlk) {
        values[valueMemberName] <- {}
        foreach (valueSkillName, _skillBlk in memberBlk) {
          let value = getMaxSkillValue(valueMemberName, valueSkillName)
          values[valueMemberName][valueSkillName] <- value
        }
      }
      let maxSpecType = crewSpecTypes.types.top().code
      values.specialization <- maxSpecType
      return values
    }
  }
}, null, "typeName")

return {
  skillParametersRequestType
}
