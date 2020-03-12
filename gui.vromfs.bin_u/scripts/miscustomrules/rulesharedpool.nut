local { getUnitClassTypeByExpClass } = require("scripts/unit/unitClassType.nut")

class ::mission_rules.SharedPool extends ::mission_rules.Base
{
  function getMaxRespawns()
  {
    return ::getTblValue("playerMaxSpawns", getMyTeamDataBlk(), ::RESPAWNS_UNLIMITED)
  }

  function getLeftRespawns()
  {
    local maxRespawns = getMaxRespawns()
    if (maxRespawns == ::RESPAWNS_UNLIMITED)
      return ::RESPAWNS_UNLIMITED

    local spawnsBlk = ::getTblValue("spawns", getMisStateBlk())
    local usedSpawns = ::getTblValue(::my_user_id_str, spawnsBlk, 0)
    return ::max(0, maxRespawns - usedSpawns)
  }

  function getRespawnInfoTextForUnit(unit)
  {
    local res = base.getRespawnInfoTextForUnit(unit)
    if (!unit)
      return res

    local limitText = getExpClassLimitTextByUnit(unit)
    return res + ((res.len() && limitText.len()) ? ::loc("ui/comma") : "") + limitText
  }

  function getSpecialCantRespawnMessage(unit)
  {
    local expClassName = unit.expClass.getExpClass()
    local activeAtOnce = getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce != ::RESPAWNS_UNLIMITED
        && activeAtOnce <= getCurActiveExpClassAmount(expClassName))
      return ::loc("multiplayer/cant_spawn/all_active_at_once",
                   {
                     name = ::colorize("activeTextColor", unit.expClass.getName())
                     amountText = getExpClassLimitTextByUnit(unit)
                   })

    local leftRespawns = getUnitLeftRespawns(unit)
    if (!leftRespawns)
      return ::loc("multiplayer/noTeamUnitLeft", { unitName = ::colorize("userlogColoredText", ::getUnitName(unit)) })

