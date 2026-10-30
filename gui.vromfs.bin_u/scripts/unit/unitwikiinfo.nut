from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/unit/unitInfo.nut" import getUnitName
from "string" import format
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "%scripts/dagui_library.nut" import *

let getUnitWikiUrl = @(unitName)
  format(getCurCircuitOverride("wikiObjectsURL", loc("url/wiki_objects")), unitName)

function openUnitWikiInfo(unit, metricPlace) {
  if (hasFeature("WikiUnitInfo"))
    openUrl(getUnitWikiUrl(unit.name), false, false, metricPlace)
  else
    showInfoMsgBox("\n".concat(colorize("activeTextColor", getUnitName(unit, false)), loc("profile/wiki_link")))
}

return freeze({
  getUnitWikiUrl
  openUnitWikiInfo
})