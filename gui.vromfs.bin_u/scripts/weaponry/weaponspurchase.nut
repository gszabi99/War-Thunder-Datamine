from "%scripts/dagui_natives.nut" import char_send_blk, shop_get_researchable_module_name
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { format } = require("string")
let unitActions = require("%scripts/unit/unitActions.nut")
let { getModItemName } = require("%scripts/weaponry/weaponryDescription.nut")
let { getItemCost,
        getAllModsCost,
        getItemStatusTbl,
        getItemUnlockCost } = require("%scripts/weaponry/itemInfo.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { addPopup } = require("%scripts/popups/popups.nut")

const PROCESS_TIME_OUT = 60000
local activePurchaseProcess = null

function canBuyForEagles(cost, unit) {
  if (cost.isZero())
    return false

  if (cost.gold > 0) {
    if (!hasFeature("SpendGold"))
      return false

    if (!::can_spend_gold_on_unit_with_popup(unit))
      return false
  }

  return true
}

function canBuyItem(cost, unit, afterRefillFunc = null, silent = false) {
  if (cost.isZero())
    return false

  if (!canBuyForEagles(cost, unit))
    return false

  if (!checkBalanceMsgBox(cost, afterRefillFunc, silent))
    return false

  return true
}

local class WeaponsPurchaseProcess {
  processStartTime = -1
  isCompleted = false

  unit = null

  silent = false
  open = false
  checkRepair = true

  modItem = null
  modName = ""
  modType = -1

  mainFunc = null
  cost = null

  afterSuccessfullPurchaseCb = null
  onCompleteCb = null

  msgLocId = ""
  repairMsgLocId = ""
  msgLocParams = {}
  isAllPresetPurchase = false

  constructor(v_unit, additionalParams) {
    this.processStartTime = get_time_msec()

    this.unit = v_unit
    this.isAllPresetPurchase = additionalParams?.isAllPresetPurchase ?? false
    this.silent = additionalParams?.silent ?? false
    this.open = additionalParams?.open ?? false
    this.afterSuccessfullPurchaseCb = additionalParams?.afterSuccessfullPurchaseCb
    this.onCompleteCb = additionalParams?.onFinishCb

    this.modItem = getTblValue("modItem", additionalParams)
    if (!u.isEmpty(this.modItem)) {
      this.modName = this.modItem.name
      this.modType = this.modItem.type
    }

    this.checkMultiPurchase()
  }

  function checkMultiPurchase() {
    local canBuyAmount = 1
    if (!u.isEmpty(this.modItem) && this.modType != weaponsItem.primaryWeapon) {
      let statusTbl = getItemStatusTbl(this.unit, this.modItem)
      if (!statusTbl.canBuyMore) {
        if (statusTbl.showPrice)
          addPopup("", loc("weaponry/enoughAmount"), null, null, null, "enough_amount")
        return this.complete()
      }

      canBuyAmount = statusTbl.maxAmount - statusTbl.amount
    }

    if (canBuyAmount == 1 || (hasFeature("BuyAllPresets") && this.isAllPresetPurchase))
      return this.execute(canBuyAmount)

    let params = {
      item = this.modItem
      unit = this.unit
      buyFunc = Callback(function(amount) { this.execute(amount, false) }, this)
      onExitFunc = Callback(function() { this.complete() }, this)
    }

    loadHandler(gui_handlers.MultiplePurchase, params)
  }

  function complete() {
    if (this.isCompleted)
      return

    this.isCompleted = true
    this.onCompleteCb?()
  }

  function execute(amount = 1, completeOnCancel = true) {
    this.fillModItemSpecificParams(amount)

    if (!canBuyItem(this.cost, this.unit, null, this.silent)) {
      if (completeOnCancel)
        this.complete()
      return
    }

    let repairCost = this.checkRepair ? this.unit.getRepairCost() : Cost()
    let price = this.cost + repairCost
    this.msgLocParams.cost <- price.getTextAccordingToBalance()
    let performAction = Callback(function() {
      if (repairCost.isZero())
        this.mainFunc(amount)
      else
        this.repair(Callback(@() this.mainFunc(amount), this),
          Callback(@() this.execute(amount, completeOnCancel), this))
    }, this)
    if (this.silent)
      return performAction()

    let cancelAction = Callback(function() {
      if (completeOnCancel)
        this.complete()
    }, this)

    let text = warningIfGold(
        loc(repairCost.isZero() ? this.msgLocId : this.repairMsgLocId,
        this.msgLocParams
      ), price)

    purchaseConfirmation("mechanic_execute_msg", text, performAction, cancelAction)
  }

  function repair(afterSuccessFunc = null, afterBalanceRefillFunc = null) {
    let repairCost = this.unit.getRepairCost()
    if (!canBuyItem(repairCost, this.unit, afterBalanceRefillFunc, this.silent))
      this.complete()
    else
      unitActions.repair(this.unit, afterSuccessFunc, Callback(@() this.complete(), this))
  }

  function fillModItemSpecificParams(amount = 1) {
    this.cost = this.getPrice()

    if (u.isEmpty(this.modItem))
      return this.fillAllModsParams()

    this.cost.multiply(amount)

    if (this.modItem.type == weaponsItem.spare)
      return this.fillSpareParams(amount)

    if (this.modItem.type == weaponsItem.weapon)
      return this.fillWeaponParams(amount)

    return this.fillModificationParams(amount)
  }

  function getPrice() {
    if (u.isEmpty(this.modItem))
      return this.getAllModificationsPrice()

    if (::g_weaponry_types.getUpgradeTypeByItem(this.modItem).canBuy(this.unit, this.modItem))
      return getItemCost(this.unit, this.modItem)

    return getItemUnlockCost(this.unit, this.modItem)
  }

  function getAllModificationsPrice() {
    let modsCost = getAllModsCost(this.unit, this.open)
    return Cost(modsCost.wp, this.open ? modsCost.gold : 0)
  }

  //-------------- <BUY ALL MODS> --------------------------------------

  function fillAllModsParams() {
    this.mainFunc = Callback(function(amount) { this.sendPurchaseAllModsRequest(amount) }, this)
    this.msgLocId = "shop/needMoneyQuestion_all_weapons"
    this.repairMsgLocId = "msgBox/repair_and_mods_purchase"
    this.msgLocParams = {
      unitName = colorize("userlogColoredText", getUnitName(this.unit))
      cost = this.cost
    }
  }

  function sendPurchaseAllModsRequest(_amount = 1) {
    let blk = DataBlock()
    blk["unit"] = this.unit.name
    blk["forceOpen"] = this.open
    blk["cost"] = this.cost.wp
    blk["costGold"] = this.cost.gold

    let taskId = char_send_blk("cln_buy_all_modification", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() { //-ident-hides-ident
      ::update_gamercards()
      broadcastEvent("ModificationPurchased", { unit = unit })
      broadcastEvent("AllModificationsPurchased", { unit = unit })
      ::updateAirAfterSwitchMod(unit, "")

      afterSuccessfullPurchaseCb?()
    })(this.unit, this.afterSuccessfullPurchaseCb)

    addTask(taskId, taskOptions, afterOpFunc)
    this.complete()
  }

  //-------------- <BUY SPARE> --------------------------------------

  function fillSpareParams(amount = 1) {
    this.mainFunc = Callback(function(amnt) { this.sendPurchaseSpareRequest(amnt) }, this)
    this.checkRepair = false
    this.msgLocId = "onlineShop/needMoneyQuestion"
    this.msgLocParams = {
      purchase = this.getItemTextWithAmount(amount)
      cost = this.cost
    }
  }

  function sendPurchaseSpareRequest(amount = 1) {
    let blk = DataBlock()
    blk["aircraft"] =  this.unit.name
    blk["count"] = amount
    blk["cost"] = this.cost.wp
    blk["costGold"] = this.cost.gold

    let taskId = char_send_blk("cln_buy_spare_aircrafts", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() { //-ident-hides-ident
      ::update_gamercards()
      broadcastEvent("SparePurchased", { unit = unit })
      afterSuccessfullPurchaseCb?()
    })(this.unit, this.afterSuccessfullPurchaseCb)

    addTask(taskId, taskOptions, afterOpFunc)
    this.complete()
  }

  //-------------- <BUY WEAPON> --------------------------------------

  function fillWeaponParams(amount = 1) {
    this.mainFunc = Callback(function(amnt) { this.sendPurchaseWeaponRequest(amnt) }, this)
    this.checkRepair = false
    this.msgLocId = "onlineShop/needMoneyQuestion"
    this.repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    this.msgLocParams = {
      purchase = this.getItemTextWithAmount(amount)
      unitName = colorize("userlogColoredText", getUnitName(this.unit))
      cost = this.cost
    }
  }

  function sendPurchaseWeaponRequest(amount = 1) {
    let blk = DataBlock()
    blk["aircraft"] = this.unit.name
    blk["weapon"] = this.modName
    blk["count"] = amount
    blk["cost"] = this.cost.wp
    blk["costGold"] = this.cost.gold

    let taskId = char_send_blk("cln_buy_weapon", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, modName, afterSuccessfullPurchaseCb) function() { //-ident-hides-ident
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit)
      broadcastEvent("WeaponPurchased", { unit = unit, weaponName = modName })
      afterSuccessfullPurchaseCb?()
    })(this.unit, this.modName, this.afterSuccessfullPurchaseCb)

    addTask(taskId, taskOptions, afterOpFunc)
    this.complete()
  }

  //-------------- <BUY SINGLE MOD> --------------------------------------

  function fillModificationParams(amount = 1) {
    this.mainFunc = Callback(function(amnt) { this.sendPurchaseModificationRequest(amnt) }, this)
    this.msgLocId = this.open ? "shop/needMoneyQuestion_purchaseModificationForGold"
      : "onlineShop/needMoneyQuestion"
    this.repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    this.msgLocParams = {
      purchase = this.getItemTextWithAmount(amount)
      unitName = colorize("userlogColoredText", getUnitName(this.unit))
      cost = this.cost
    }
  }

  function sendPurchaseModificationRequest(amount = 1) {
    let blk = DataBlock()
    blk["aircraft"] = this.unit.name
    blk["modification"] = this.modName
    blk["open"] = this.open
    blk["count"] = amount
    blk["cost"] = this.cost.wp
    blk["costGold"] = this.cost.gold

    let hadUnitModResearch = shop_get_researchable_module_name(this.unit.name)
    let taskId = char_send_blk("cln_buy_modification", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = Callback(function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(this.unit, this.modName)

      let newResearch = shop_get_researchable_module_name(this.unit.name)
      if (u.isEmpty(newResearch) && !u.isEmpty(hadUnitModResearch))
        broadcastEvent("AllModificationsPurchased", { unit = this.unit })

      broadcastEvent("ModificationPurchased", { unit = this.unit, modName = this.modName })

      this.afterSuccessfullPurchaseCb?()
    }, this)

    addTask(taskId, taskOptions, afterOpFunc)
    this.complete()
  }

  function getItemTextWithAmount(amount) {
    local text = getModItemName(this.unit, this.modItem, false)
    if (amount > 1)
      text = "".concat(text, " ", colorize("activeTextColor", format(loc("weapons/counter/right/short"), amount)))

    return colorize("userlogColoredText", text)
  }
}

function weaponsPurchase(unit, additionalParams = {}) {
  if (u.isString(unit))
    unit = getAircraftByName(unit)

  if (u.isEmpty(unit))
    return

  if (activePurchaseProcess?.isCompleted == false)
    if (get_time_msec() - activePurchaseProcess.processStartTime < PROCESS_TIME_OUT)
      return assert(false, "Error: trying to use 2 modification purchase processes at once")
    else
      activePurchaseProcess.complete()

  activePurchaseProcess = WeaponsPurchaseProcess(unit, additionalParams)
}

return {
  canBuyItem
  weaponsPurchase
}
