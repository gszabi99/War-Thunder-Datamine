from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "string" import format
from "guiOptions" import get_gui_option
from "blkGetters" import get_warpoints_blk
from "%scripts/dagui_natives.nut" import shop_repair_all, shop_purchase_modification, shop_repair_aircraft, shop_purchase_weapon
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import call_for_handler

let { g_squad_manager } = require("%scripts/squads/squadManager.nut")
let { SkipableMsgBox } = require("%scripts/wndLib/skipableMsgBox.nut")
let { WeaponWarningHandler } = require("%scripts/weaponry/weaponWarningHandler.nut")
let { Cost } = require("%scripts/money.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let time = require("%scripts/time.nut")
let { AMMO } = require("%scripts/weaponry/ammoInfo.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")

function buyAllAmmoAndApply(handler, unreadyAmmoList, afterDoneFunc, totalCost = Cost()) {
  if (!handler)
    return

  if (unreadyAmmoList.len() == 0) {
    afterDoneFunc.call(handler)
    return
  }

  if (!checkBalanceMsgBox(totalCost))
    return

  let ammo = unreadyAmmoList[0]
  local taskId = -1

  if (ammo.ammoType == AMMO.WEAPON)
    taskId = shop_purchase_weapon(ammo.airName, ammo.ammoName, ammo.buyAmount)
  else if (ammo.ammoType == AMMO.MODIFICATION)
    taskId = shop_purchase_modification(ammo.airName, ammo.ammoName, ammo.buyAmount, false)
  unreadyAmmoList.remove(0)

  let self = callee()
  if (taskId >= 0) {
    let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
    addBgTaskCb(taskId,function() {
      destroyMsgBox(progressBox)
      self(handler, unreadyAmmoList, afterDoneFunc)
    })
  }
}

function repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry = true, totalRCost = null) {
  if (!handler)
    return

  if (broken_countries.len() == 0) {
    broadcastEvent("UnitRepaired")
    afterDoneFunc.call(handler)
    return
  }

  let self = callee()
  if (totalRCost) {
    let afterCheckFunc = function() {
      if (checkBalanceMsgBox(totalRCost, null, true))
        self(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
      else if (onCancelFunc)
        onCancelFunc.call(handler)
    }
    if (!checkBalanceMsgBox(totalRCost, afterCheckFunc))
      return
  }

  local taskId = -1

  if (broken_countries[0].airs.len() == 1 || !canRepairWholeCountry)
    taskId = shop_repair_aircraft(broken_countries[0].airs[0])
  else
    taskId = shop_repair_all(broken_countries[0].country, true)

  if (broken_countries[0].airs.len() > 1 && !canRepairWholeCountry)
    broken_countries[0].airs.remove(0)
  else
    broken_countries.remove(0)

  if (taskId >= 0) {
    let progressBox = scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
    addBgTaskCb(taskId, function() {
      destroyMsgBox(progressBox)
      self(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
    })
  }
}

function checkBrokenAirsAndDo(repairInfo, handler, startFunc, canRepairWholeCountry = true, cancelFunc = null) {
  if (repairInfo.weaponWarning && repairInfo.unreadyAmmoList && !get_gui_option(USEROPT_SKIP_WEAPON_WARNING)) {
    let self = callee()
    let price = Cost(repairInfo.unreadyAmmoCost, repairInfo.unreadyAmmoCostGold)
    local msg = loc(repairInfo.haveRespawns ? "msgbox/all_planes_zero_ammo_warning" : "controls/no_ammo_left_warning")
    msg = "\n\n".concat(msg, format(loc("buy_unsufficient_ammo"), price.getTextAccordingToBalance()))

    loadHandler(WeaponWarningHandler,
      {
        parentHandler = handler
        message = msg
        startBtnText = loc("mainmenu/btnBuy")
        defaultBtnId = "btn_select"
        onStartPressed = function() {
          buyAllAmmoAndApply(
            handler,
            repairInfo.unreadyAmmoList,
            function() {
              repairInfo.weaponWarning = false
              repairInfo.canFlyout = repairInfo.canFlyoutIfRefill
              self(repairInfo, handler, startFunc, canRepairWholeCountry, cancelFunc)
            },
            price
          )
        }
        cancelFunc = cancelFunc
      })
    return
  }

  let repairAll = function() {
    let rCost = Cost(repairInfo.repairCost)
    repairAllAirsAndApply(handler, repairInfo.broken_countries, startFunc, cancelFunc, canRepairWholeCountry, rCost)
  }

  let onCancel = function() { call_for_handler(handler, cancelFunc) }

  if (!repairInfo.canFlyout) {
    local msgText = ""
    let respawns = repairInfo.haveRespawns
    if (respawns)
      msgText = repairInfo.randomCountry ? "msgbox/no_%s_aircrafts_random" : "msgbox/no_%s_aircrafts"
    else
      msgText = repairInfo.randomCountry ? "msgbox/select_%s_aircrafts_random" : "msgbox/select_%s_aircraft"

    if (repairInfo.canFlyoutIfRepair)
      msgText = format(loc(format(msgText, "repared")), Cost(repairInfo.repairCost).tostring())
    else if (g_squad_manager.isSquadMember())
      msgText = loc("squadMember/airs_not_available")
    else
      msgText = format(loc(format(msgText, "available")),
        time.secondsToString(get_warpoints_blk()?.lockTimeMaxLimitSec ?? 0))

    let repairBtnName = respawns ? "RepairAll" : "Repair"
    let buttons = repairInfo.canFlyoutIfRepair ?
                      [[repairBtnName, repairAll], ["cancel", onCancel]] :
                      [["ok", onCancel]]
    let defButton = repairInfo.canFlyoutIfRepair ? repairBtnName : "ok"
    handler.msgBox("no_aircrafts", msgText, buttons, defButton)
    return
  }
  else if (repairInfo.broken_countries.len() > 0) {
    local msgText = repairInfo.randomCountry ? loc("msgbox/some_repared_aircrafts_random") : loc("msgbox/some_repared_aircrafts")
    msgText = format(msgText, Cost(repairInfo.repairCost).tostring())
    scene_msg_box("no_aircrafts", null, msgText,
       [
         ["ContinueWithoutRepair", function() { startFunc.call(handler) }],
         ["RepairAll", repairAll],
         ["cancel", onCancel]
       ], "RepairAll")
    return
  }
  else if (repairInfo.shipsWithoutPurshasedTorpedoes.len() > 0
    && !loadLocalAccountSettings("skipped_msg/shipsWithoutPurshasedTorpedoes", false))
    loadHandler(SkipableMsgBox,
      {
        parentHandler = handler
        message = loc("msgbox/hasShipWithoutPurshasedTorpedoes",
          {
            numShips = repairInfo.shipsWithoutPurshasedTorpedoes.len()
            shipsList = loc("ui/comma").join(
              repairInfo.shipsWithoutPurshasedTorpedoes.map(@(u)
                colorize("activeTextColor", getUnitName(u, true))),
              true)
          })
        startBtnText = loc(getToBattleLocId())
        showCheckBoxBullets = false
        skipFunc = function(value) {
          saveLocalAccountSettings("skipped_msg/shipsWithoutPurshasedTorpedoes", value)
        }
        onStartPressed = function() {
          startFunc.call(handler)
        }
        cancelFunc = cancelFunc
    })
  else
    startFunc.call(handler)
}

return {
  checkBrokenAirsAndDo
}
