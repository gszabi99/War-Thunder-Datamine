local unitActions = require("scripts/unit/unitActions.nut")
local { getModItemName } = require("scripts/weaponry/weaponryDescription.nut")
local { getItemCost,
        getAllModsCost,
        getItemStatusTbl,
        getItemUnlockCost } = require("scripts/weaponry/itemInfo.nut")

const PROCESS_TIME_OUT = 60000
local activePurchaseProcess = null

local function canBuyForEagles(cost, unit)
{
  if (cost.isZero())
    return false

  if (cost.gold > 0)
  {
    if (!::has_feature("SpendGold"))
      return false

    if (!::can_spend_gold_on_unit_with_popup(unit))
      return false
  }

  return true
}

local function canBuyItem(cost, unit, afterRefillFunc = null)
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

  constructor(_unit, additionalParams)
  {
    processStartTime = ::dagor.getCurTime()

    unit = _unit
    isAllPresetPurchase = additionalParams?.isAllPresetPurchase ?? false
    silent = additionalParams?.silent ?? false
    open = additionalParams?.open ?? false
    afterSuccessfullPurchaseCb = additionalParams?.afterSuccessfullPurchaseCb
    onCompleteCb = additionalParams?.onFinishCb

    modItem = ::getTblValue("modItem", additionalParams)
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
      local statusTbl = getItemStatusTbl(unit, modItem)
      if (!statusTbl.canBuyMore)
      {
        if (statusTbl.showPrice)
          ::g_popups.add("", ::loc("weaponry/enoughAmount"), null, null, null, "enough_amount")
        return complete()
      }

      canBuyAmount = statusTbl.maxAmount - statusTbl.amount
    }

    if (canBuyAmount == 1 || (::has_feature("BuyAllPresets") && isAllPresetPurchase))
      return execute(canBuyAmount)

    local params = {
      item = modItem
      unit = unit
      buyFunc = ::Callback(function(amount) { execute(amount, false) }, this)
      onExitFunc = ::Callback(function() { complete() }, this)
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

    if (!canBuyItem(cost, unit))
    {
      if (completeOnCancel)
        complete()
      return
    }

    local repairCost = checkRepair? unit.getRepairCost() : ::Cost()
    local price = cost + repairCost
    msgLocParams.cost <- price.getTextAccordingToBalance()

    local performAction = (@(repairCost, mainFunc, amount, completeOnCancel) function() {
      if (repairCost.isZero())
        mainFunc(amount)
      else
        repair(::Callback((@(amount) function() { mainFunc(amount)})(amount), this),
               ::Callback((@(amount, completeOnCancel) function() { execute(amount, completeOnCancel)})(amount, completeOnCancel), this))
    })(repairCost, mainFunc, amount, completeOnCancel)

    if (silent)
      return performAction()

    local cancelAction = (@(completeOnCancel) function() {
      if (completeOnCancel)
        complete()
    })(completeOnCancel)

    local text = ::warningIfGold(
        ::loc(repairCost.isZero() ? msgLocId : repairMsgLocId,
        msgLocParams
      ), price)
    local defButton = "yes"
    local buttons = [
      ["yes", performAction ],
      ["no", cancelAction ]
    ]
    ::scene_msg_box("mechanic_execute_msg", null, text, buttons, defButton,
      { cancel_fn = cancelAction, baseHandler = this})
  }

  function repair(afterSuccessFunc = null, afterBalanceRefillFunc = null)
  {
    local repairCost = unit.getRepairCost()
    if (!canBuyItem(repairCost, unit, afterBalanceRefillFunc))
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
    local modsCost = getAllModsCost(unit, open)
    return ::Cost(modsCost.wp, open? modsCost.gold : 0)
  }

  //-------------- <BUY ALL MODS> --------------------------------------

  function fillAllModsParams()
  {
    mainFunc = ::Callback(function(amount) { sendPurchaseAllModsRequest(amount) }, this)
    msgLocId = "shop/needMoneyQuestion_all_weapons"
    repairMsgLocId = "msgBox/repair_and_mods_purchase"
    msgLocParams = {
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseAllModsRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["unit"] = unit.name
    blk["forceOpen"] = open
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_all_modification", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
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
    mainFunc = ::Callback(function(amount) { sendPurchaseSpareRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      cost = cost
    }
  }

  function sendPurchaseSpareRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] =  unit.name
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_spare_aircrafts", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
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
    mainFunc = ::Callback(function(amount) { sendPurchaseWeaponRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseWeaponRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["weapon"] = modName
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_weapon", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, modName, afterSuccessfullPurchaseCb) function() {
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
    mainFunc = ::Callback(function(amount)
      { sendPurchaseModificationRequest(amount) }, this)
    msgLocId = open? "shop/needMoneyQuestion_purchaseModificationForGold"
      : "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseModificationRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["modification"] = modName
    blk["open"] = open
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local hadUnitModResearch = ::shop_get_researchable_module_name(unit.name)
    local taskId = ::char_send_blk("cln_buy_modification", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, modName, hadUnitModResearch, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit, modName)

      local newResearch = ::shop_get_researchable_module_name(unit.name)
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
      text += " " + ::colorize("activeTextColor", ::format(::loc("weapons/counter/right/short"), amount))

    return ::colorize("userlogColoredText", text)
  }
}

local function weaponsPurchase(unit, additionalParams = {})
{
  if (::u.isString(unit))
    unit = ::getAircraftByName(unit)

  if (::u.isEmpty(unit))
    return

  if (activePurchaseProcess?.isCompleted == false)
    if (::dagor.getCurTime() - activePurchaseProcess.processStartTime < PROCESS_TIME_OUT)
      return ::dagor.assertf(false, "Error: trying to use 2 modification purchase processes at once")
    else
      activePurchaseProcess.complete()

  activePurchaseProcess = WeaponsPurchaseProcess(unit, additionalParams)
}

return {
  canBuyItem
  weaponsPurchase
}
