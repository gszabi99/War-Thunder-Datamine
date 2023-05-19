//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

subscriptions.addListenersWithoutEnv({
  UnitBought = function(p) {
    let unit = getAircraftByName(p?.unitName)
    if (!unit)
      return

    let config = {
      locId = "purchase_unit"
      subType = ps4_activity_feed.PURCHASE_UNIT
      backgroundPost = true
    }

    let customFeedParams = {
      requireLocalization = ["unitName", "country"]
      unitNameId = unit.name
      unitName = unit.name + "_shop"
      rank = ::get_roman_numeral(unit?.rank ?? -1)
      country = ::getUnitCountry(unit)
      link = format(loc("url/wiki_objects"), unit.name)
    }

    let reciever = isPlatformSony ? bit_activity.PS4_ACTIVITY_FEED : bit_activity.NONE
    activityFeedPostFunc(config, customFeedParams, reciever)
  }
})