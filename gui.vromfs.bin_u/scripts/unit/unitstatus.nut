local canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && ::canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()

local function isShipWithoutPurshasedTorpedoes(unit)
{
  if (!unit?.isShip())
    return false

  local torpedoes = null
  if (::isAirHaveSecondaryWeapons(unit))
    torpedoes = ::u.search(unit.weapons, @(weapon) weapon.name == "torpedoes")    //!!! FIX ME: Need determine weapons by weapon mask. WeaponMask now available only for air

  if (!torpedoes)
    return false

  if (::g_weaponry_types.getUpgradeTypeByItem(torpedoes).getAmount(unit, torpedoes) > 0)
    return false

  return true
}

local function getBitStatus(unit, params = {})
{
  local isLocalState = params?.isLocalState ?? true
  local forceNotInResearch  = params?.forceNotInResearch ?? false
  local shopResearchMode    = params?.shopResearchMode ?? false
  local isSquadronResearchMode  = params?.isSquadronResearchMode ?? false

  local isMounted      = ::isUnitInSlotbar(unit)
  local isOwn          = unit.isBought()
  local isSquadVehicle = unit.isSquadronVehicle()
  local researched     = unit.isResearched()

  local isVehicleInResearch = unit.isInResearch() && !forceNotInResearch
  local canResearch         = ::canResearchUnit(unit)

  local unitExpGranted      = unit.getExp()
  local diffExp = isSquadVehicle
    ? ::min(::clan_get_exp(), ::getUnitReqExp(unit) - unitExpGranted)
    : (params?.diffExp ?? 0)
  local isLockedSquadronVehicle = isSquadVehicle && !::is_in_clan() && diffExp <= 0

  local bitStatus = 0
  if (!isLocalState || ::is_in_flight())
    bitStatus = bit_unit_status.owned
  else if (unit.isBroken())
    bitStatus = bit_unit_status.broken
  else if (isMounted)
    bitStatus = bit_unit_status.mounted
  else if (isOwn)
    bitStatus = bit_unit_status.owned
  else if (::canBuyUnit(unit) || ::canBuyUnitOnline(unit) || ::canBuyUnitOnMarketplace(unit))
    bitStatus = bit_unit_status.canBuy
  else if (isLockedSquadronVehicle && (!unit.unitType.canSpendGold() || !canBuyNotResearched(unit)))
    bitStatus = bit_unit_status.locked
  else if (researched)
    bitStatus = bit_unit_status.researched
  else if (isVehicleInResearch)
    bitStatus = bit_unit_status.inResearch
  else if (canResearch)
    bitStatus = bit_unit_status.canResearch
  else if (unit.isRented())
    bitStatus = bit_unit_status.inRent
  else
    bitStatus = bit_unit_status.locked

  if ((shopResearchMode
      && (isSquadVehicle || !(bitStatus &
        ( bit_unit_status.locked
          | bit_unit_status.canBuy
          | bit_unit_status.inResearch
          | bit_unit_status.canResearch))))
    || (isSquadronResearchMode && !isSquadVehicle))
  {
    bitStatus = bit_unit_status.disabled
  }

  return bitStatus
}

return {
  canBuyNotResearched = canBuyNotResearched
  isShipWithoutPurshasedTorpedoes = isShipWithoutPurshasedTorpedoes
  getBitStatus = getBitStatus
}