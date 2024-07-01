from "%scripts/dagui_library.nut" import *
let { exit_ship_flags_mode } = require("unitCustomization")
let { charSendBlk } = require("chard")
let DataBlock = require("DataBlock")
let { getPlaneBySkinId, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { addTask } = require("%scripts/tasker.nut")
let { buyUnlockImpl } = require("%scripts/unlocks/unlocksAction.nut")

// Functions for acquiring decorators by all possible ways (purchase, consume coupon, find on marketplace)

function buyResourceImpl(resourceType, unitName, id, cost, afterSuccessFunc) {
  let blk = DataBlock()
  blk["name"] = id
  blk["type"] = resourceType
  blk["unitName"] = unitName
  blk["cost"] = cost.wp
  blk["costGold"] = cost.gold

  let taskId = charSendBlk("cln_buy_resource", blk)
  let taskOptions = { showProgressBox = true, progressBoxText = loc("charServer/purchase") }
  addTask(taskId, taskOptions, afterSuccessFunc)
}

let buyFuncByResourceType = {
  [decoratorTypes.FLAGS] = function(unitName, id, cost, afterSuccessFunc) {
    buyUnlockImpl(id, unitName, cost,
      function() {
        exit_ship_flags_mode(true, true)
        afterSuccessFunc()
      },
      @() exit_ship_flags_mode(false, false))
  },
}

let getResourceBuyFunc = @(resType) buyFuncByResourceType?[resType] ??
  @(unitName, id, cost, afterSuccessFunc)
    buyResourceImpl(resType.resourceType, unitName, id, cost, afterSuccessFunc)

function askPurchaseDecorator(decorator, onSuccessCb) {
  if (!(decorator?.canBuyUnlock(null) ?? false))
    return

  let cost = decorator.getCost()
  let decoratorType = decorator.decoratorType
  local unitName = ""
  local decoratorId = decorator.id
  if (decoratorType == decoratorTypes.SKINS) {
    unitName = getPlaneBySkinId(decoratorId)
    decoratorId = getSkinNameBySkinId(decoratorId)
  }
  let msgText = warningIfGold(loc("shop/needMoneyQuestion_purchaseDecal",
    { purchase = decorator.getName(),
      cost = cost.getTextAccordingToBalance()
    }), cost)

  this.msgBox("need_money", msgText,
        [["ok", function() {
          if (checkBalanceMsgBox(cost))
            getResourceBuyFunc(decoratorType)(unitName, decoratorId, cost, onSuccessCb)
        }],
        ["cancel"]], "ok", { cancel_fn = @() null })
}

function askConsumeDecoratorCoupon(decorator, onSuccessCb) {
  if (!(decorator?.canGetFromCoupon(null) ?? false))
    return

  let inventoryItem = ::ItemsManager.getInventoryItemById(decorator?.getCouponItemdefId())
  inventoryItem.consume(Callback(function(result) {
    if (result?.success ?? false)
      onSuccessCb?()
  }, this), null)
}

function findDecoratorCouponOnMarketplace(decorator) {
  let item = ::ItemsManager.findItemById(decorator?.getCouponItemdefId())
  if (!(item?.hasLink() ?? false))
    return
  item.openLink()
}

function askFindDecoratorCouponOnMarketplace(decorator) {
  if (!(decorator?.canBuyCouponOnMarketplace(null) ?? false))
    return

  let item = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
  let itemName = colorize("activeTextColor", item.getName())
  this.msgBox("find_on_marketplace", loc("msgbox/find_on_marketplace", { itemName = itemName }), [
      [ "find_on_marketplace", @() findDecoratorCouponOnMarketplace(decorator) ],
      [ "cancel" ]
    ], "find_on_marketplace", { cancel_fn = @() null })
}

// Pass unit=null to skip unit check
function canAcquireDecorator(decorator, unit = null) {
  if (decorator == null || decorator.isUnlocked())
    return false
  return decorator.canBuyUnlock(unit)
    || decorator.canGetFromCoupon(unit)
    || decorator.canBuyCouponOnMarketplace(unit)
}

function askAcquireDecorator(decorator, onSuccessCb) {
  if (!canAcquireDecorator(decorator, null))
    return
  if (decorator.canBuyUnlock(null))
    return askPurchaseDecorator(decorator, onSuccessCb)
  if (decorator.canGetFromCoupon(null))
    return askConsumeDecoratorCoupon(decorator, onSuccessCb)
  if (decorator.canBuyCouponOnMarketplace(null))
    return askFindDecoratorCouponOnMarketplace(decorator)
}


return {
  canAcquireDecorator
  askAcquireDecorator
  askPurchaseDecorator
  askConsumeDecoratorCoupon
  askFindDecoratorCouponOnMarketplace
  findDecoratorCouponOnMarketplace
  getResourceBuyFunc
}
