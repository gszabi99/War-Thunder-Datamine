local { unitClassType } = require("scripts/unit/unitClassType.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

class ::mission_rules.NumSpawnsByUnitType extends ::mission_rules.Base
{
  needLeftRespawnOnSlots = true
  customUnitRespawnsAllyListHeaderLocId  = "multiplayer/personalUnitsLeftHeader"

  restrictionRule = null
  knownUnitTypesList     = null
  allowedUnitTypesList   = null
  allowedUnitClassesList = null

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    return getUnitLeftRespawnsByRestrictionRule(unit, getRestrictionRule())
  }

  //stateData is a table or blk
  function getUnitLeftRespawnsByRestrictionRule(unit, rule, stateData = null)
  {
    if (!unit)
      return 0
    stateData = stateData || getMyStateBlk()
    switch (rule)
    {
      case "type":
        return getUnitTypeLeftRespawns(::get_es_unit_type(unit), stateData)
      case "class":
        return getUnitClassLeftRespawns(unit.expClass.getExpClass(), stateData)
      case "type_and_class":
        return ::min(
          getUnitTypeLeftRespawns(::get_es_unit_type(unit), stateData),
          getUnitClassLeftRespawns(unit.expClass.getExpClass(), stateData)
        )
    }
    return 0
  }

  function hasCustomUnitRespawns()
  {
    return true
  }

  function getSpecialCantRespawnMessage(unit)
  {
    local leftRespawns = getUnitLeftRespawns(unit)
    if (leftRespawns)
      return null

    if (getUnitInitialRespawns(unit) == 0)
      return ::loc("not_available_aircraft")

    local icon = ""
    local name = ""
    switch (getRestrictionRule())
    {
      case "type":
        icon = unit.unitType.fontIcon
        name = unit.unitType.getArmyLocName()
        break
      case "class":
        icon = unit.expClass.getFontIcon()
        name = unit.expClass.getName()
        break
      case "type_and_class":
        local needType = getUnitLeftRespawnsByRestrictionRule(unit, "type") <=
          getUnitLeftRespawnsByRestrictionRule(unit, "class")
        icon = needType ? unit.unitType.fontIcon         : unit.expClass.getFontIcon()
        name = needType ? unit.unitType.getArmyLocName() : unit.expClass.getName()
        break
    }

    return ::loc("multiplayer/noArmyRespawnsLeft",
                 {
                   armyIcon = ::colorize("userlogColoredText", icon)
                   armyName = name
                 })
  }

  function getCurCrewsRespawnMask()
  {
    local res = 0
    if (!getLeftRespawns())
      return res

    local crewsList = ::get_crews_list_by_country(::get_local_player_country())
    local myStateBlk = getMyStateBlk()
    if (!myStateBlk)
      return (1 << crewsList.len()) - 1

    foreach(idx, crew in crewsList)
      if (getUnitLeftRespawns(::g_crew.getCrewUnit(crew)) != 0)
        res = res | (1 << idx)
    return res
  }

  function getRespawnInfoTextForUnit(unit)
  {
    return getRespawnInfoText(unit, getMyStateBlk())
  }

  function getRespawnInfoTextForUnitInfo(unit)
  {
    local cantRespawnMsg = getSpecialCantRespawnMessage(unit)
    return cantRespawnMsg ? ::colorize("@badTextColor", cantRespawnMsg) :
      ::loc("multiplayer/leftTeamUnit", { num = getUnitLeftRespawns(unit) })
  }

  //unit is Unit, or null to get info about all listed units
  //stateData is a table or blk
  function getRespawnInfoText(unit, stateData)
  {
    switch(getRestrictionRule())
    {
      case "type":
        local res = []
        foreach(unitType in getAllowedUnitTypes())
        {
          if (unit && unit.esUnitType != unitType.esUnitType)
            continue

          local resp = getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
          res.append(unitType.fontIcon + resp)
        }
        return ::colorize("@activeTextColor", ::g_string.implode(res, ::loc("ui/comma")))

      case "class":
        local res = []
        foreach(classType in getAllowedUnitClasses())
        {
          if (unit && unit.expClass != classType)
            continue

          local resp = getUnitClassLeftRespawns(classType.getExpClass(), stateData)
          res.append(classType.getFontIcon() + resp)
        }
        return ::colorize("@activeTextColor", ::g_string.implode(res, ::loc("ui/comma")))

      case "type_and_class":
        local res = []
        foreach(unitType in getKnownUnitTypes())
        {
          if (unit && unit.esUnitType != unitType.esUnitType)
            continue

          local typeResp = getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
          if (!typeResp)
            continue

          local classesText = []
          local classTypes = ::u.filter(getAllowedUnitClasses(), @(c) c.unitTypeCode == unitType.esUnitType)
          foreach (classType in classTypes)
          {
            if (unit && unit.expClass != classType)
              continue

            local classResp = getUnitClassLeftRespawns(classType.getExpClass(), stateData)
            classesText.append(classType.getFontIcon() + classResp)
          }
          classesText = ::g_string.implode(classesText, ::loc("ui/comma"))

          local typeText = unitType.fontIcon + typeResp
          if (classesText != "")
          {
            if (unit)
              typeText = ::g_string.implode([ typeText, classesText ], ::loc("ui/comma"))
            else
              typeText += ::loc("ui/parentheses/space", { text = classesText })
          }
          res.append(typeText)
        }
        return ::colorize("@activeTextColor", ::g_string.implode(res, ::loc("ui/comma")))
    }
    return ""
  }

  function getUnitTypeLeftRespawns(esUnitType, stateData, isDsUnitType = false) //stateData is a table or blk
  {
    local respawns = stateData?[(isDsUnitType ? esUnitType : ::get_ds_ut_name_unit_type(esUnitType)) + "_numSpawn"] ?? 0
    return ::max(0, respawns) //dont have unlimited respawns
  }

  function getUnitClassLeftRespawns(expClass, stateData) //stateData is a table or blk
  {
    local respawns = stateData?[expClass] ?? 0
    return ::max(0, respawns) //dont have unlimited respawns
  }

  function getUnitInitialRespawns(unit)
  {
    return getUnitLeftRespawnsByRestrictionRule(unit, getRestrictionRule(), getCustomRulesBlk()?.ruleSet)
  }

  function getEventDescByRulesTbl(rulesTbl)
  {
    local baseRules = rulesTbl?.ruleSet ?? {}
    getRestrictionRule(baseRules)
    collectAllowedTypeAndClasses(baseRules)
    return ::loc("multiplayer/flyouts") + ::loc("ui/colon") + getRespawnInfoText(null, baseRules)
  }

  function calcFullUnitLimitsData(isTeamMine = true)
  {
    local res = base.calcFullUnitLimitsData()

    local stateData = getMyStateBlk()
    if (::u.isEmpty(stateData))
      stateData = getCustomRulesBlk()?.ruleSet

    local needUnitTypes   = getAllowedUnitTypes().len()   != 0
    local needUnitClasses = getAllowedUnitClasses().len() != 0

    foreach(unitType in getKnownUnitTypes())
    {
      if (needUnitTypes)
      {
        local respLeft  = getUnitTypeLeftRespawns(unitType.esUnitType, stateData)
        res.unitLimits.append(::g_unit_limit_classes.LimitByUnitType(unitType.typeName, respLeft))
      }

      if (needUnitClasses)
      {
        local classTypes = ::u.filter(getAllowedUnitClasses(), @(c) c.unitTypeCode == unitType.esUnitType)
        foreach(classType in classTypes)
        {
          local expClassName = classType.getExpClass()
          local respLeft  = getUnitClassLeftRespawns(expClassName, stateData)
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitExpClass(expClassName, respLeft))
        }
      }
    }

    return res
  }

  function getRestrictionRule(baseRules = null)
  {
    if (!restrictionRule)
    {
      baseRules = baseRules || getCustomRulesBlk()?.ruleSet
      local value = baseRules?.restriction_rule ?? "type"
      local validValues = [ "type", "class", "type_and_class" ]
      restrictionRule = ::isInArray(value, validValues) ? value : "type"
    }
    return restrictionRule
  }

  function getKnownUnitTypes()
  {
    if (!knownUnitTypesList)
      collectAllowedTypeAndClasses()
    return knownUnitTypesList
  }

  function getAllowedUnitTypes()
  {
    if (!allowedUnitTypesList)
      collectAllowedTypeAndClasses()
    return allowedUnitTypesList
  }

  function getAllowedUnitClasses()
  {
    if (!allowedUnitClassesList)
      collectAllowedTypeAndClasses()
    return allowedUnitClassesList
  }

  function collectAllowedTypeAndClasses(baseRules = null)
  {
    baseRules  = baseRules || getCustomRulesBlk()?.ruleSet
    local rule = getRestrictionRule()
    local needUnitTypes   = ::isInArray(rule, [ "type",  "type_and_class" ])
    local needUnitClasses = ::isInArray(rule, [ "class", "type_and_class" ])

    knownUnitTypesList     = []
    allowedUnitTypesList   = []
    allowedUnitClassesList = []

    local checkedDsUnitTypes = []

    foreach(unitType in unitTypes.types)
    {
      if (!unitType.isAvailable())
        continue

      local dsUnitType = ::get_ds_ut_name_unit_type(unitType.esUnitType)
      if (::isInArray(dsUnitType, checkedDsUnitTypes))
        continue
      checkedDsUnitTypes.append(dsUnitType)

      if (needUnitTypes)
        if (getUnitTypeLeftRespawns(unitType.esUnitType, baseRules) > 0)
        {
          allowedUnitTypesList.append(unitType)
          ::u.appendOnce(unitType, knownUnitTypesList)
        }

      if (needUnitClasses)
      {
        local unitTypeClassTypes = ::u.filter(unitClassType.types, @(c) c.unitTypeCode == unitType.esUnitType)
        foreach(classType in unitTypeClassTypes)
          if (getUnitClassLeftRespawns(classType.getExpClass(), baseRules) > 0)
          {
            ::u.appendOnce(classType, allowedUnitClassesList)
            ::u.appendOnce(unitType, knownUnitTypesList)
          }
      }
    }
  }
}
