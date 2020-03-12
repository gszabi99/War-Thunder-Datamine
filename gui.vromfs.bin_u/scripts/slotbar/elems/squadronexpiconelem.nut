local elemModelType = require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local { topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")


elemModelType.addTypes({
  SQUADRON_EXP_ICON = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    isVisible = @() ::has_feature("ClanVehicles")
      && ::clan_get_exp() > 0 && ::clan_get_researching_unit() != ""

    getTooltip = @() ::format(::loc("mainmenu/availableFreeExpForNewResearch"),
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
      local isVisible = model.isVisible()
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

      local unit = ::getAircraftByName(::clan_get_researching_unit())
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

      local objConfig = ::split(obj.id, ";")
      local unit = ::getAircraftByName(::clan_get_researching_unit())
      isVisible = isVisible && unit?.shopCountry == objConfig?[0]
        && unit?.unitType?.armyId == objConfig?[1]
      obj.show(isVisible)
      if (isVisible)
        obj.tooltip = model.getTooltip()
    }
  }
})

return {}
