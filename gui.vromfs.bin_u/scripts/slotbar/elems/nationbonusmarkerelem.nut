//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { getUnitsWithNationBonuses, getNationBonusMarkState } = require("%scripts/nationBonuses/nationBonuses.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { addTooltipTypes, getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_ranks_blk } = require("blkGetters")

let { expNewNationBonusDailyBattleCount = 1 } = get_ranks_blk()

elemModelType.addTypes({
  NATION_BONUS_MARKER = {
    function init() {
      subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    }

    isVisible = @() hasFeature("ExpNewNationBonus")

    onEventShopWndSwitched = @(_p) this.notify([])
    onEventNationBonusMarkStateChange = @(_p) this.notify([])
    onEventUnitResearch = @(_p) this.notify([])
    onEventBattleEnded = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  SHOP_NATION_BONUS_MARKER = {
    model = elemModelType.NATION_BONUS_MARKER

    updateView = function(obj, _params) {
      if(!this.model.isVisible()) {
        obj.show(false)
        return
      }
      let countryBonuses = getUnitsWithNationBonuses().units
        .findindex(@(b) getNationBonusMarkState(b.unit.shopCountry, b.unit.unitType.armyId))
      obj.show(countryBonuses != null)
    }
  }

  COUNTRY_NATION_BONUS_MARKER = {
    model = elemModelType.NATION_BONUS_MARKER

    updateView = function(obj, _params) {
      if(!this.model.isVisible()) {
        obj.show(false)
        return
      }
      let countryBonuses = getUnitsWithNationBonuses().units
        .findindex(@(b) b.unit.shopCountry == obj.countryId && getNationBonusMarkState(obj.countryId, b.unit.unitType.armyId))
      obj.show(topMenuShopActive.value && countryBonuses != null)
    }
  }

  SHOP_PAGES_NATION_BONUS_MARKER = {
    model = elemModelType.NATION_BONUS_MARKER

    updateView = function(obj, _params) {
      if(!this.model.isVisible()) {
        obj.show(false)
        return
      }
      let showBonusMark = getNationBonusMarkState(obj.countryId, obj.armyId)
      if (!showBonusMark) {
        obj.show(showBonusMark)
        return
      }
      let { units, maxRanks } = getUnitsWithNationBonuses()
      let bonus = units.findvalue(@(b) b.unit.shopCountry == obj.countryId && b.unit.unitType.armyId == obj.armyId)
      obj.show(topMenuShopActive.value && bonus != null)
      if (bonus == null)
        return

      let nationBonusTooltipId = getTooltipType("SHOP_CELL_NATION_BONUS").getTooltipId("bonus", {
        unitName = $" ({getUnitName(bonus.unit.name, true)})"
        battlesRemain = bonus.battlesRemainCount
        maxRank = maxRanks?[obj.countryId][obj.armyId] ?? 0
        rank = bonus.unit.rank
        unitTypeName = bonus.unit.unitType.name
      })
      obj.findObject("nationBonusMarkerTooltip").tooltipId = nationBonusTooltipId
    }
  }
})

addTooltipTypes({
  NATIONBONUSES = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      let { countryId = "" } = params
      let { units } = getUnitsWithNationBonuses()
      let bonuses = countryId == "" ? units : units.filter(@(b) b.unit.shopCountry == countryId)
      let unitsWithBonus = bonuses
        .filter(@(b) getNationBonusMarkState(b.unit.shopCountry, b.unit.unitType.armyId))
        .map(@(b, idx) {
          hasCountry = countryId == ""
          unitName = getUnitName(b.unit.name, true)
          unitTypeIco = b.unit?.customClassIco ?? $"#ui/gameuiskin#{b.unit.name}_ico.svg"
          countryIcon = getUnitCountryIcon(b.unit)
          battlesRemain = $"{b.battlesRemainCount}/{expNewNationBonusDailyBattleCount}"
          even = idx % 2 == 0
        })

      let data = handyman.renderCached("%gui/nationBonus/nationBonusesTooltip.tpl", { units = unitsWithBonus })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {}
