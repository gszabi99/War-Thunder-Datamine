from "%scripts/unit/unitInfo.nut" import bit_unit_status, getUnitReqExp
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit
from "%scripts/unit/unitStatus.nut" import canResearchUnit, canBuyNotResearched
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace
from "%scripts/unit/unitEvents.nut" import hasUnitEvent
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "gameplayBinding" import isInFlight
from "%scripts/dagui_natives.nut" import clan_get_exp
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

function getBitStatus(unit, params = {}) {
  let isLocalState = params?.isLocalState ?? true
  let forceNotInResearch  = params?.forceNotInResearch ?? false
  let shopResearchMode    = params?.shopResearchMode ?? false
  let isSquadronResearchMode  = params?.isSquadronResearchMode ?? false

  let isMounted      = isUnitInSlotbar(unit)
  let isOwn          = unit.isBought()
  let isSquadVehicle = unit.isSquadronVehicle()
  let researched     = unit.isResearched()

  let isVehicleInResearch = unit.isInResearch() && !forceNotInResearch
  let canResearch         = canResearchUnit(unit)

  let isUnitFromMarathon = !isOwn && !researched && !canResearch && unit.event != null

  let unitExpGranted      = unit.getExp()
  let diffExp = isSquadVehicle
    ? min(clan_get_exp(), getUnitReqExp(unit) - unitExpGranted)
    : (params?.diffExp ?? 0)
  let isLockedSquadronVehicle = isSquadVehicle && !is_in_clan() && diffExp <= 0

  local bitStatus = 0
  if (!isLocalState || isInFlight())
    bitStatus = bit_unit_status.owned
  else if (unit.isBroken())
    bitStatus = bit_unit_status.broken
  else if (isMounted)
    bitStatus = bit_unit_status.mounted
  else if (isOwn)
    bitStatus = bit_unit_status.owned
  else if (canBuyUnit(unit) || canBuyUnitOnline(unit) || canBuyUnitOnMarketplace(unit) || isUnitFromMarathon)
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
  else if (unit.isCrossPromo || hasUnitEvent(unit.name))
    return bitStatus
  else
    bitStatus = bit_unit_status.locked

  if ((shopResearchMode
      && (isSquadVehicle || !(bitStatus &
        (bit_unit_status.locked
          | bit_unit_status.canBuy
          | bit_unit_status.inResearch
          | bit_unit_status.canResearch))))
    || (isSquadronResearchMode && !isSquadVehicle)) {
    bitStatus = bit_unit_status.disabled
  }

  return bitStatus
}

return freeze({
  getBitStatus
})