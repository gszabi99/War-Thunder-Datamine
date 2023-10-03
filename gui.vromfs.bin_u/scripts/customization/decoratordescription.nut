//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { sqrt } = require("math")
let { format } = require("string")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let { getUnlockCondsDescByCfg, getUnlockMultDescByCfg,
  getUnlockMainCondDescByCfg } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isDefaultSkin } = require("%scripts/customization/skinUtils.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")

let function updateDecoratorDescription(obj, handler, decoratorType, decorator, params = {}) {
  local config = null
  let unlockBlk = getUnlockById(decorator?.unlockId)
  if (unlockBlk) {
    config = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(config)
  }

  let iObj = obj.findObject("image")
  let img = decoratorType.getImage(decorator)

  iObj["background-image"] = img

  if (img != "") {
    let imgSize = params?.imgSize ?? {}
    let imgRatio = decoratorType.getRatio(decorator)
    let iDivObj = iObj.getParent()
    iDivObj.height = imgSize?[1] ?? format("%.2f@decalIconHeight", sqrt(4.0 / imgRatio))
    iDivObj.width  = imgSize?[0] ?? $"{imgRatio}h"
    iDivObj.show(true)
  }

  let header = decorator.getName()
  obj.findObject("header").setValue(header)

  let desc = [decorator.getDesc()]
  if (config?.isRevenueShare ?? false)
    desc.append(colorize("advertTextColor", loc("content/revenue_share")))

  local typeDesc = decorator.getTypeDesc()
  typeDesc = (desc.len() > 1 || desc[0].len() > 0) ? $"\n{typeDesc}" : typeDesc
  desc.append(typeDesc, decorator.getVehicleDesc(),
    decorator.getLocParamsDesc(), decorator.getRestrictionsDesc())

  let commaLoc = loc("ui/comma")
  let colonLoc = loc("ui/colon")
  let searchId = decorator.id
  if (decoratorType.hasLocations(searchId)) {
    let mask = skinLocations.getSkinLocationsMaskBySkinId(searchId, decoratorTypes.SKINS, false)
    let locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (locations.len())
      desc.append($"{loc("camouflage/for_environment_conditions")}{colonLoc}{commaLoc.join(locations, true)}")
  }

  local tags = decorator.getTagsLoc()
  if (tags.len()) {
    tags = tags.map(@(txt) colorize("activeTextColor", txt))
    desc.append($"\n{loc("ugm/tags")}{colonLoc}{commaLoc.join(tags, true)}")
  }

  local descText = "\n".join(desc, true)
  let warbondId = getTblValue("wbId", params)
  if (warbondId) {
    let warbond = ::g_warbonds.findWarbond(warbondId, getTblValue("wbListId", params))
    let award = warbond ? warbond.getAwardById(searchId) : null
    if (award)
      descText = award.addAmountTextToDesc(descText)
  }
  obj.findObject("description").setValue(descText)

  let isDefSkin = isDefaultSkin(searchId)
  let isTrophyContent  = params?.showAsTrophyContent ?? false
  let isReceivedPrizes = params?.receivedPrizes      ?? false

  local canBuy = false
  let hasDecor = decoratorType.isPlayerHaveDecorator(searchId)
  if (!hasDecor) {
    let cost = decorator.getCost()
    let hasPrice = !isTrophyContent && !isReceivedPrizes && !cost.isZero()
    let aObj = showObjById("price", hasPrice, obj)
    if (hasPrice) {
      canBuy = true
      if (checkObj(aObj))
        aObj.setValue(loc("ugm/price") + loc("ui/colon") + colorize("white", cost.getTextAccordingToBalance()))
    }
  }
  else
    showObjById("price", false, obj)

  local canConsumeCoupon = false
  local canFindOnMarketplace = false
  if (!hasDecor && decorator.getCouponItemdefId() != null) {
    let inventoryItem = ::ItemsManager.getInventoryItemById(decorator.getCouponItemdefId())
    if (inventoryItem?.canConsume() ?? false)
      canConsumeCoupon = true
    canFindOnMarketplace = !canConsumeCoupon
  }

  let markup = params?.additionalDescriptionMarkup
  let dObj = showObjById("additional_description", markup != null, obj)
  if (markup != null)
    dObj.getScene().replaceContentFromText(dObj, markup, markup.len(), handler)

  let { hideUnlockInfo = false } = params
  showObjById("conditions", !hideUnlockInfo, obj)
  if (hideUnlockInfo)
    return

  //fill unlock info
  let canShowUnlockDesc = !isTrophyContent && !isReceivedPrizes
  let mainCond = canShowUnlockDesc ? getUnlockMainCondDescByCfg(config) : ""
  let multDesc = canShowUnlockDesc ? getUnlockMultDescByCfg(config) : ""
  let conds = canShowUnlockDesc ? getUnlockCondsDescByCfg(config) : ""

  let cObj = obj.findObject("conditions")
  cObj.findObject("mainCond").setValue(mainCond)
  cObj.findObject("multDesc").setValue(multDesc)
  cObj.findObject("conds").setValue(conds)

  local obtainInfo = ""
  let hasNoConds = mainCond == "" && conds == ""
  if (!isDefSkin && hasNoConds) {
    if (hasDecor) {
      obtainInfo = loc("mainmenu/itemReceived")
      if (isTrophyContent && !isReceivedPrizes)
        obtainInfo += "\n" + colorize("badTextColor",
          loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce"))
    }
    else if (isTrophyContent)
      obtainInfo = loc("mainmenu/itemCanBeReceived")
    else if (canBuy)
      obtainInfo = loc("shop/object/can_be_purchased")
    else if (canConsumeCoupon)
      obtainInfo = " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_get_from_coupon")))
    else if (canFindOnMarketplace)
      obtainInfo = " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_be_found_on_marketplace")))
    else
      obtainInfo = loc("multiplayer/notAvailable")
  }
  cObj.findObject("obtain_info").setValue(obtainInfo)

  let canShowProgressBar = !hasDecor && canShowUnlockDesc && config
  if (canShowProgressBar) {
    let progressData = config.getProgressBarData()
    let pObj = showObjById("progress", progressData.show, cObj)
    if (progressData.show)
      pObj.setValue(progressData.value)
  }
  else
    showObjById("progress", false, cObj)

  let iconName = isDefSkin ? ""
    : hasDecor ? "#ui/gameuiskin#favorite"
    : "#ui/gameuiskin#locked.svg"
  cObj.findObject("state")["background-image"] = iconName
}

return {
  updateDecoratorDescription
}