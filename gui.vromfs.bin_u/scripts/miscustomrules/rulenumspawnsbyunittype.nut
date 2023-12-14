//-file:plus-string
from "%scripts/dagui_natives.nut" import get_local_player_country
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { unitClassType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { registerMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let RuleBase = require("%scripts/misCustomRules/ruleBase.nut")
let { UnitLimitByUnitType, UnitLimitByUnitExpClass } = require("%scripts/misCustomRules/unitLimit.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")
let { get_ds_ut_name_unit_type } = require("%appGlobals/ranks_common_shared.nut")

let NumSpawnsByUnitType = class (RuleBase) {
  needLeftRespawnOnSlots = true
  customUnitRespawnsAllyListHeaderLocId  = "multiplayer/personalUnitsLeftHeader"

  restrictionRule = null
  knownUnitTypesList     = null
  allowedUnitTypesList   = null
  allowedUnitClassesList = null

  function getUnitLeftRespawns(unit, _teamDataBlk = null) {
    return this.getUnitLeftRespawnsByRestrictionRule(unit, this.getRestrictionRule())
  }

  //stateData is a table or blk
  function getUnitLeftRespawnsByRestrictionRule(unit, rule, stateData = null) {
    if (!unit)
      return 0
    stateData = stateData || this.getMyStateBlk()
    switch (rule) {
      case "type":
        return this.getUnitTypeLeftRespawns(getEsUnitType(unit), stateData)
      case "class":
        return this.getUnitClassLeftRespawns(unit.expClass.getExpClass(), stateData)
      case "type_and_class":
        return min(
          this.getUnitTypeLeftRespawns(getEsUnitType(unit), stateData),
          this.getUnitClassLeftRespawns(unit.expClass.getExpClass(), stateData)
        )
    }
    return 0
  }

  function hasCustomUnitRespawns() {
    return true
  }

  function getSpecialCantRespawnMessage(unit) {
    let leftRespawns = this.getUnitLeftRespawns(unit)
    if (leftRespawns)
      return null

    if (this.getUnitInitialRespawns(unit) == 0)
      return loc("not_available_aircraft")

    local icon = ""
    local name = ""
    switch (this.getRestrictionRule()) {
      case "type":
        icon = unit.unitType.fontIcon
        name = unit.unitType.getArmyLocName()
        break
      case "class":
        icon = unit.expClass.getFontIcon()
        name = unit.expClass.getName()
        break
      case "type_and_class":
        let needType = this.getUnitLeftRespawnsByRestrictionRule(unit, "type") <=
          this.getUnitLeftRespawnsByRestrictionRule(unit, "class")
        icon = needType ? unit.unitType.fontIcon         : unit.expClass.getFontIcon()
        name = needType ? unit.unitType.getArmyLocName() : unit.expClass.getName()
        break
    }

    return loc("multiplayer/noArmyRespawnsLeft",
                 {
                   armyIcon = colorize("userlogColoredText", icon)
                   armyName = name
                 })
  }

  function getCurCrewsRespawnMask() {
    local res = 0
    if (!this.getLeftRespawns())
      return res

    let crewsList = getCrewsListByCountry(get_local_player_country())
    let myStateBlk = this.getMyStateBlk()
    if (!myStateBlk)
      return (1 << crewsList.len()) - 1

    foreach (idx, crew in crewsList)
      if (this.getUnitLeftRespawns(::g_crew.getCrewUnit(crew)) != 0)
        res = res | (1 << idx)
    return res
  }

  function getRespawnInfoTextForUnit(unit) {
    return this.getRespawnInfoText(unit, this.getMyStateBlk())
  }

  function getRespawnInfoTextForUnitInfo(unit) {
    let cantRespawnMsg = this.getSpecialCantRespawnMessage(unit)
    return cantRespawnMsg ? colorize("@badTextColor", cantRespawnMsg) :
      loc("multiplayer/leftTeamUnit", { num = this.getUnitLeftRespawns(unit) })
  }

  //unit is Unit, or null to get info about all listed units
  //stateData is a table or blk
  function getRespawnInfoText(unit, stateData) {
    switch (this.getRestrictionRule()) {
      case "type":
        let res = []
        foreach (unitType in this.getAllowedUnitTypes()) {
          if (unit && unit.esUnitType != unitType.esUnitType)
            continue

          let resp = this.getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
          res.append(unitType.fontIcon + resp)
        }
        return colorize("@activeTextColor", loc("ui/comma").join(res, true))

      case "class":
        let res = []
        foreach (classType in this.getAllowedUnitClasses()) {
          if (unit && unit.expClass != classType)
            continue

          let resp = this.getUnitClassLeftRespawns(classType.getExpClass(), stateData)
          res.append(classType.getFontIcon() + resp)
        }
        return colorize("@activeTextColor", loc("ui/comma").join(res, true))

      case "type_and_class":
        let res = []
        foreach (unitType in this.getKnownUnitTypes()) {
          if (unit && unit.esUnitType != unitType.esUnitType)
            continue

          let typeResp = this.getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
          if (!typeResp)
            continue

          local classesText = []
          let classTypes = this.getAllowedUnitClasses().filter(@(c) c.unitTypeCode == unitType.esUnitType)
          foreach (classType in classTypes) {
            if (unit && unit.expClass != classType)
              continue

            let classResp = this.getUnitClassLeftRespawns(classType.getExpClass(), stateData)
            classesText.append(classType.getFontIcon() + classResp)
          }
          classesText = loc("ui/comma").join(classesText, true)

          local typeText = unitType.fontIcon + typeResp
          if (classesText != "") {
            if (unit)
              typeText = loc("ui/comma").join([ typeText, classesText ], true)
            else
              typeText += loc("ui/parentheses/space", { text = classesText })
          }
          res.append(typeText)
        }
        return colorize("@activeTextColor", loc("ui/comma").join(res, true))
    }
    return ""
  }

  function getUnitTypeLeftRespawns(esUnitType, stateData, isDsUnitType = false) { //stateData is a table or blk
    let respawns = stateData?[(isDsUnitType ? esUnitType : get_ds_ut_name_unit_type(esUnitType)) + "_numSpawn"] ?? 0
    return max(0, respawns) //dont have unlimited respawns
  }

  function getUnitClassLeftRespawns(expClass, stateData) { //stateData is a table or blk
    let respawns = stateData?[expClass] ?? 0
    return max(0, respawns) //dont have unlimited respawns
  }

  function getUnitInitialRespawns(unit) {
    return this.getUnitLeftRespawnsByRestrictionRule(unit, this.getRestrictionRule(), this.getCustomRulesBlk()?.ruleSet)
  }

  function getEventDescByRulesTbl(rulesTbl) {
    let baseRules = rulesTbl?.ruleSet ?? {}
    this.getRestrictionRule(baseRules)
    this.collectAllowedTypeAndClasses(baseRules)
    return loc("multiplayer/flyouts") + loc("ui/colon") + this.getRespawnInfoText(null, baseRules)
  }

  function calcFullUnitLimitsData(_isTeamMine = true) {
    let res = base.calcFullUnitLimitsData()

    local stateData = this.getMyStateBlk()
    if (u.isEmpty(stateData))
      stateData = this.getCustomRulesBlk()?.ruleSet

    let needUnitTypes   = this.getAllowedUnitTypes().len()   != 0
    let needUnitClasses = this.getAllowedUnitClasses().len() != 0

    foreach (unitType in this.getKnownUnitTypes()) {
      if (needUnitTypes) {
        let respLeft  = this.getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
        res.unitLimits.append(UnitLimitByUnitType(unitType.typeName, respLeft))
      }

      if (needUnitClasses) {
        let classTypes = this.getAllowedUnitClasses().filter(@(c) c.unitTypeCode == unitType.esUnitType)
        foreach (classType in classTypes) {
          let expClassName = classType.getExpClass()
          local respLeft  = this.getUnitClassLeftRespawns(expClassName, stateData)
          res.unitLimits.append(UnitLimitByUnitExpClass(expClassName, respLeft))
        }
      }
    }

    return res
  }

  function getRestrictionRule(baseRules = null) {
    if (!this.restrictionRule) {
      baseRules = baseRules || this.getCustomRulesBlk()?.ruleSet
      let value = baseRules?.restriction_rule ?? "type"
      let validValues = [ "type", "class", "type_and_class" ]
      this.restrictionRule = isInArray(value, validValues) ? value : "type"
    }
    return this.restrictionRule
  }

  function getKnownUnitTypes() {
    if (!this.knownUnitTypesList)
      this.collectAllowedTypeAndClasses()
    return this.knownUnitTypesList
  }

  function getAllowedUnitTypes() {
    if (!this.allowedUnitTypesList)
      this.collectAllowedTypeAndClasses()
    return this.allowedUnitTypesList
  }

  function getAllowedUnitClasses() {
    if (!this.allowedUnitClassesList)
      this.collectAllowedTypeAndClasses()
    return this.allowedUnitClassesList
  }

  function collectAllowedTypeAndClasses(baseRules = null) {
    baseRules  = baseRules || this.getCustomRulesBlk()?.ruleSet
    let rule = this.getRestrictionRule()
    let needUnitTypes   = isInArray(rule, [ "type",  "type_and_class" ])
    let needUnitClasses = isInArray(rule, [ "class", "type_and_class" ])

    this.knownUnitTypesList     = []
    this.allowedUnitTypesList   = []
    this.allowedUnitClassesList = []

    let checkedDsUnitTypes = []

    foreach (unitType in unitTypes.types) {
      if (!unitType.isAvailable())
        continue

      let dsUnitType = get_ds_ut_name_unit_type(unitType.esUnitType)
      if (isInArray(dsUnitType, checkedDsUnitTypes))
        continue
      checkedDsUnitTypes.append(dsUnitType)

      if (needUnitTypes)
        if (this.getUnitTypeLeftRespawns(unitType.esUnitType, baseRules) > 0) {
          this.allowedUnitTypesList.append(unitType)
          u.appendOnce(unitType, this.knownUnitTypesList)
        }

      if (needUnitClasses) {
        let unitTypeClassTypes = unitClassType.types.filter(@(c) c.unitTypeCode == unitType.esUnitType)
        foreach (classType in unitTypeClassTypes)
          if (this.getUnitClassLeftRespawns(classType.getExpClass(), baseRules) > 0) {
            u.appendOnce(classType, this.allowedUnitClassesList)
            u.appendOnce(unitType, this.knownUnitTypesList)
          }
      }
    }
  }
}

registerMissionRules("NumSpawnsByUnitType", NumSpawnsByUnitType)
