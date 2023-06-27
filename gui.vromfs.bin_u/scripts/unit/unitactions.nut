//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")

let DataBlock  = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

let function repairRequest(unit, price, onSuccessCb = null, onErrorCb = null) {
  let blk = DataBlock()
  blk["name"] = unit.name
  blk["cost"] = price.wp
  blk["costGold"] = price.gold

  let taskId = ::char_send_blk("cln_prepare_aircraft", blk)

  let progBox = { showProgressBox = true }
  let onTaskSuccess = function() {
    broadcastEvent("UnitRepaired", { unit = unit })
    if (onSuccessCb)
      onSuccessCb()
  }

  ::g_tasker.addTask(taskId, progBox, onTaskSuccess, onErrorCb)
}

let function repair(unit, onSuccessCb = null, onErrorCb = null) {
  if (!unit) {
    onErrorCb?()
    return
  }
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  if (::check_balance_msgBox(price))
    repairRequest(unit, price, onSuccessCb, onErrorCb)
  else
    onErrorCb?()
}

let function repairWithMsgBox(unit, onSuccessCb = null) {
  if (!unit)
    return
  let price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  let msgText = loc("msgbox/question_repair", { unitName = loc(::getUnitName(unit)), cost = price.tostring() })
  ::scene_msg_box("question_repair", null, msgText,
  [
    ["yes", function() { repair(unit, onSuccessCb) }],
    ["no", function() {} ]
  ], "no", { cancel_fn = function() {} })
}

let function showFlushSquadronExpMsgBox(unit, onDoneCb, onCancelCb) {
  ::scene_msg_box("ask_flush_squadron_exp",
    null,
    loc("squadronExp/invest/needMoneyQuestion",
      { exp = Cost().setSap(min(::clan_get_exp(), unit.reqExp - ::getUnitExp(unit))).tostring() }),
    [
      ["yes", onDoneCb],
      ["no", onCancelCb]
    ],
    "yes")
}

let function flushSquadronExp(unit, params = {}) {
  if (!unit)
    return

  let { afterDoneFunc = @() null } = params
  let onDoneCb = @() ::g_tasker.addTask(::char_send_action_and_load_profile("cln_flush_clan_exp_to_unit"),
    null,
    function() {
      afterDoneFunc()
      broadcastEvent("FlushSquadronExp", { unit = unit })
    })
  showFlushSquadronExpMsgBox(unit, onDoneCb, afterDoneFunc)
}

let function take(unit, params = {}) {
  if (!unit)
    return

  ::queues.checkAndStart(
    function() {
      ::g_squad_utils.checkSquadUnreadyAndDo(
        function () {
          if (!unit || !unit.isUsable() || ::isUnitInSlotbar(unit))
            return

          ::gui_start_selecting_crew({
            unit = unit
          }.__update(params))
        }, null, params?.shouldCheckCrewsReady ?? false)
    },
    null, "isCanModifyCrew", null)
}

let function buy(unit, metric) {
  if (!unit)
    return

  if (::canBuyUnitOnline(unit))
    ::OnlineShopModel.showUnitGoods(unit.name, metric)
  else
    ::buyUnit(unit)
}

let function research(unit, checkCurrentUnit = true, afterDoneFunc = null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  if (!::canResearchUnit(unit) || (checkCurrentUnit && ::isUnitInResearch(unit)))
    return

  local prevUnitName = ::shop_get_researchable_unit_name(::getUnitCountry(unit), ::get_es_unit_type(unit))
  local taskId = -1
  if (unit.isSquadronVehicle()) {
     prevUnitName = ::clan_get_researching_unit()

     let blk = DataBlock()
     blk.addStr("unit", unitName);
     taskId = ::char_send_blk("cln_set_research_clan_unit", blk)
  }
  else
    taskId = ::shop_set_researchable_unit(unitName, ::get_es_unit_type(unit))
  let progressBox = ::scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
  ::add_bg_task_cb(taskId, function() {
    ::destroyMsgBox(progressBox)
    if (afterDoneFunc)
      afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName = unitName, prevUnitName = prevUnitName })
  })
}

let function setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc = @() null) {
  let unitName = unit.name
  sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_new_research_unit", { unitName = unitName })
  let prevUnitName = ::clan_get_researching_unit()
  let blk = DataBlock()
  blk.addStr("unit", unitName)
  blk.addBool("auto", true)
  let taskId = ::char_send_blk("cln_set_research_clan_unit", blk)
  let taskCallback = function() {
    afterDoneFunc()
    broadcastEvent("UnitResearch", { unitName, prevUnitName, unit })
  }
  ::g_tasker.addTask(taskId, { showProgressBox = true }, taskCallback, taskCallback)
}

let function setResearchClanVehicleWithAutoFlush(unit, afterDoneFunc = @() null) {
  if (!::canResearchUnit(unit) || ::isUnitInResearch(unit))
    return

  showFlushSquadronExpMsgBox(unit, @() setResearchClanVehicleWithAutoFlushImpl(unit, afterDoneFunc), afterDoneFunc)
}

return {
  repair
  repairWithMsgBox
  flushSquadronExp
  take
  buy
  research
  setResearchClanVehicleWithAutoFlush
}
