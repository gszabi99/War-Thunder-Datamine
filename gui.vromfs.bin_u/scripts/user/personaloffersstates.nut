from "%scripts/dagui_natives.nut" import shop_is_aircraft_purchased
from "%scripts/dagui_library.nut" import *

let personalOffers = require("personalOffers")
let DataBlock = require("DataBlock")
let { parse_json } = require("json")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { getTrophyRewardType } = require("%scripts/items/trophyReward.nut")

let curPersonalOffer = mkWatched(persist, "curPersonalOffer", null)
let checkedOffers = mkWatched(persist, "checkedOffers", {})

let isInProgressOfferValidation = Watched(false)

function clearOfferCache() {
  clearTimer(clearOfferCache)
  curPersonalOffer(null)
}

let hasSendToBq = @(offerName)
  loadLocalAccountSettings($"personalOffer/{offerName}/hasSendToBq") ?? false

function sendDataToBqOnce(data) {
  if (hasSendToBq(data.offerName))
    return
  sendBqEvent("CLIENT_POPUP_1", "personal_offer_restriction", data)
  saveLocalAccountSettings($"personalOffer/{data.offerName}/hasSendToBq", true)
}

function markSeenPersonalOffer(offerName) {
  let seenCountId = $"personalOffer/{offerName}/visibleOfferCount"
  saveLocalAccountSettings(seenCountId, (loadLocalAccountSettings(seenCountId) ?? 0) + 1)
  sendDataToBqOnce({ offerName, serverTime = get_charserver_time_sec(), reason = "personal_offer_window_is_show" })
}

let isSeenOffer = @(offerName)
  (loadLocalAccountSettings($"personalOffer/{offerName}/visibleOfferCount") ?? 0) > 0

function getReceivedOfferContent(offerContent) {
  let res = []
  foreach(offer in offerContent) {
    let contentType = getTrophyRewardType(offer)
    if (contentType == "unit" || contentType == "rentedUnit") {
      let unitName = offer?.unit ?? offer.rentedUnit
      if (shop_is_aircraft_purchased(unitName))
        res.append($"{contentType}:{unitName}")
      continue
    }

    if(contentType == "resourceType" || contentType == "resource") {
      let { resource, resourceType } = offer
      let decoratorType = getTypeByResourceType(resourceType)
      if(decoratorType.isPlayerHaveDecorator(resource))
        res.append($"resource:{resource}")
      continue
    }
  }

  return res
}

function checkCompletedSuccessfully(currentOfferData) {
  curPersonalOffer(currentOfferData)
  saveLocalAccountSettings($"personalOffer/{currentOfferData.offerName}/finishTime", currentOfferData.timeExpired)
  setTimeout(currentOfferData.timeExpired - get_charserver_time_sec(), clearOfferCache)
}

function validatePersonalOffer(personalOffer, currentOfferData) {
  currentOfferData.clear()
  let offerName = personalOffer.key
  currentOfferData.offerName <- offerName

  local data = null
  try {
    data = parse_json(personalOffer.text)
  }
  catch(e) {
  }

  let serverTime = get_charserver_time_sec()
  if (data == null) {
    sendDataToBqOnce({ offerName, serverTime, reason = "can_not_parse_json", desc = personalOffer.text })
    return false
  }
  let { offer = "" } = data
  if (offer == "") {
    sendDataToBqOnce({ offerName, serverTime, reason = "offer_is_empty_string" })
    return false
  }

  let offerBlk = DataBlock()
  try {
    offerBlk.loadFromText(offer, offer.len())
  }
  catch(e) {
  }
  currentOfferData.offerBlk <- offerBlk
  if (offerBlk.paramCount() == 0) {
    sendDataToBqOnce({ offerName, serverTime, reason = "can_not_load_offer_to_blk", desc = offer })
    return false
  }

  let { costGold = 0, duration_in_seconds = 0 } = offerBlk
  if (costGold <= 0) {
    sendDataToBqOnce({ offerName, serverTime, reason = "wrong_cost_gold", desc = offer })
    return false
  }

  if (duration_in_seconds <= 0) {
    sendDataToBqOnce({ offerName, serverTime, reason = "wrong_duration_in_seconds", desc = offer })
    return false
  }

  let receivedOfferContent = getReceivedOfferContent(offerBlk % "i")
  if(receivedOfferContent.len() > 0) {
    sendDataToBqOnce({ offerName, serverTime, reason = "has_content", desc = ";".join(receivedOfferContent) })
    return false
  }

  let finishTime = loadLocalAccountSettings($"personalOffer/{offerName}/finishTime") ?? 0
  if (finishTime == 0
      && ((serverTime + duration_in_seconds) > (personalOffer?.timeExpired ?? 0).tointeger())) {
    sendDataToBqOnce({ offerName, serverTime, reason = "expired_time_less_duration_time" })
    return false
  }

  let timeExpired = finishTime != 0 ? finishTime : serverTime + duration_in_seconds
  currentOfferData.timeExpired <- timeExpired
  if(timeExpired <= serverTime) {
    sendDataToBqOnce({ offerName, serverTime, reason = "offer_is_expired", desc = $"timeExpired:{timeExpired}" })
    return false
  }

  return true
}

