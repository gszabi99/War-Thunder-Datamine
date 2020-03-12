class ::WwOperationModel
{
  armies = null
  unitClassFlyoutRange = null
  groupAirArmiesLimit = 0

  maxUniqueUnitsOnFlyout = 0

  constructor()
  {
    armies = ::WwOperationArmies()
    maxUniqueUnitsOnFlyout = ::g_world_war.getWWConfigurableValue("maxUniqueUnitsOnFlyout", 0)
    groupAirArmiesLimit = ::g_world_war.getWWConfigurableValue("airArmiesLimitPerArmyGroup", 0)
  }

  function update()
  {
    armies.statusUpdate()
  }

  function getGroupAirArmiesLimit()
  {
    return groupAirArmiesLimit
  }

  function getUnitsFlyoutRange()
  {
    if (!unitClassFlyoutRange)
      unitClassFlyoutRange = {
        [WW_UNIT_CLASS.COMBINED] = {
          [WW_UNIT_CLASS.FIGHTER] = ::Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyFightersMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyFightersMax", 0)
          ),
          [WW_UNIT_CLASS.BOMBER] = ::Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateCombinedArmyAttackersMax", 0)
          )
        },
        [WW_UNIT_CLASS.FIGHTER] = {
          [WW_UNIT_CLASS.FIGHTER] = ::Point2(
            ::g_world_war.getWWConfigurableValue("airfieldCreateFightersArmyMin", 0),
            ::g_world_war.getWWConfigurableValue("airfieldCreateFightersArmyMax", 0)
          )
        },
        [WW_UNIT_CLASS.BOMBER] = {
          [WW_UNIT_CLASS.BOMBER] = ::Point2(0,0)
        }
      }

    return unitClassFlyoutRange
  }

  function getQuantityToFlyOut(bit, mask, range = null)
  {
    if (!range)
      range = getUnitsFlyoutRange()

    if (!(bit & mask) || !(mask in range))
      return ::Point2(0, 0)
    return range[mask][bit]
  }
}