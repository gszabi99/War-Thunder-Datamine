import "%scripts/openCrossPromoWnd.nut" as openCrossPromoWnd
import "%scripts/unit/takeUnitInSlotbar.nut" as takeUnitInSlotbar
from "%scripts/unit/unitStatus.nut" import canBuyNotResearched, isUnitMaxExp, canResearchUnit, isUnitInResearch, isUnitGroup, isUnitBroken, isUnitUsable, isUnitResearched
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/unit/unitActions.nut" import repairWithMsgBox, buy, flushSquadronExp, research
from "%scripts/unit/unitInfo.nut" import getUnitExp
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit, isUnitGift, canSpendGoldOnUnitWithPopup
from "%scripts/unit/unitChecks.nut" import checkForResearch
from "%scripts/onlineShop/onlineShopModel.nut" import showUnitGoods
from "%scripts/weaponry/weaponryActions.nut" import open_weapons_for_unit
from "%scripts/convertExp/convertExp.nut" import openConvertExpModalWnd
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "%scripts/unit/unitEvents.nut" import hasUnitEvent, getUnitEventId
from "%scripts/user/profileHandler.nut" import guiStartProfile
from "%scripts/dagui_natives.nut" import clan_get_exp
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let ACTION_FUNCTION_PARAMS = {
  availableFlushExp = 0
  isSquadronResearchMode = false
  setResearchManually = false
  needChosenResearchOfSquadron = false
}

let MAIN_FUNC_PARAMS = {
  onSpendExcessExp = null
  onTakeParams = {}
  availableFlushExp = 0
  isSquadronResearchMode = false
  setResearchManually = true
  needChosenResearchOfSquadron = false
  curEdiff = 0
}

function getSlotActionFunctionName(unit, params) {
  params = ACTION_FUNCTION_PARAMS.__merge(params)

  if (isUnitBroken(unit))
    return "mainmenu/btnRepair"
  if (isUnitInSlotbar(unit))
    return ""
  if (unit.isUsable() && !isUnitInSlotbar(unit))
    return "mainmenu/btnTakeAircraft"
  if (hasUnitEvent(unit.name))
    return "mainmenu/btnGotoAchievement"
  if (!unit.isCrossPromo && (canBuyUnit(unit) || canBuyUnitOnline(unit)))
    return "mainmenu/btnOrder"

  let isSquadronVehicle = unit.isSquadronVehicle()
  let isInResearch = isUnitInResearch(unit)
  let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
    && min(clan_get_exp(), unit.reqExp - getUnitExp(unit)) > 0
  if ((params.availableFlushExp > 0 || !params.setResearchManually
      || (params.isSquadronResearchMode && params.needChosenResearchOfSquadron)
      || (isSquadronVehicle && !is_in_clan() && !canFlushSquadronExp))
    && (canResearchUnit(unit) || isInResearch))
    return "mainmenu/btnResearch"
  if(unit.isCrossPromo && !unit.isUsable())
    return "sm_conditions"
  if (isInResearch && hasFeature("SpendGold") && !isSquadronVehicle)
    return "mainmenu/btnConvert"

  if (canFlushSquadronExp && (isInResearch || params.isSquadronResearchMode))
    return "mainmenu/btnInvestSquadronExp"
  if (isInResearch && canBuyNotResearched(unit))
    return "mainmenu/btnOrder"
  if (!isUnitUsable(unit) && !isUnitGift(unit) && (!isSquadronVehicle || !isInResearch))
    return (isUnitResearched(unit) || isUnitMaxExp(unit)) ? "mainmenu/btnOrder" : "mainmenu/btnResearch"
  return ""
}

function slotMainAction(unit, params = MAIN_FUNC_PARAMS) {
  if (!unit || isUnitGroup(unit) || unit?.isFakeUnit)
    return

  params = MAIN_FUNC_PARAMS.__merge(params)
  if (isUnitBroken(unit))
    return repairWithMsgBox(unit)
  if (isUnitInSlotbar(unit))
    return open_weapons_for_unit(unit, { curEdiff = params.curEdiff })
  if (unit.isUsable() && !isUnitInSlotbar(unit))
    return takeUnitInSlotbar(unit, params.onTakeParams)
  if (hasUnitEvent(unit.name))
    return guiStartProfile({ initialSheet = "UnlockAchievement", curAchievementGroupName = getUnitEventId(unit.name) })
  if (canBuyUnitOnline(unit))
    return showUnitGoods(unit.name, "slot_action")
  if (canBuyUnit(unit))
    return buy(unit, "slotAction")

  let isSquadronVehicle = unit.isSquadronVehicle()
  let isInResearch = isUnitInResearch(unit)
  let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
    && min(clan_get_exp(), unit.reqExp - getUnitExp(unit)) > 0
  if ((params.availableFlushExp > 0
      || !params.setResearchManually
      || (params.isSquadronResearchMode && (canFlushSquadronExp || params.needChosenResearchOfSquadron)))
    && (canResearchUnit(unit) || isInResearch))
    return params.onSpendExcessExp()
  if (isInResearch && hasFeature("SpendGold")
      && !isSquadronVehicle && canSpendGoldOnUnitWithPopup(unit))
    return openConvertExpModalWnd(unit)

  if (canFlushSquadronExp && isInResearch)
    return flushSquadronExp(unit)
  if (isInResearch && canBuyNotResearched(unit)
    && isSquadronVehicle && is_in_clan())
    return buy(unit, "slot_action_squad")
  if (unit.isCrossPromo)
    return openCrossPromoWnd(unit.crossPromoBanner)
  if (checkForResearch(unit)) 
    return research(unit)
}

return freeze({
  getSlotActionFunctionName
  slotMainAction
})