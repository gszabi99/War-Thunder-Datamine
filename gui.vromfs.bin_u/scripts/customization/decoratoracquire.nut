// Functions for acquiring decorators by all possible ways (purchase, consume coupon, find on marketplace)

local function askPurchaseDecorator(decorator, onSuccessCb)
{
  if (!(decorator?.canBuyUnlock(null) ?? false))
    return

  local cost = decorator.getCost()
  local decoratorType = decorator.decoratorType
  local unitName = ""
  local decoratorId = decorator.id
  if (decoratorType == ::g_decorator_type.SKINS) {
    unitName = ::g_unlocks.getPlaneBySkinId(decoratorId)
    decoratorId = ::g_unlocks.getSkinNameBySkinId(decoratorId)
  }
  local msgText = ::warningIfGold(::loc("shop/needMoneyQuestion_purchaseDecal",
    { purchase = decorator.getName(),
      cost = cost.getTextAccordingToBalance()
    }), cost)

  msgBox("need_money", msgText,
        [["ok", function() {
          if (::check_balance_msgBox(cost))
            decoratorType.buyFunc(unitName, decoratorId, cost, onSuccessCb)
        }],
        ["cancel"]], "ok", { cancel_fn = @() null })
}

local function askConsumeDecoratorCoupon(decorator, onSuccessCb)
{
  if (!(decorator?.canGetFromCoupon(null) ?? false))
    return

  local inventoryItem = ::ItemsManager.getInventoryItemById(decorator?.getCouponItemdefId())
  inventoryItem.consume(::Callback(function(result) {
    if (result?.success ?? false)
      onSuccessCb?()
  }, this), null)
}

local function findDecoratorCouponOnMarketplace(decorator)
{
  local item = ::ItemsManager.findItemById(decorator?.getCouponItemdefId())
  if (!(item?.hasLink() ?? false))
    return
  item.openLink()
}

local function askFindDecoratorCouponOnMarketplace(decorator)
{
  if (!(decorator?.canBuyCouponOnMarketplace(null) ?? false))
    return

  local item = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
  local itemName = ::colorize("activeTextColor", item.getName())
  msgBox("find_on_marketplace", ::loc("msgbox/find_on_marketplace", { itemName = itemName }), [
      [ "find_on_marketplace", @() findDecoratorCouponOnMarketplace(decorator) ],
      [ "cancel" ]
    ], "find_on_marketplace", { cancel_fn = @() null })
}

// Pass unit=null to skip unit check
local function canAcquireDecorator(decorator, unit = null)
{
  if (decorator == null || decorator.isUnlocked())
    return false
  return decorator.canBuyUnlock(unit)
    || decorator.canGetFromCoupon(unit)
    || decorator.canBuyCouponOnMarketplace(unit)
}

local function askAcquireDecorator(decorator, onSuccessCb)
{
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