    return null
  }

  function getExpClassLimitTextByUnit(unit)
  {
    local expClassName = unit.expClass.getExpClass()
    local activeAtOnce = getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce == ::RESPAWNS_UNLIMITED)
      return ""

    local limit = ::g_unit_limit_classes.ActiveLimitByUnitExpClass(
                    expClassName,
                    activeAtOnce,
                    { distributed = getCurActiveExpClassAmount(expClassName) }
                 )
    return limit.getText()
  }

  function hasCustomUnitRespawns()
  {
    local myTeamDataBlk = getMyTeamDataBlk()
    return "limitedUnits" in myTeamDataBlk || "unlimitedUnits" in myTeamDataBlk
           || "limitedClasses" in myTeamDataBlk || "limitedTags" in myTeamDataBlk
           || "limitedActiveClasses" in myTeamDataBlk
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    if (!unit)
      return 0

    local res = ::RESPAWNS_UNLIMITED
    local limitedClasses = ::getTblValue("limitedClasses", teamDataBlk)
    if (::u.isDataBlock(limitedClasses))
    {
      local total = limitedClasses.paramCount()
      for(local i = 0; i < total; i++)
      {
        local expClassName = limitedClasses.getParamName(i)
        local expClass = getUnitClassTypeByExpClass(expClassName)
        if (expClass != unit.expClass)
          continue

        res = limitedClasses.getParamValue(i)
        break
      }
    }

    local limitedTags = ::getTblValue("limitedTags", teamDataBlk)
    if (::u.isDataBlock(limitedTags))
    {
      local total = limitedTags.paramCount()
      for(local i = 0; i < total; i++)
        if (::isInArray(limitedTags.getParamName(i), unit.tags))
          res = minRespawns(res, limitedTags.getParamValue(i))
    }

    local limitedUnits = ::getTblValue("limitedUnits", teamDataBlk)
    res = minRespawns(res, ::getTblValue(unit.name, limitedUnits, ::RESPAWNS_UNLIMITED))

    if (res != ::RESPAWNS_UNLIMITED)
      return res

    local unlimitedUnits = ::getTblValue("unlimitedUnits", teamDataBlk)
    if (unlimitedUnits && !(unit.name in unlimitedUnits))
      res = 0
    return res
  }

  function calcFullUnitLimitsData(isTeamMine = true)
  {
    local res = base.calcFullUnitLimitsData()

    local myTeamDataBlk = getMyTeamDataBlk()
    res.defaultUnitRespawnsLeft = "unlimitedUnits" in myTeamDataBlk ? 0 : ::RESPAWNS_UNLIMITED

    local limitedClasses = ::getTblValue("limitedClasses", myTeamDataBlk)
    if (::u.isDataBlock(limitedClasses))
    {
      local total = limitedClasses.paramCount()
      for(local i = 0; i < total; i++)
      {
        local expClassName = limitedClasses.getParamName(i)
        if (getUnitClassTypeByExpClass(expClassName).isValid())
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitExpClass(expClassName, limitedClasses.getParamValue(i)))
      }
    }

    local limitedTags = ::getTblValue("limitedTags", myTeamDataBlk)
    if (::u.isDataBlock(limitedTags))
    {
      local total = limitedTags.paramCount()
      for(local i = 0; i < total; i++)
      {
        local tag = limitedTags.getParamName(i)
        local respLeft = limitedTags.getParamValue(i)

        local unitType = ::g_unit_type.getByTag(tag)
        if (unitType != ::g_unit_type.INVALID)
        {
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitType(unitType.typeName, respLeft))
          continue
        }

        local role = ::g_string.cutPrefix(tag, "type_", null)
        if (role)
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitRole(role, respLeft))
      }
    }

    local unitsGroups = getUnitsGroups()
    local blk = ::getTblValue("limitedUnits", myTeamDataBlk)
    if (::u.isDataBlock(blk))
      for(local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(::g_unit_limit_classes.LimitByUnitName(blk.getParamName(i), blk.getParamValue(i),
          { nameLocId = unitsGroups?[blk.getParamName(i)] }))

    blk = ::getTblValue("unlimitedUnits", myTeamDataBlk)
    if (::u.isDataBlock(blk))
      for(local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(::g_unit_limit_classes.LimitByUnitName(blk.getParamName(i), ::RESPAWNS_UNLIMITED,
          { nameLocId = unitsGroups?[blk.getParamName(i)] }))

    local activeLimitsBlk = ::getTblValue("limitedActiveClasses", myTeamDataBlk)
    if (::u.isDataBlock(activeLimitsBlk))
    {
      local limitByExpClassName = {}
      local total = activeLimitsBlk.paramCount()
      for(local i = 0; i < total; i++)
      {
        local value = activeLimitsBlk.getParamValue(i)
        local expClassName = activeLimitsBlk.getParamName(i)
        if (::g_string.endsWith(expClassName, "_perc"))
        {
          value = getAmountByTeamPercent(value)
          expClassName = expClassName.slice(0, expClassName.len() - 5)
        }
        if (expClassName in limitByExpClassName)
          limitByExpClassName[expClassName] = ::min(value, limitByExpClassName[expClassName])
        else
          limitByExpClassName[expClassName] <- value
      }

      local activeBlk = ::getTblValue("activeClasses", myTeamDataBlk)
      foreach(expClassName, maxAmount in limitByExpClassName)
        res.unitLimits.append(
          ::g_unit_limit_classes.ActiveLimitByUnitExpClass(
            expClassName,
            maxAmount,
            { distributed = activeBlk?[expClassName] ?? 0 }
          )
        )
    }

    return res
  }

  function getAmountByTeamPercent(percent)
  {
    return ((percent * ::get_mplayers_count(::get_mp_local_team(), false)) / 100).tointeger()
  }

  function getActiveAtOnceExpClass(expClassName)
  {
    local res = ::RESPAWNS_UNLIMITED
    local activeLimitsBlk = ::getTblValue("limitedActiveClasses", getMyTeamDataBlk())
    if (!activeLimitsBlk)
      return res

    res = minRespawns(res, ::getTblValue(expClassName, activeLimitsBlk, ::RESPAWNS_UNLIMITED))
    local percent = ::getTblValue(expClassName + "_perc", activeLimitsBlk, -1)
    if (percent >= 0)
      res = minRespawns(res, getAmountByTeamPercent(percent))
    return res
  }

  function getCurActiveExpClassAmount(expClassName)
  {
    local activeBlk = ::getTblValue("activeClasses", getMyTeamDataBlk())
    return ::getTblValue(expClassName, activeBlk, 0)
  }
}