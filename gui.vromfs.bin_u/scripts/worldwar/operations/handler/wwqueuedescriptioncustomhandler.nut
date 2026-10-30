import "%scripts/worldWar/worldWarUtils.nut" as g_world_war
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/worldWar/operations/handler/wwMapDescription.nut" import WwMapDescription
from "%scripts/money.nut" import Cost
from "%scripts/sqDagui/daguiUtil.nut" import getObjValidIndex
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut" import getCustomViewCountryData
from "%scripts/worldWar/operations/model/wwGlobalStatus.nut" import getGlobalStatusData
from "%globalScripts/wwNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

register_gui_handler("WwQueueDescriptionCustomHandler", class (WwMapDescription) {
  function mapCountriesToView(side, _amountByCountry, joinedCountries) {
    let countriesByTeams = this.descItem.getCountriesByTeams()
    let countries = countriesByTeams?[side] ?? []
    let mapName = this.descItem.getId()
    let creationCost = this.getCreationCost()
    let hasCreationCost = creationCost != ""

    let createOperationBtnText = hasCreationCost
      ? $"{loc("worldwar/btnCreateOperation")} ({creationCost})"
      : loc("worldwar/btnCreateOperation")

    let buttonWidth = to_pixels("0.35@WWOperationDescriptionWidth - 1@buttonIconHeight")
    let textWidth = getStringWidthPx(createOperationBtnText, "fontMedium", this.guiScene)

    let smallFont = textWidth >= buttonWidth

    return {
      countries = countries.map(function(countryId) {
        let customViewCountryData = getCustomViewCountryData(countryId, mapName)
        let customLocId = customViewCountryData.locId
        let countryNameText = countryId == customLocId
          ? loc(countryId)
          : "".concat(loc(customLocId), loc("ui/parentheses/space", { text = loc(countryId) }))
        return {
          countryNameText = countryNameText
          countryId       = countryId
          countryIcon     = customViewCountryData.icon
          isJoined        = isInArray(countryId, joinedCountries)
          side            = side
          isLeftAligned   = side == SIDE_1
          hasCreationCost = hasCreationCost
          createOperationBtnText
          smallFont
        }
      })
    }
  }

  function getCreationCost() {
    let fee = getGlobalStatusData()?.operationCreationFeeWp ?? 0
    return fee > 0
      ? Cost(fee).toStringWithParams({ isColored = false isWpAlwaysShown = true })
      : ""
  }

  function updateCountriesList() {
    let obj = this.scene.findObject("div_before_text")
    if (!checkObj(obj))
      return

    let amountByCountry = this.descItem.getArmyGroupsAmountByCountries()
    let joinedCountries = this.descItem.getMyClanCountries()
    let sides = []
    foreach (side in g_world_war.getCommonSidesOrder())
      sides.append(this.mapCountriesToView(side, amountByCountry, joinedCountries))
    let view = {
      sides = sides
      vsText = "".concat(loc("country/VS"), "\n ")
    }

    let lastSelectedValue = getObjValidIndex(obj.findObject("countries_container"))
    let data = handyman.renderCached("%gui/worldWar/wwOperationCountriesInfo.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    let isVisible = this.descItem.isMapActive()
    obj.show(isVisible)
    if (isVisible && lastSelectedValue >= 0)
      obj.findObject("countries_container").setValue(lastSelectedValue)
  }
})
