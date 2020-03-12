class ::gui_handlers.WwQueueDescriptionCustomHandler extends ::gui_handlers.WwMapDescription
{
  function mapCountriesToView(countries, amountByCountry, joinedCountries)
  {
    local minTeamsInfoText = descItem.getMinClansCondition()
    local getTeamsInfoText = function (countryName) {
      local isJoined = ::isInArray(countryName, joinedCountries)
      local text = ::getTblValue(countryName, amountByCountry, "").tostring()

      return (isJoined ? ::colorize("@userlogColoredText", text) : text) + "/" + minTeamsInfoText
    }

    return {
      countries = ::u.map(countries,
        @(countryName) {
          countryName   = countryName
          countryIcon   = ::get_country_icon(countryName)
          isJoined      = ::isInArray(countryName, joinedCountries)
          teamsInfoText = getTeamsInfoText(countryName)
        })
    }
  }

  function updateCountriesList()
  {
    local obj = scene.findObject("div_before_text")
    if (!::checkObj(obj))
      return

    local cuntriesByTeams = descItem.getCountriesByTeams()
    local amountByCountry = descItem.getArmyGroupsAmountByCountries()
    local joinedCountries = descItem.getMyClanCountries()

    local view = {
      side1 = mapCountriesToView(::getTblValue(::SIDE_1, cuntriesByTeams, {}), amountByCountry, joinedCountries)
      side2 = mapCountriesToView(::getTblValue(::SIDE_2, cuntriesByTeams, {}), amountByCountry, joinedCountries)
      vsText = ::loc("country/VS") + "\n "
    }
    local data = ::handyman.renderCached("gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    obj.show(descItem.isMapActive())
  }
}
