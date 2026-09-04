from "string" import format
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%scripts/dagui_library.nut" import *

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

let getUnitWikiUrl = @(unitName)
  format(getCurCircuitOverride("wikiObjectsURL", loc("url/wiki_objects")), unitName)

function openUnitWikiInfo(unit, metricPlace) {
  if (hasFeature("WikiUnitInfo"))
    openUrl(getUnitWikiUrl(unit.name), false, false, metricPlace)
  else
    showInfoMsgBox("\n".concat(colorize("activeTextColor", getUnitName(unit, false)), loc("profile/wiki_link")))
}

return {
  getUnitWikiUrl
  openUnitWikiInfo
}