function checkExternalItemsComplete(notExistedItems, currentOfferData) {
  checkedOffers.mutate(@(v) v[currentOfferData.offerName] <- true)
  if(notExistedItems.len() > 0)
    sendDataToBqOnce({
      offerName = currentOfferData.offerName
      serverTime = get_charserver_time_sec()
      reason = "content_not_exists"
      desc = ";".join(notExistedItems)
    })
  else
    checkCompletedSuccessfully(currentOfferData)
  isInProgressOfferValidation(false)
}

function onGetExternalItems(notExistedItems, externalItems, currentOfferData) {
  notExistedItems.extend(externalItems
    .filter(@(itemId) findItemById(itemId) == null)
    .apply(@(itemId) $"item:{itemId}"))
  checkExternalItemsComplete(notExistedItems, currentOfferData)
}

function getNotExistedAndExternalOfferItems(currentOfferData) {
  let offerContent = currentOfferData.offerBlk % "i"
  let notExistedItems = []
  let externalItems = []
  foreach(offer in offerContent) {
    let contentType = getTrophyRewardType(offer)

    if(contentType == "unit") {
      let { unit } = offer
      if (getAircraftByName(unit) == null)
        notExistedItems.append($"{contentType}:{unit}")
      continue
    }

    if(contentType == "resourceType" || contentType == "resource") {
      let { resourceType, resource } = offer
      let decoratorType = getTypeByResourceType(resourceType)
      if (decoratorType == decoratorTypes.UNKNOWN)
        notExistedItems.append($"resource:{resource}")
      let decorator = getDecorator(resource, decoratorType)
      if (decorator == null)
        notExistedItems.append($"resource:{resource}")
      continue
    }

    if(contentType == "unlock") {
      let { unlock } = offer
      if(getUnlockById(unlock) == null)
        notExistedItems.append($"unlock:{unlock}")
      continue
    }

    if(contentType == "entitlement") {
      let { entitlement } = offer

      if(getEntitlementConfig(entitlement) == null)
        notExistedItems.append($"entitlement:{entitlement}")
      continue
    }

    if(contentType == "item") {
      let { item } = offer
      if(type(item) == "string") {
        if(!findItemById(item))
          notExistedItems.append($"item:{item}")
      }
      else {
        externalItems.append(item)
      }
      continue
    }
  }

  return {
    notExistedItems
    externalItems
  }
}

function cachePersonalOfferIfNeed() {
  if (isInProgressOfferValidation.value)
    return

  if (curPersonalOffer.value != null)
    return

  let count = personalOffers.count()
  if(count == 0)
    return

  for (local i = 0; i < count; ++i) {
    let personalOffer = personalOffers.get(i)
    let offerName = personalOffer.key
    if (offerName in checkedOffers.value)
      continue
    let currentOfferData = {}
    let isValidOffer = validatePersonalOffer(personalOffer, currentOfferData)
    if(!isValidOffer) {
      checkedOffers.mutate(@(v) v[offerName] <- true)
      continue
    }

    let { notExistedItems, externalItems } = getNotExistedAndExternalOfferItems(currentOfferData)

    if(notExistedItems.len() > 0) {
      sendDataToBqOnce({
        offerName = currentOfferData.offerName
        serverTime = get_charserver_time_sec()
        reason = "content_not_exists"
        desc = ";".join(notExistedItems)
      })
      continue
    }

    if(externalItems.len() == 0) {
      checkExternalItemsComplete(notExistedItems, currentOfferData)
      return
    }

    inventoryClient.requestItemdefsByIds(externalItems, @() onGetExternalItems(notExistedItems, externalItems, currentOfferData))
    isInProgressOfferValidation(true)
    return
  }
}

isInProgressOfferValidation.subscribe(function(v) {
  if(!v)
    handlersManager.doDelayed(cachePersonalOfferIfNeed)
})

addListenersWithoutEnv({
  function SignOut(_) {
    checkedOffers.mutate(@(v) v.clear())
    clearOfferCache()
  }
})

return {
  curPersonalOffer
  cachePersonalOfferIfNeed
  markSeenPersonalOffer
  isSeenOffer
  clearOfferCache
}