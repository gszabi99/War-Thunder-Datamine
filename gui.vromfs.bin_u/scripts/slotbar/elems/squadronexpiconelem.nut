from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format, split_by_chars } = require("string")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { isAllClanUnitsResearched } = require("%scripts/unit/squadronUnitAction.nut")
let { subscribe } = require("%scripts/seen/seenListEvents.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)


elemModelType.addTypes({
  SQUADRON_EXP_ICON = {
    init = function() {
      ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
      subscribe(seenList.id, null, Callback(@() notify([]), this))
    }

    isVisible = @() seenList.getNewCount() == 0
      && hasFeature("ClanVehicles")
      && ::clan_get_exp() > 0
      && ::clan_get_researching_unit() != ""
      && !isAllClanUnitsResearched()

    getTooltip = @() format(loc("mainmenu/availableFreeExpForNewResearch"),
      ::Cost().setSap(::clan_get_exp()).tostring())

    onEventFlushSquadronExp = @(p) notify([])
    onEventShopWndSwitched = @(p) notify([])
    onEventClanChanged = @(p) notify([])
    onEventUnitResearch = @(p) notify([])
    onEventSquadronExpChanged = @(p) notify([])
  }
})


elemViewType.addTypes({
  SHOP_SQUADRON_EXP_ICON = {
    model = elemModelType.SQUADRON_EXP_ICON

    updateView = function(obj, params)
    {
      let isVisible = model.isVisible()
      obj.show(isVisible)
      if (isVisible)
        obj.tooltip = model.getTooltip()
    }
  }

  COUNTRY_SQUADRON_EXP_ICON = {
    model = elemModelType.SQUADRON_EXP_ICON

    updateView = function(obj, params)
    {
      local isVisible = topMenuShopActive.value && model.isVisible()
      if(!isVisible)
      {
        obj.show(isVisible)
        return
      }

      let unit = ::getAircraftByName(::clan_get_researching_unit())
      isVisible = isVisible && unit?.shopCountry == obj.countryId
      obj.show(isVisible)
      if (isVisible)
        obj.tooltip = model.getTooltip()
    }
  }

  SHOP_PAGES_SQUADRON_EXP_ICON = {
    model = elemModelType.SQUADRON_EXP_ICON

    updateView = function(obj, params)
    {
      local isVisible = topMenuShopActive.value && model.isVisible()
      if(!isVisible)
      {
        obj.show(isVisible)
        return
      }

      let objConfig = split_by_chars(obj.id, ";")
      let unit = ::getAircraftByName(::clan_get_researching_unit())
      isVisible = isVisible && unit?.shopCountry == objConfig?[0]
        && unit?.unitType?.armyId == objConfig?[1]
      obj.show(isVisible)
      if (isVisible)
        obj.tooltip = model.getTooltip()
    }
  }
})

return {}
