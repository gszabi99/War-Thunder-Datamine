from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")

function fillCountriesList(obj, countries, handler = null) {
  if (!checkObj(obj))
    return

  if (obj.childrenCount() != shopCountriesList.len()) {
    let view = {
      countries = shopCountriesList.map(@(countryName) { countryName = countryName
          countryIcon = getCountryIcon(countryName)
        })
    }
    let markup = handyman.renderCached("%gui/countriesList.tpl", view)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
  }

  foreach (idx, country in shopCountriesList)
    if (idx < obj.childrenCount())
      obj.getChild(idx).show(isInArray(country, countries))
}

return {
  fillCountriesList
}