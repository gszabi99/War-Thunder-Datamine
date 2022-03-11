let { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

::gui_handlers.WwQueueDescriptionCustomHandler <- class extends ::gui_handlers.WwMapDescription
{
  function mapCountriesToView(side, amountByCountry, joinedCountries)
  {
    let cuntriesByTeams = descItem.getCountriesByTeams()
    let countries = cuntriesByTeams?[side] ?? []
    let mapName = descItem.getId()
    return {
      countries = countries.map(function(countryId) {
        let customViewCountryData = getCustomViewCountryData(countryId, mapName)
        let customLocId = customViewCountryData.locId
        let countryNameText = countryId == customLocId
          ? ::loc(countryId)
          : "".concat(::loc(customLocId), ::loc("ui/parentheses/space", {text = ::loc(countryId)}))
        return {
          countryNameText = countryNameText
          countryId       = countryId
          countryIcon     = customViewCountryData.icon
          isJoined        = ::isInArray(countryId, joinedCountries)
          side            = side
          isLeftAligned   = side == ::SIDE_1
        }
      })
    }
  }

  function updateCountriesList()
  {
    let obj = scene.findObject("div_before_text")
    if (!::checkObj(obj))
      return

    let amountByCountry = descItem.getArmyGroupsAmountByCountries()
    let joinedCountries = descItem.getMyClanCountries()
    let sides = []
    foreach (side in ::g_world_war.getCommonSidesOrder())
      sides.append(mapCountriesToView(side, amountByCountry, joinedCountries))
    let view = {
      sides = sides
      vsText = ::loc("country/VS") + "\n "
    }

    let lastSelectedValue = ::get_obj_valid_index(obj.findObject("countries_container"))
    let data = ::handyman.renderCached("%gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    let isVisible = descItem.isMapActive()
    obj.show(isVisible)
    if (isVisible && lastSelectedValue >= 0)
      obj.findObject("countries_container").setValue(lastSelectedValue)
  }
}
