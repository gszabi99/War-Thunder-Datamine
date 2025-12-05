from "%scripts/dagui_natives.nut" import clan_get_exp, shop_set_researchable_unit, shop_get_researchable_unit_name, clan_get_researching_unit, char_send_blk, char_send_action_and_load_profile, shop_purchase_aircraft
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock  = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getUnitName, getUnitCountry, getUnitExp, getUnitCost
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { addTask, addBgTaskCb } = require("%scripts/tasker.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { canBuyNotResearched, canResearchUnit, isUnitInResearch, isUnitResearched, isUnitFeatureLocked
} = require("%scripts/unit/unitStatus.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCantBuyUnitReason } = require("%scripts/unit/unitInfoTexts.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")

enum CheckFeatureLockAction {
  BUY,
  RESEARCH
}

function canSpendGoldOnUnitWithPopup(unit) {
  if (unit.unitType.canSpendGold())
    return true

  addPopup(getUnitName(unit), loc("msgbox/unitTypeRestrictFromSpendGold"),
    null, null, null, "cant_spend_gold_on_unit")
  return false
}

function impl_buyUnit(unit, needSelectCrew = true) {
  if (!unit)
    return false
  if (unit.isBought())
    return false

  let canBuyNotResearchedUnit = canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : getUnitCost(unit)
  if (!checkBalanceMsgBox(unitCost))
    return false

  let unitName = unit.name
  local taskId = null
  if (canBuyNotResearchedUnit) {
    let blk = DataBlock()
    blk["unit"] = unit.name
    blk["cost"] = unitCost.wp
    blk["costGold"] = unitCost.gold

    taskId = char_send_blk("cln_buy_not_researched_clans_unit", blk)
  }
  else
    taskId = shop_purchase_aircraft(unitName)

  let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase"), null, null)
  addBgTaskCb(taskId, function() {
    destroyMsgBox(progressBox)
    broadcastEvent("UnitBought", { unitName = unit.name, needSelectCrew })
  })
  return true
}

function checkFeatureLock(unit, lockAction) {
  if (!isUnitFeatureLocked(unit))
    return true
  let params = {
    purchaseAvailable = hasFeature("OnlineShopPacks")
    featureLockAction = lockAction
    unit = unit
  }

  loadHandler(gui_handlers.VehicleRequireFeatureWindow, params)
  return false
}

function showCantBuyOrResearchUnitMsgbox(unit) {
  let reason = getCantBuyUnitReason(unit)
  if (u.isEmpty(reason))
    return true

  scene_msg_box("need_buy_prev", null, reason, [["ok", function () {}]], "ok")
  return false
}

function buyUnit(unit, silent = false) {
  if (!checkFeatureLock(unit, CheckFeatureLockAction.BUY))
    return false

  let canBuyNotResearchedUnit = canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : getUnitCost(unit)
  if (unitCost.gold > 0 && !canSpendGoldOnUnitWithPopup(unit))
    return false

  if (!canBuyUnit(unit) && !canBuyNotResearchedUnit) {
    if ((isUnitResearched(unit) || isUnitSpecial(unit)) && !silent)
      showCantBuyOrResearchUnitMsgbox(unit)
    return false
  }

  if (silent)
    return impl_buyUnit(unit)

  let unitName  = colorize("userlogColoredText", getUnitName(unit, true))
  let unitPrice = unitCost.getTextAccordingToBalance()
  let msgText = warningIfGold(loc("shop/needMoneyQuestion_purchaseAircraft",
      { unitName = unitName, cost = unitPrice }),
    unitCost)

  scene_msg_box("need_money", null, msgText, [
    ["no", @() null],
    ["order_and_choose_crew/later", @() impl_buyUnit(unit, false)],
    ["order_and_choose_crew", @() impl_buyUnit(unit)],
  ], "order_and_choose_crew", { cancel_fn = @() null })
  return true
}

function repairRequest(unit, price, onSuccessCb = null, onErrorCb = null) {
  let blk = DataBlock()
  blk["name"] = unit.name
  blk["cost"] = price.wp
  blk["costGold"] = price.gold

  let taskId = char_send_blk("cln_prepare_aircraft", blk)

  let progBox = { showProgressBox = true }
  let onTaskSuccess = function() {
    broadcastEvent("UnitRepaired", { unit = unit })
    if (onSuccessCb)
      onSuccessCb()
  }

  addTask(taskId, progBox, onTaskSuccess, onErrorCb)
}

function repairNoMsgBox(unit, onSuccessCb = null, onErrorCb = null) {
  if (!unit) {
    onErrorCb?()
    return
  }
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  if (checkBalanceMsgBox(price))
    repairRequest(unit, price, onSuccessCb, onErrorCb)
  else
    onErrorCb?()
}

function repairWithMsgBox(unit, onSuccessCb = null) {
  if (!unit)
    return
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  let msgText = loc("msgbox/question_repair", { unitName = loc(getUnitName(unit)), cost = price.tostring() })
  let callbackYes = @() repairNoMsgBox(unit, onSuccessCb)
  purchaseConfirmation("question_repair", msgText, callbackYes)
}

function showFlushSquadronExpMsgBox(unit, onDoneCb, onCancelCb) {
  scene_msg_box("ask_flush_squadron_exp",
    null,
    loc("squadronExp/invest/needMoneyQuestion",
      { exp = Cost().setSap(min(clan_get_exp(), unit.reqExp - getUnitExp(unit))).tostring() }),
    [
      ["yes", onDoneCb],
      ["no", onCancelCb]
    ],
    "yes")
}

function flushSquadronExp(unit, params = {}) {
  if (!unit)
    return

  let { afterDoneFunc = @() null } = params
  let onDoneCb = @() addTask(char_send_action_and_load_profile("cln_flush_clan_exp_to_unit"),
    null,
    function() {
      afterDoneFunc()
      broadcastEvent("FlushSquadronExp", { unit = unit })
    })
  showFlushSquadronExpMsgBox(unit, onDoneCb, afterDoneFunc)
}

function buy(unit, metric) {
  if (!unit)
    return

  if (canBuyUnitOnline(unit))
    showUnitGoods(unit.name, metric)
  else
    buyUnit(unit)
}

function research(unit, checkCurrentUnit = true, afterDoneFunc = null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  if (!canResearchUnit(unit) || (checkCurrentUnit && isUnitInResearch(unit)))
    return

  local prevUnitName = shop_get_researchable_unit_name(getUnitCountry(unit), getEsUnitType(unit))
  local taskId = -1
  if (unit.isSquadronVehicle()) {
     prevUnitName = clan_get_researching_unit()

     let blk = DataBlock()
     blk.addStr("unit", unitName);
     taskId = char_send_blk("cln_set_research_clan_unit", blk)
  }
  else
    taskId = shop_set_researchable_unit(unitName, getEsUnitType(unit))
  let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
  addBgTaskCb(taskId, function() {
    destroyMsgBox(progressBox)
    if (afterDoneFunc)
      afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName = unitName, prevUnitName = prevUnitName })
  })
}

function setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc = @() null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  let prevUnitName = clan_get_researching_unit()
  let blk = DataBlock()
  blk.addStr("unit", unitName)
  blk.addBool("auto", true)
  let taskId = char_send_blk("cln_set_research_clan_unit", blk)
  let taskCallback = function() {
    afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName, prevUnitName, unit })
  }
  addTask(taskId, { showProgressBox = true }, taskCallback, taskCallback)
}

function setResearchClanVehicleWithAutoFlush(unit, afterDoneFunc = @() null) {
  if (!canResearchUnit(unit) || isUnitInResearch(unit))
    return

  showFlushSquadronExpMsgBox(unit, @() setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc), afterDoneFunc)
}

function flushExcessExpToUnit(unit) {
  let blk = DataBlock()
  blk.setStr("unit", unit)

  return char_send_blk("cln_move_exp_to_unit", blk)
}

function flushExcessExpToModule(unit, module) {
  let blk = DataBlock()
  blk.setStr("unit", unit)
  blk.setStr("mod", module)

  return char_send_blk("cln_move_exp_to_module", blk)
}

return {
  CheckFeatureLockAction
  checkFeatureLock
  repairNoMsgBox
  repairWithMsgBox
  flushSquadronExp
  buy
  buyUnit
  research
  setResearchClanVehicleWithAutoFlush
  flushExcessExpToUnit
  flushExcessExpToModule
  showCantBuyOrResearchUnitMsgbox
  canSpendGoldOnUnitWithPopup
}
