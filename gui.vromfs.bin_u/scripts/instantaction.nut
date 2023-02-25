//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { format } = require("string")
let time = require("%scripts/time.nut")
let unitStatus = require("%scripts/unit/unitStatus.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { AMMO,
        getAmmoCost,
        getUnitNotReadyAmmoList } = require("%scripts/weaponry/ammoInfo.nut")
let { getToBattleLocId } = require("%scripts/viewUtils/interfaceCustomization.nut")
let { getSelSlotsData } = require("%scripts/slotbar/slotbarState.nut")
let { get_gui_option } = require("guiOptions")

::getBrokenAirsInfo <- function getBrokenAirsInfo(countries, respawn, checkAvailFunc = null) {
  let res = {
          canFlyout = true
          canFlyoutIfRepair = true
          canFlyoutIfRefill = true
          weaponWarning = false
          repairCost = 0
          broken_countries = [] // { country, airs }
          unreadyAmmoList = []
          unreadyAmmoCost = 0
          unreadyAmmoCostGold = 0

          haveRespawns = respawn
          randomCountry = countries.len() > 1

          shipsWithoutPurshasedTorpedoes = []
        }

  local readyWeaponsFound = false
  let unreadyAmmo = []
  if (!respawn) {
    let selList = getSelSlotsData().units
    foreach (c, airName in selList)
      if ((isInArray(c, countries)) && airName != "") {
        let repairCost = ::wp_get_repair_cost(airName)
        if (repairCost > 0) {
          res.repairCost += repairCost
          res.broken_countries.append({ country = c, airs = [airName] })
          res.canFlyout = false
        }
        let air = ::getAircraftByName(airName)
        let crew = air && ::getCrewByAir(air)
        if (!crew || ::is_crew_locked_by_prev_battle(crew))
          res.canFlyoutIfRepair = false

        let ammoList = getUnitNotReadyAmmoList(
          air, getLastWeapon(air.name), UNIT_WEAPONS_WARNING)
        if (ammoList.len())
          unreadyAmmo.extend(ammoList)
        else
          readyWeaponsFound = true

        if (unitStatus.isShipWithoutPurshasedTorpedoes(air))
          res.shipsWithoutPurshasedTorpedoes.append(air)
      }
  }
  else
    foreach (cc in ::g_crews_list.get())
      if (isInArray(cc.country, countries)) {
        local have_repaired_in_country = false
        local have_unlocked_in_country = false
        let brokenList = []
        foreach (crew in cc.crews) {
          let unit = ::g_crew.getCrewUnit(crew)
          if (!unit || (checkAvailFunc && !checkAvailFunc(unit)))
            continue

          let repairCost = ::wp_get_repair_cost(unit.name)
          if (repairCost > 0) {
            brokenList.append(unit.name)
            res.repairCost += repairCost
          }
          else
            have_repaired_in_country = true

          if (!::is_crew_locked_by_prev_battle(crew))
            have_unlocked_in_country = true

          let ammoList = getUnitNotReadyAmmoList(
            unit, getLastWeapon(unit.name), UNIT_WEAPONS_WARNING)
          if (ammoList.len())
            unreadyAmmo.extend(ammoList)
          else
            readyWeaponsFound = true

          if (unitStatus.isShipWithoutPurshasedTorpedoes(unit))
            res.shipsWithoutPurshasedTorpedoes.append(unit)
        }
        res.canFlyout = res.canFlyout && have_repaired_in_country
        res.canFlyoutIfRepair = res.canFlyoutIfRepair && have_unlocked_in_country
        if (brokenList.len() > 0)
          res.broken_countries.append({ country = cc.country, airs = brokenList })
      }
  res.canFlyout = res.canFlyout && res.canFlyoutIfRepair

  let allUnitsMustBeReady = countries.len() > 1
  if (unreadyAmmo.len() && (allUnitsMustBeReady || (!allUnitsMustBeReady && !readyWeaponsFound))) {
    res.weaponWarning = true
    res.canFlyoutIfRefill = res.canFlyout

    res.canFlyout = false

    res.unreadyAmmoList = unreadyAmmo
    foreach (ammo in unreadyAmmo) {
      let cost = getAmmoCost(::getAircraftByName(ammo.airName), ammo.ammoName, ammo.ammoType)
      res.unreadyAmmoCost     += ammo.buyAmount * cost.wp
      res.unreadyAmmoCostGold += ammo.buyAmount * cost.gold
    }
  }
  return res
}

