import "DataBlock" as DataBlock
from "%scripts/customization/skinUtils.nut" import getPlaneBySkinId, getSkinNameBySkinId
from "%scripts/viewUtils/objectTextUpdate.nut" import warningIfGold
from "%scripts/user/balanceFeatures.nut" import checkBalanceMsgBox
from "%scripts/tasker.nut" import addTask
from "%scripts/unlocks/unlocksAction.nut" import buyUnlockImpl
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/items/itemsManagerGetters.nut" import getInventoryItemById
from "%scripts/purchase/purchaseConfirmationHandler.nut" import purchaseConfirmation
from "unitCustomization" import exit_ship_flags_mode
from "chard" import charSendBlk
from "%scripts/dagui_library.nut" import *

let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")



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
  let text = warningIfGold(loc("shop/needMoneyQuestion_purchaseDecal",
    { purchase = decorator.getName(),
      cost = cost.getTextAccordingToBalance()
    }), cost)

  let callbackYes = function() {
    if (checkBalanceMsgBox(cost))
      getResourceBuyFunc(decoratorType)(unitName, decoratorId, cost, onSuccessCb)
  }

  purchaseConfirmation({ id = "need_money", text, callbackYes }, cost)
}

function askConsumeDecoratorCoupon(decorator, onSuccessCb) {
  if (!(decorator?.canGetFromCoupon(null) ?? false))
    return

  let inventoryItem = getInventoryItemById(decorator?.getCouponItemdefId())
  inventoryItem.consume(Callback(function(result) {
    if (result?.success ?? false)
      onSuccessCb?()
  }, this), null)
}

function findDecoratorCouponOnMarketplace(decorator) {
  let item = findItemById(decorator?.getCouponItemdefId())
  if (!(item?.hasLink() ?? false))
    return
  item.openLink()
}

function askFindDecoratorCouponOnMarketplace(decorator) {
  if (!(decorator?.canBuyCouponOnMarketplace(null) ?? false))
    return

  let item = findItemById(decorator.getCouponItemdefId())
  let itemName = colorize("activeTextColor", item.getName())
  this.msgBox("find_on_marketplace", loc("msgbox/find_on_marketplace", { itemName = itemName }), [
      [ "find_on_marketplace", @() findDecoratorCouponOnMarketplace(decorator) ],
      [ "cancel" ]
    ], "find_on_marketplace", { cancel_fn = @() null })
}


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


return freeze({
  canAcquireDecorator
  askAcquireDecorator
  askPurchaseDecorator
  askConsumeDecoratorCoupon
  askFindDecoratorCouponOnMarketplace
  findDecoratorCouponOnMarketplace
  getResourceBuyFunc
})
