from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")

function fillCountriesList(obj, countries, customViewCountryData = null) {
  if (!checkObj(obj))
    return

  if (obj.childrenCount() != shopCountriesList.len()) {
    let view = {
      countries = shopCountriesList.map(@(countryName) { countryName, countryIcon = "" })
    }
    let markup = handyman.renderCached("%gui/countriesList.tpl", view)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), null)
  }

  foreach (idx, country in shopCountriesList) {
    if (idx >= obj.childrenCount())
      continue

    let isVisible = countries.contains(country)
    let countryObj = obj.getChild(idx)
    countryObj.show(isVisible)
    if (isVisible)
      countryObj["background-image"] = getCountryIcon(customViewCountryData?[country].icon ?? country)
  }
}

return {
  fillCountriesList
}