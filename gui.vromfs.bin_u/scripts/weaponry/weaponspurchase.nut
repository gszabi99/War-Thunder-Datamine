from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_time_msec } = require("dagor.time")
let { format } = require("string")
let unitActions = require("%scripts/unit/unitActions.nut")
let { getModItemName } = require("%scripts/weaponry/weaponryDescription.nut")
let { getItemCost,
        getAllModsCost,
        getItemStatusTbl,
        getItemUnlockCost } = require("%scripts/weaponry/itemInfo.nut")

const PROCESS_TIME_OUT = 60000
local activePurchaseProcess = null

let function canBuyForEagles(cost, unit)
{
  if (cost.isZero())
    return false

  if (cost.gold > 0)
  {
    if (!hasFeature("SpendGold"))
      return false

    if (!::can_spend_gold_on_unit_with_popup(unit))
      return false
  }

  return true
}

let function canBuyItem(cost, unit, afterRefillFunc = null, silent = false)
{
  if (cost.isZero())
    return false

  if (!canBuyForEagles(cost, unit))
    return false

  if (!::check_balance_msgBox(cost, afterRefillFunc, silent))
    return false

  return true
}

local class WeaponsPurchaseProcess
{
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

  constructor(v_unit, additionalParams)
  {
    processStartTime = get_time_msec()

    unit = v_unit
    isAllPresetPurchase = additionalParams?.isAllPresetPurchase ?? false
    silent = additionalParams?.silent ?? false
    open = additionalParams?.open ?? false
    afterSuccessfullPurchaseCb = additionalParams?.afterSuccessfullPurchaseCb
    onCompleteCb = additionalParams?.onFinishCb

    modItem = getTblValue("modItem", additionalParams)
    if (!::u.isEmpty(modItem))
    {
      modName = modItem.name
      modType = modItem.type
    }

    checkMultiPurchase()
  }

  function checkMultiPurchase()
  {
    local canBuyAmount = 1
    if (!::u.isEmpty(modItem) && modType != weaponsItem.primaryWeapon)
    {
      let statusTbl = getItemStatusTbl(unit, modItem)
      if (!statusTbl.canBuyMore)
      {
        if (statusTbl.showPrice)
          ::g_popups.add("", loc("weaponry/enoughAmount"), null, null, null, "enough_amount")
        return complete()
      }

      canBuyAmount = statusTbl.maxAmount - statusTbl.amount
    }

    if (canBuyAmount == 1 || (hasFeature("BuyAllPresets") && isAllPresetPurchase))
      return execute(canBuyAmount)

    let params = {
      item = modItem
      unit = unit
      buyFunc = Callback(function(amount) { execute(amount, false) }, this)
      onExitFunc = Callback(function() { complete() }, this)
    }

    ::gui_start_modal_wnd(::gui_handlers.MultiplePurchase, params)
  }

  function complete()
  {
    if (isCompleted)
      return

    isCompleted = true
    onCompleteCb?()
  }

  function execute(amount = 1, completeOnCancel = true)
  {
    fillModItemSpecificParams(amount)

    if (!canBuyItem(cost, unit, null, silent))
    {
      if (completeOnCancel)
        complete()
      return
    }

    let repairCost = checkRepair? unit.getRepairCost() : ::Cost()
    let price = cost + repairCost
    msgLocParams.cost <- price.getTextAccordingToBalance()

    let performAction = (@(repairCost, mainFunc, amount, completeOnCancel) function() {
      if (repairCost.isZero())
        mainFunc(amount)
      else
        repair(Callback((@(amount) function() { mainFunc(amount)})(amount), this),
               Callback((@(amount, completeOnCancel) function() { execute(amount, completeOnCancel)})(amount, completeOnCancel), this))
    })(repairCost, mainFunc, amount, completeOnCancel)

    if (silent)
      return performAction()

    let cancelAction = (@(completeOnCancel) function() {
      if (completeOnCancel)
        complete()
    })(completeOnCancel)

    let text = ::warningIfGold(
        loc(repairCost.isZero() ? msgLocId : repairMsgLocId,
        msgLocParams
      ), price)
    let defButton = "yes"
    let buttons = [
      ["yes", performAction ],
      ["no", cancelAction ]
    ]
    ::scene_msg_box("mechanic_execute_msg", null, text, buttons, defButton,
      { cancel_fn = cancelAction, baseHandler = this})
  }

  function repair(afterSuccessFunc = null, afterBalanceRefillFunc = null)
  {
    let repairCost = unit.getRepairCost()
    if (!canBuyItem(repairCost, unit, afterBalanceRefillFunc, silent))
      complete()
    else
      unitActions.repair(unit, afterSuccessFunc)
  }

  function fillModItemSpecificParams(amount = 1)
  {
    cost = getPrice()

    if (::u.isEmpty(modItem))
      return fillAllModsParams()

    cost.multiply(amount)

    if (modItem.type == weaponsItem.spare)
      return fillSpareParams(amount)

    if (modItem.type == weaponsItem.weapon)
      return fillWeaponParams(amount)

    return fillModificationParams(amount)
  }

  function getPrice()
  {
    if (::u.isEmpty(modItem))
      return getAllModificationsPrice()

    if (::g_weaponry_types.getUpgradeTypeByItem(modItem).canBuy(unit, modItem))
      return getItemCost(unit, modItem)

    return getItemUnlockCost(unit, modItem)
  }

  function getAllModificationsPrice()
  {
    let modsCost = getAllModsCost(unit, open)
    return ::Cost(modsCost.wp, open? modsCost.gold : 0)
  }

  //-------------- <BUY ALL MODS> --------------------------------------

  function fillAllModsParams()
  {
    mainFunc = Callback(function(amount) { sendPurchaseAllModsRequest(amount) }, this)
    msgLocId = "shop/needMoneyQuestion_all_weapons"
    repairMsgLocId = "msgBox/repair_and_mods_purchase"
    msgLocParams = {
      unitName = colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseAllModsRequest(_amount = 1)
  {
    let blk = ::DataBlock()
    blk["unit"] = unit.name
    blk["forceOpen"] = open
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    let taskId = ::char_send_blk("cln_buy_all_modification", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::broadcastEvent("ModificationPurchased", {unit = unit})
      ::updateAirAfterSwitchMod(unit, "")

      afterSuccessfullPurchaseCb?()
    })(unit, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    complete()
  }

  //-------------- <BUY SPARE> --------------------------------------

  function fillSpareParams(amount = 1)
  {
    mainFunc = Callback(function(amount) { sendPurchaseSpareRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      cost = cost
    }
  }

  function sendPurchaseSpareRequest(amount = 1)
  {
    let blk = ::DataBlock()
    blk["aircraft"] =  unit.name
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    let taskId = ::char_send_blk("cln_buy_spare_aircrafts", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::broadcastEvent("SparePurchased", {unit = unit})
      afterSuccessfullPurchaseCb?()
    })(unit, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    complete()
  }

  //-------------- <BUY WEAPON> --------------------------------------

  function fillWeaponParams(amount = 1)
  {
    mainFunc = Callback(function(amount) { sendPurchaseWeaponRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseWeaponRequest(amount = 1)
  {
    let blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["weapon"] = modName
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    let taskId = ::char_send_blk("cln_buy_weapon", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, modName, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit)
      ::broadcastEvent("WeaponPurchased", {unit = unit, weaponName = modName})
      afterSuccessfullPurchaseCb?()
    })(unit, modName, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    complete()
  }

  //-------------- <BUY SINGLE MOD> --------------------------------------

  function fillModificationParams(amount = 1)
  {
    mainFunc = Callback(function(amount)
      { sendPurchaseModificationRequest(amount) }, this)
    msgLocId = open? "shop/needMoneyQuestion_purchaseModificationForGold"
      : "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseModificationRequest(amount = 1)
  {
    let blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["modification"] = modName
    blk["open"] = open
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    let hadUnitModResearch = ::shop_get_researchable_module_name(unit.name)
    let taskId = ::char_send_blk("cln_buy_modification", blk)
    let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
    let afterOpFunc = (@(unit, modName, hadUnitModResearch, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit, modName)

      let newResearch = ::shop_get_researchable_module_name(unit.name)
      if (::u.isEmpty(newResearch) && !::u.isEmpty(hadUnitModResearch))
        ::broadcastEvent("AllModificationsPurchased", {unit = unit})

      ::broadcastEvent("ModificationPurchased", {unit = unit, modName = modName})

      afterSuccessfullPurchaseCb?()
    })(unit, modName, hadUnitModResearch, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    complete()
  }

  function getItemTextWithAmount(amount)
  {
    local text = getModItemName(unit, modItem, false)
    if (amount > 1)
      text += " " + colorize("activeTextColor", format(loc("weapons/counter/right/short"), amount))

    return colorize("userlogColoredText", text)
  }
}

local function weaponsPurchase(unit, additionalParams = {})
{
  if (::u.isString(unit))
    unit = ::getAircraftByName(unit)

  if (::u.isEmpty(unit))
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