::checkBrokenAirsAndDo <- function checkBrokenAirsAndDo(repairInfo, handler, startFunc, canRepairWholeCountry = true, cancelFunc = null) {
  if (repairInfo.weaponWarning && repairInfo.unreadyAmmoList && !get_gui_option(::USEROPT_SKIP_WEAPON_WARNING)) {
    let price = ::Cost(repairInfo.unreadyAmmoCost, repairInfo.unreadyAmmoCostGold)
    local msg = loc(repairInfo.haveRespawns ? "msgbox/all_planes_zero_ammo_warning" : "controls/no_ammo_left_warning")
    msg += "\n\n" + format(loc("buy_unsufficient_ammo"), price.getTextAccordingToBalance())

    ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
      {
        parentHandler = handler
        message = msg
        startBtnText = loc("mainmenu/btnBuy")
        ableToStartAndSkip = true
        onStartPressed = function() {
          ::buyAllAmmoAndApply(
            handler,
            repairInfo.unreadyAmmoList,
            function() {
              repairInfo.weaponWarning = false
              repairInfo.canFlyout = repairInfo.canFlyoutIfRefill
              ::checkBrokenAirsAndDo(repairInfo, handler, startFunc, canRepairWholeCountry, cancelFunc)
            },
            price
          )
        }
        cancelFunc = cancelFunc
      })
    return
  }

  let repairAll = function() {
    let rCost = ::Cost(repairInfo.repairCost)
    ::repairAllAirsAndApply(handler, repairInfo.broken_countries, startFunc, cancelFunc, canRepairWholeCountry, rCost)
  }

  let onCancel = function() { ::call_for_handler(handler, cancelFunc) }

  if (!repairInfo.canFlyout) {
    local msgText = ""
    let respawns = repairInfo.haveRespawns
    if (respawns)
      msgText = repairInfo.randomCountry ? "msgbox/no_%s_aircrafts_random" : "msgbox/no_%s_aircrafts"
    else
      msgText = repairInfo.randomCountry ? "msgbox/select_%s_aircrafts_random" : "msgbox/select_%s_aircraft"

    if (repairInfo.canFlyoutIfRepair)
      msgText = format(loc(format(msgText, "repared")), ::Cost(repairInfo.repairCost).tostring())
    else
      msgText = format(loc(format(msgText, "available")),
        time.secondsToString(::get_warpoints_blk()?.lockTimeMaxLimitSec ?? 0))

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
    msgText = format(msgText, ::Cost(repairInfo.repairCost).tostring())
    ::scene_msg_box("no_aircrafts", null, msgText,
       [
         ["ContinueWithoutRepair", function() { startFunc.call(handler) }],
         ["RepairAll", repairAll],
         ["cancel", onCancel]
       ], "RepairAll")
    return
  }
  else if (repairInfo.shipsWithoutPurshasedTorpedoes.len() > 0
    && !::load_local_account_settings("skipped_msg/shipsWithoutPurshasedTorpedoes", false))
    ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
      {
        parentHandler = handler
        message = loc("msgbox/hasShipWithoutPurshasedTorpedoes",
          {
            numShips = repairInfo.shipsWithoutPurshasedTorpedoes.len()
            shipsList = ::g_string.implode(
              repairInfo.shipsWithoutPurshasedTorpedoes.map(@(u)
                colorize("activeTextColor", ::getUnitName(u, true))),
              loc("ui/comma"))
          })
        startBtnText = loc(getToBattleLocId())
        ableToStartAndSkip = true
        showCheckBoxBullets = false
        skipFunc = function(value) {
          ::save_local_account_settings("skipped_msg/shipsWithoutPurshasedTorpedoes", value)
        }
        onStartPressed = function() {
          startFunc.call(handler)
        }
        cancelFunc = cancelFunc
    })
  else
    startFunc.call(handler)
}

::repairAllAirsAndApply <- function repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry = true, totalRCost = null) {
  if (!handler)
    return

  if (broken_countries.len() == 0) {
    afterDoneFunc.call(handler)
    return
  }

  if (totalRCost) {
    let afterCheckFunc = function() {
      if (::check_balance_msgBox(totalRCost, null, true))
        ::repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
      else if (onCancelFunc)
        onCancelFunc.call(handler)
    }
    if (!::check_balance_msgBox(totalRCost, afterCheckFunc))
      return
  }

  local taskId = -1

  if (broken_countries[0].airs.len() == 1 || !canRepairWholeCountry)
    taskId = ::shop_repair_aircraft(broken_countries[0].airs[0])
  else
    taskId = ::shop_repair_all(broken_countries[0].country, true)

  if (broken_countries[0].airs.len() > 1 && !canRepairWholeCountry)
    broken_countries[0].airs.remove(0)
  else
    broken_countries.remove(0)

  if (taskId >= 0) {
    let progressBox = ::scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
    ::add_bg_task_cb(taskId, function() {
      ::destroyMsgBox(progressBox)
      ::repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
    })
  }
}

::buyAllAmmoAndApply <- function buyAllAmmoAndApply(handler, unreadyAmmoList, afterDoneFunc, totalCost = ::Cost()) {
  if (!handler)
    return

  if (unreadyAmmoList.len() == 0) {
    afterDoneFunc.call(handler)
    return
  }

  if (!::check_balance_msgBox(totalCost))
    return

  let ammo = unreadyAmmoList[0]
  local taskId = -1

  if (ammo.ammoType == AMMO.WEAPON)
    taskId = ::shop_purchase_weapon(ammo.airName, ammo.ammoName, ammo.buyAmount)
  else if (ammo.ammoType == AMMO.MODIFICATION)
    taskId = ::shop_purchase_modification(ammo.airName, ammo.ammoName, ammo.buyAmount, false)
  unreadyAmmoList.remove(0)

  if (taskId >= 0) {
    let progressBox = ::scene_msg_box("char_connecting", null, loc("charServer/purchase0"), null, null)
    ::add_bg_task_cb(taskId, (@(handler, unreadyAmmoList, afterDoneFunc, progressBox) function() {
      ::destroyMsgBox(progressBox)
      ::buyAllAmmoAndApply(handler, unreadyAmmoList, afterDoneFunc)
    })(handler, unreadyAmmoList, afterDoneFunc, progressBox))
  }
}
