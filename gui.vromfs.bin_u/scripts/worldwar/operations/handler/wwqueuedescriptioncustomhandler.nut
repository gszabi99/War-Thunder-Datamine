local { getCustomViewCountryData } = require("scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

class ::gui_handlers.WwQueueDescriptionCustomHandler extends ::gui_handlers.WwMapDescription
{
  function mapCountriesToView(side, amountByCountry, joinedCountries)
  {
    local cuntriesByTeams = descItem.getCountriesByTeams()
    local countries = cuntriesByTeams?[side] ?? []
    local mapName = descItem.getId()
    return {
      countries = countries.map(function(countryId) {
        local customViewCountryData = getCustomViewCountryData(countryId, mapName)
        local customLocId = customViewCountryData.locId
        local countryNameText = countryId == customLocId
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
    local obj = scene.findObject("div_before_text")
    if (!::checkObj(obj))
      return

    local amountByCountry = descItem.getArmyGroupsAmountByCountries()
    local joinedCountries = descItem.getMyClanCountries()
    local sides = []
    foreach (side in ::g_world_war.getCommonSidesOrder())
      sides.append(mapCountriesToView(side, amountByCountry, joinedCountries))
    local view = {
      sides = sides
      vsText = ::loc("country/VS") + "\n "
    }

    local lastSelectedValue = ::get_obj_valid_index(obj.findObject("countries_container"))
    local data = ::handyman.renderCached("gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    local isVisible = descItem.isMapActive()
    obj.show(isVisible)
    if (isVisible && lastSelectedValue >= 0)
      obj.findObject("countries_container").setValue(lastSelectedValue)
  }
}
