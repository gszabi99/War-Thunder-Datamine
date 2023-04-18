//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let personalOffers = require("personalOffers")
let DataBlock = require("DataBlock")
let { parse } = require("json")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let curPersonalOffer = mkWatched(persist, "curPersonalOffer", null)
let checkedOffers = mkWatched(persist, "checkedOffers", {})

let function clearOfferCache() {
  clearTimer(clearOfferCache)
  curPersonalOffer(null)
}

let function gerRecievedOfferContent(offerContent) {
  let res = []
  foreach(offer in offerContent) {
    let contentType = ::trophyReward.getType(offer)
    if(contentType == "unit") {
      let unitName = offer.unit
      if (::shop_is_aircraft_purchased(unitName))
        res.append($"{contentType}:{unitName}")
      continue
    }

    if(contentType == "resourceType" || contentType == "resource") {
      let { resource, resourceType } = offer
      let decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
      if(decoratorType.isPlayerHaveDecorator(resource))
        res.append($"resource:{resource}")
      continue
    }
  }

  return res
}

let hasSendToBq= @(offerName)
  ::load_local_account_settings($"personalOffer/{offerName}/hasSendToBq") ?? false

let function sendDataToBqOnce(data) {
  if (hasSendToBq(data.offerName))
    return
  ::add_big_query_record("personal_offer_restriction", ::save_to_json(data))
  ::save_local_account_settings($"personalOffer/{data.offerName}/hasSendToBq", true)
}

let function markSeenPersonalOffer(offerName) {
  let seenCountId = $"personalOffer/{offerName}/visibleOfferCount"
  ::save_local_account_settings(seenCountId, (::load_local_account_settings(seenCountId) ?? 0) + 1)
  sendDataToBqOnce({ offerName, serverTime = ::get_charserver_time_sec(), reason = "personal_offer_window_is_show" })
}

let isSeenOffer= @(offerName)
  (::load_local_account_settings($"personalOffer/{offerName}/visibleOfferCount") ?? 0) > 0

let function cachePersonalOfferIfNeed() {
  if (curPersonalOffer.value != null)
    return

  let checked = clone checkedOffers.value
  let count = personalOffers.count()
  for (local i = 0; i < count; ++i) {
    let personalOffer = personalOffers.get(i)
    let offerName = personalOffer.key
    if (offerName in checked)
      continue

    checked[offerName] <- true
    local data = null
    try {
      data = parse(personalOffer.text)
    }
    catch(e) {
    }
    let serverTime = ::get_charserver_time_sec()
    if (data == null) {
      sendDataToBqOnce({ offerName, serverTime, reason = "can_not_parse_json", desc = personalOffer.text })
      continue
    }
    let { offer = "" } = data
    if (offer == "") {
      sendDataToBqOnce({ offerName, serverTime, reason = "offer_is_empty_string" })
      continue
    }
    let offerBlk = DataBlock()
    try {
      offerBlk.loadFromText(offer, offer.len())
    }
    catch(e) {
    }
    if (offerBlk.paramCount() == 0) {
      sendDataToBqOnce({ offerName, serverTime, reason = "can_not_load_offer_to_blk", desc = offer })
      continue
    }

    let { costGold = 0, duration_in_seconds = 0 } = offerBlk
    if (costGold <= 0) {
      sendDataToBqOnce({ offerName, serverTime, reason = "wrong_cost_gold", desc = offer })
      continue
    }

    if (duration_in_seconds <= 0) {
      sendDataToBqOnce({ offerName, serverTime, reason = "wrong_duration_in_seconds", desc = offer })
      continue
    }

    let recievedOfferContent = gerRecievedOfferContent(offerBlk % "i")
    if(recievedOfferContent.len() > 0) {
      sendDataToBqOnce({ offerName, serverTime, reason = "has_content", desc = ";".join(recievedOfferContent) })
      continue
    }

    let finishTime = ::load_local_account_settings($"personalOffer/{offerName}/finishTime") ?? 0
    if (finishTime == 0
        && ((serverTime + duration_in_seconds) > (personalOffer?.timeExpired ?? 0).tointeger())) {
      sendDataToBqOnce({ offerName, serverTime, reason = "expired_time_less_duration_time" })
      continue
    }
    let timeExpired = finishTime !=0 ? finishTime : serverTime + duration_in_seconds
    if(timeExpired <= serverTime) {
      sendDataToBqOnce({ offerName, serverTime, reason = "offer_is_expired", desc = $"timeExpired:{timeExpired}" })
      continue
    }

    curPersonalOffer({
      offerName
      timeExpired
      offerBlk
    })
    ::save_local_account_settings($"personalOffer/{offerName}/finishTime", timeExpired)
    setTimeout(timeExpired - serverTime, clearOfferCache)
    break
  }
  checkedOffers(checked)
}

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