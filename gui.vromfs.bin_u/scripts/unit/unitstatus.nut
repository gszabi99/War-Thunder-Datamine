from "%scripts/dagui_natives.nut" import clan_get_exp, get_unit_elite_status
from "%scripts/dagui_library.nut" import *
let { canResearchUnit, bit_unit_status, canBuyUnit, getUnitReqExp } = require("%scripts/unit/unitInfo.nut")
let { isInFlight } = require("gameplayBinding")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")

let isUnitInSlotbar = @(unit) getCrewByAir(unit) != null

let canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()

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

  let unitExpGranted      = unit.getExp()
  let diffExp = isSquadVehicle
    ? min(clan_get_exp(), getUnitReqExp(unit) - unitExpGranted)
    : (params?.diffExp ?? 0)
  let isLockedSquadronVehicle = isSquadVehicle && !::is_in_clan() && diffExp <= 0

  local bitStatus = 0
  if (!isLocalState || isInFlight())
    bitStatus = bit_unit_status.owned
  else if (unit.isBroken())
    bitStatus = bit_unit_status.broken
  else if (isMounted)
    bitStatus = bit_unit_status.mounted
  else if (isOwn)
    bitStatus = bit_unit_status.owned
  else if (canBuyUnit(unit) || ::canBuyUnitOnline(unit) || ::canBuyUnitOnMarketplace(unit))
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
  else if (unit.isCrossPromo)
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

function isUnitEliteByStatus(status) {
  return status > ES_UNIT_ELITE_STAGE1
}

function isUnitElite(unit) {
  let unitName = unit?.name
  return unitName ? isUnitEliteByStatus(get_unit_elite_status(unitName)) : false
}

return {
  canBuyNotResearched
  getBitStatus
  isUnitEliteByStatus
  isUnitElite
  isUnitInSlotbar
}