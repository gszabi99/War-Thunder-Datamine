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

let function markSeenPersonalOffer(offerName) {
  let seenCountId = $"personalOffer/{offerName}/visibleOfferCount"
  ::save_local_account_settings(seenCountId, (::load_local_account_settings(seenCountId) ?? 0) + 1)
}

let isSeenOffer= @(offerName)
  (::load_local_account_settings($"personalOffer/{offerName}/visibleOfferCount") ?? 0) > 0

let hasSendToBq= @(offerName)
  ::load_local_account_settings($"personalOffer/{offerName}/hasSendToBq") ?? false

let function sendDataToBq(config) {
  ::add_big_query_record("personal_offer_restriction", ::save_to_json(config))
  ::save_local_account_settings($"personalOffer/{config.offerName}/hasSendToBq", true)
}

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
    let data = parse(personalOffer.text)

    let { offer = "" } = data
    if (offer == "")
      continue
    let offerBlk = DataBlock()
    if (!offerBlk.loadFromText(offer, offer.len()))
      continue

    let { costGold = 0, duration_in_seconds = 0 } = offerBlk
    if (costGold <= 0 || duration_in_seconds <= 0)
      continue

    let curTime = ::get_charserver_time_sec()
    let recievedOfferContent = gerRecievedOfferContent(offerBlk % "i")
    if(recievedOfferContent.len() > 0) {
      if (!hasSendToBq(offerName))
        sendDataToBq({
          offerName
          serverTime = curTime
          reason = "has_content"
          desc = ";".join(recievedOfferContent)
        })
      continue
    }

    let finishTime = ::load_local_account_settings($"personalOffer/{offerName}/finishTime") ?? 0
    if (finishTime == 0
        && ((curTime + duration_in_seconds) > (personalOffer?.timeExpired ?? 0).tointeger())) {
      if (!hasSendToBq(offerName))
        sendDataToBq({
          offerName
          serverTime = curTime
          reason = "expired_time_less_duration_time"
        })
      continue
    }
    let timeExpired = finishTime !=0 ? finishTime : curTime + duration_in_seconds
    if(timeExpired <= curTime)
      continue

    curPersonalOffer({
      offerName
      timeExpired
      offerBlk
    })
    ::save_local_account_settings($"personalOffer/{offerName}/finishTime", timeExpired)
    setTimeout(timeExpired - curTime, clearOfferCache)
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