from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

::mission_rules.SharedPool <- class extends ::mission_rules.Base
{
  function getMaxRespawns()
  {
    return getTblValue("playerMaxSpawns", this.getMyTeamDataBlk(), ::RESPAWNS_UNLIMITED)
  }

  function getLeftRespawns()
  {
    let maxRespawns = getMaxRespawns()
    if (maxRespawns == ::RESPAWNS_UNLIMITED)
      return ::RESPAWNS_UNLIMITED

    let spawnsBlk = getTblValue("spawns", this.getMisStateBlk())
    let usedSpawns = getTblValue(::my_user_id_str, spawnsBlk, 0)
    return max(0, maxRespawns - usedSpawns)
  }

  function getRespawnInfoTextForUnit(unit)
  {
    let res = base.getRespawnInfoTextForUnit(unit)
    if (!unit)
      return res

    let limitText = getExpClassLimitTextByUnit(unit)
    return res + ((res.len() && limitText.len()) ? loc("ui/comma") : "") + limitText
  }

  function getSpecialCantRespawnMessage(unit)
  {
    let expClassName = unit.expClass.getExpClass()
    let activeAtOnce = getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce != ::RESPAWNS_UNLIMITED
        && activeAtOnce <= getCurActiveExpClassAmount(expClassName))
      return loc("multiplayer/cant_spawn/all_active_at_once",
                   {
                     name = colorize("activeTextColor", unit.expClass.getName())
                     amountText = getExpClassLimitTextByUnit(unit)
                   })

    let leftRespawns = this.getUnitLeftRespawns(unit)
    if (!leftRespawns)
      return loc("multiplayer/noTeamUnitLeft", { unitName = colorize("userlogColoredText", ::getUnitName(unit)) })

    return null
  }

  function getExpClassLimitTextByUnit(unit)
  {
    let expClassName = unit.expClass.getExpClass()
    let activeAtOnce = getActiveAtOnceExpClass(expClassName)
    if (activeAtOnce == ::RESPAWNS_UNLIMITED)
      return ""

    let limit = ::g_unit_limit_classes.ActiveLimitByUnitExpClass(
                    expClassName,
                    activeAtOnce,
                    { distributed = getCurActiveExpClassAmount(expClassName) }
                 )
    return limit.getText()
  }

  function hasCustomUnitRespawns()
  {
    let myTeamDataBlk = this.getMyTeamDataBlk()
    return "limitedUnits" in myTeamDataBlk || "unlimitedUnits" in myTeamDataBlk
           || "limitedClasses" in myTeamDataBlk || "limitedTags" in myTeamDataBlk
           || "limitedActiveClasses" in myTeamDataBlk
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    if (!unit)
      return 0

    local res = ::RESPAWNS_UNLIMITED
    let limitedClasses = getTblValue("limitedClasses", teamDataBlk)
    if (::u.isDataBlock(limitedClasses))
    {
      let total = limitedClasses.paramCount()
      for(local i = 0; i < total; i++)
      {
        let expClassName = limitedClasses.getParamName(i)
        let expClass = getUnitClassTypeByExpClass(expClassName)
        if (expClass != unit.expClass)
          continue

        res = limitedClasses.getParamValue(i)
        break
      }
    }

    let limitedTags = getTblValue("limitedTags", teamDataBlk)
    if (::u.isDataBlock(limitedTags))
    {
      let total = limitedTags.paramCount()
      for(local i = 0; i < total; i++)
        if (isInArray(limitedTags.getParamName(i), unit.tags))
          res = this.minRespawns(res, limitedTags.getParamValue(i))
    }

    let limitedUnits = getTblValue("limitedUnits", teamDataBlk)
    res = this.minRespawns(res, getTblValue(unit.name, limitedUnits, ::RESPAWNS_UNLIMITED))

    if (res != ::RESPAWNS_UNLIMITED)
      return res

    let unlimitedUnits = getTblValue("unlimitedUnits", teamDataBlk)
    if (unlimitedUnits && !(unit.name in unlimitedUnits))
      res = 0
    return res
  }

  function calcFullUnitLimitsData(_isTeamMine = true)
  {
    let res = base.calcFullUnitLimitsData()

    let myTeamDataBlk = this.getMyTeamDataBlk()
    res.defaultUnitRespawnsLeft = "unlimitedUnits" in myTeamDataBlk ? 0 : ::RESPAWNS_UNLIMITED

    let limitedClasses = getTblValue("limitedClasses", myTeamDataBlk)
    if (::u.isDataBlock(limitedClasses))
    {
      let total = limitedClasses.paramCount()
      for(local i = 0; i < total; i++)
      {
        let expClassName = limitedClasses.getParamName(i)
        if (getUnitClassTypeByExpClass(expClassName).isValid())
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitExpClass(expClassName, limitedClasses.getParamValue(i)))
      }
    }

    let limitedTags = getTblValue("limitedTags", myTeamDataBlk)
    if (::u.isDataBlock(limitedTags))
    {
      let total = limitedTags.paramCount()
      for(local i = 0; i < total; i++)
      {
        let tag = limitedTags.getParamName(i)
        let respLeft = limitedTags.getParamValue(i)

        let unitType = unitTypes.getByTag(tag)
        if (unitType != unitTypes.INVALID)
        {
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitType(unitType.typeName, respLeft))
          continue
        }

        let role = ::g_string.cutPrefix(tag, "type_", null)
        if (role)
          res.unitLimits.append(::g_unit_limit_classes.LimitByUnitRole(role, respLeft))
      }
    }

    let unitsGroups = this.getUnitsGroups()
    local blk = getTblValue("limitedUnits", myTeamDataBlk)
    if (::u.isDataBlock(blk))
      for(local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(::g_unit_limit_classes.LimitByUnitName(blk.getParamName(i), blk.getParamValue(i),
          { nameLocId = unitsGroups?[blk.getParamName(i)] }))

    blk = getTblValue("unlimitedUnits", myTeamDataBlk)
    if (::u.isDataBlock(blk))
      for(local i = 0; i < blk.paramCount(); i++)
        res.unitLimits.append(::g_unit_limit_classes.LimitByUnitName(blk.getParamName(i), ::RESPAWNS_UNLIMITED,
          { nameLocId = unitsGroups?[blk.getParamName(i)] }))

    let activeLimitsBlk = getTblValue("limitedActiveClasses", myTeamDataBlk)
    if (::u.isDataBlock(activeLimitsBlk))
    {
      let limitByExpClassName = {}
      let total = activeLimitsBlk.paramCount()
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
          limitByExpClassName[expClassName] = min(value, limitByExpClassName[expClassName])
        else
          limitByExpClassName[expClassName] <- value
      }

      let activeBlk = getTblValue("activeClasses", myTeamDataBlk)
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
    let activeLimitsBlk = getTblValue("limitedActiveClasses", this.getMyTeamDataBlk())
    if (!activeLimitsBlk)
      return res

    res = this.minRespawns(res, getTblValue(expClassName, activeLimitsBlk, ::RESPAWNS_UNLIMITED))
    let percent = getTblValue(expClassName + "_perc", activeLimitsBlk, -1)
    if (percent >= 0)
      res = this.minRespawns(res, getAmountByTeamPercent(percent))
    return res
  }

  function getCurActiveExpClassAmount(expClassName)
  {
    let activeBlk = getTblValue("activeClasses", this.getMyTeamDataBlk())
    return getTblValue(expClassName, activeBlk, 0)
  }
}