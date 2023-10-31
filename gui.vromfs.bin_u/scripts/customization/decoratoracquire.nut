//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { getPlaneBySkinId, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")

// Functions for acquiring decorators by all possible ways (purchase, consume coupon, find on marketplace)

let function askPurchaseDecorator(decorator, onSuccessCb) {
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
          if (::check_balance_msgBox(cost))
            decoratorType.buyFunc(unitName, decoratorId, cost, onSuccessCb)
        }],
        ["cancel"]], "ok", { cancel_fn = @() null })
}

let function askConsumeDecoratorCoupon(decorator, onSuccessCb) {
  if (!(decorator?.canGetFromCoupon(null) ?? false))
    return

  let inventoryItem = ::ItemsManager.getInventoryItemById(decorator?.getCouponItemdefId())
  inventoryItem.consume(Callback(function(result) {
    if (result?.success ?? false)
      onSuccessCb?()
  }, this), null)
}

let function findDecoratorCouponOnMarketplace(decorator) {
  let item = ::ItemsManager.findItemById(decorator?.getCouponItemdefId())
  if (!(item?.hasLink() ?? false))
    return
  item.openLink()
}

let function askFindDecoratorCouponOnMarketplace(decorator) {
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
let function canAcquireDecorator(decorator, unit = null) {
  if (decorator == null || decorator.isUnlocked())
    return false
  return decorator.canBuyUnlock(unit)
    || decorator.canGetFromCoupon(unit)
    || decorator.canBuyCouponOnMarketplace(unit)
}

let function askAcquireDecorator(decorator, onSuccessCb) {
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
  canAcquireDecorator = canAcquireDecorator
  askAcquireDecorator = askAcquireDecorator
  askPurchaseDecorator = askPurchaseDecorator
  askConsumeDecoratorCoupon = askConsumeDecoratorCoupon
  askFindDecoratorCouponOnMarketplace = askFindDecoratorCouponOnMarketplace
  findDecoratorCouponOnMarketplace = findDecoratorCouponOnMarketplace
}
