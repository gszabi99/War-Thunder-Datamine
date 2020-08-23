local { canUseIngameShop, getShopItem, getShopItemsTable } = ::is_platform_ps4? require("scripts/onlineShop/ps4ShopData.nut")
  : ::is_platform_xboxone? require("scripts/onlineShop/xboxShopData.nut")
    : { canUseIngameShop = @() false, getShopItem = @(...) null, getShopItemsTable = @() {} }

local unitStatus = require("scripts/unit/unitStatus.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
local unitContextMenuState = require("scripts/unit/unitContextMenuState.nut")
local selectUnitHandler = require("scripts/slotbar/selectUnitHandler.nut")
local selectGroupHandler = require("scripts/slotbar/selectGroupHandler.nut")
local crewModalByVehiclesGroups = require("scripts/crew/crewModalByVehiclesGroups.nut")
local { getBundleId } = require("scripts/onlineShop/onlineBundles.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local weaponryPresetsModal = require("scripts/weaponry/weaponryPresetsModal.nut")

local getActions = ::kwarg(function getActions(unitObj, unit, actionsNames, crew = null, curEdiff = -1,
  isSlotbarEnabled = true, setResearchManually = null, needChosenResearchOfSquadron = false,
  isSquadronResearchMode = false, hasSlotbarByUnitsGroups = false, shopResearchMode = false,
  shouldCheckCrewsReady = false, onSpendExcessExp = null, onCloseShop = null, slotbar = null
) {
  local actions = []
  if (!unit || ("airsGroup" in unit) || actionsNames.len()==0 || ::is_in_loading_screen())
    return actions

  local inMenu = ::isInMenu()
  local isUsable  = unit.isUsable()
  crew = crew ?? (hasSlotbarByUnitsGroups ? slotbarPresets.getCrewByUnit(unit) : ::getCrewByAir(unit))

  foreach(action in actionsNames)
  {
    local actionText = ""
    local showAction = false
    local actionFunc = null
    local haveWarning  = false
    local haveDiscount = false
    local disabled    = false
    local icon       = ""
    local isLink = false
    local iconRotation = 0

    if (action == "showroom")
    {
      actionText = ::loc(isUsable ? "mainmenu/btnShowroom" : "mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#slot_showroom.svg"
      showAction = inMenu
      actionFunc = function () {
        ::queues.checkAndStart(function () {
          ::broadcastEvent("BeforeStartShowroom")
          ::show_aircraft = unit
          ::handlersManager.animatedSwitchScene(::gui_start_decals)
        }, null, "isCanModifyCrew")
      }
    }
    else if (action == "preview")
    {
      actionText = ::loc("mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#btn_preview.svg"
      showAction = inMenu
      actionFunc = @() unit.doPreview()
    }
    else if (action == "aircraft")
    {
      if (crew == null || slotbar == null)
        continue

      actionText = ::loc("multiplayer/changeAircraft")
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      showAction = inMenu && ::SessionLobby.canChangeCrewUnits()
      actionFunc = function () {
        if (::g_crews_list.isSlotbarOverrided)
        {
          ::showInfoMsgBox(::loc("multiplayer/slotbarOverrided"))
          return
        }
        ::queues.checkAndStart(
          function() {
            ::g_squad_utils.checkSquadUnreadyAndDo(
              @() selectUnitHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
          }, null, "isCanModifyCrew")
      }
    }
    else if (action == "crew")
    {
      if (crew == null)
        continue

      local discountInfo = ::g_crew.getDiscountInfo(crew.idCountry, crew.idInCountry)

      actionText = ::loc("mainmenu/btnCrew")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      haveWarning = ::isInArray(::get_crew_status(crew, unit), [ "ready", "full" ])
      haveDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo) > 0
      showAction = inMenu && ::has_feature("CrewInfo") && !::g_crews_list.isSlotbarOverrided
      local params = {
        countryId = crew.idCountry,
        idInCountry = crew.idInCountry,
        curEdiff = curEdiff
        needHideSlotbar = !isSlotbarEnabled
      }

      actionFunc = function() {
        if (hasSlotbarByUnitsGroups)
          crewModalByVehiclesGroups.open(params)
        else
          ::gui_modal_crew(params)
      }
    }
    else if (action == "sec_weapons")
    {
      if (hasSlotbarByUnitsGroups)
        continue

      actionText = ::loc("options/secondary_weapons")
      icon       = "#ui/gameuiskin#slot_preset.svg"
      haveWarning = ::checkUnitWeapons(unit) != UNIT_WEAPONS_READY
      haveDiscount = ::get_max_weaponry_discount_by_unitName(unit.name) > 0
      showAction = inMenu && !::g_crews_list.isSlotbarOverrided &&
        (unit.isAir() || unit.isHelicopter()) && ::isAirHaveSecondaryWeapons(unit) &&
          ::has_feature("ShowWeapPresetsMenu")
      actionFunc = @() weaponryPresetsModal.open({ unit = unit })
    }
    else if (action == "weapons")
    {
      if (hasSlotbarByUnitsGroups)
        continue

      actionText = ::loc("mainmenu/btnWeapons")
      icon       = "#ui/gameuiskin#btn_weapons.svg"
      haveWarning = ::checkUnitWeapons(unit) != UNIT_WEAPONS_READY
      haveDiscount = ::get_max_weaponry_discount_by_unitName(unit.name) > 0
      showAction = inMenu && !::g_crews_list.isSlotbarOverrided
      actionFunc = @() ::open_weapons_for_unit(unit, {
        curEdiff = curEdiff
        needHideSlotbar = !isSlotbarEnabled
      })
    }
    else if (action == "take")
    {
      actionText = ::loc("mainmenu/btnTakeAircraft")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      showAction = inMenu && isUsable && !::isUnitInSlotbar(unit)
      actionFunc = @() unitActions.take(unit, {
        unitObj = unitObj
        shouldCheckCrewsReady = shouldCheckCrewsReady
      })
    }
    else if (action == "repair")
    {
      local repairCost = ::wp_get_repair_cost(unit.name)
      actionText = ::loc("mainmenu/btnRepair")+": "+::Cost(repairCost).getTextAccordingToBalance()
      icon       = "#ui/gameuiskin#slot_repair.svg"
      haveWarning = true
      showAction = inMenu && isUsable && repairCost > 0 && ::SessionLobby.canChangeCrewUnits()
        && !::g_crews_list.isSlotbarOverrided
      actionFunc = @() unitActions.repairWithMsgBox(unit)
    }
    else if (action == "buy")
    {
      local isSpecial   = ::isUnitSpecial(unit)
      local isGift   = ::isUnitGift(unit)
      local canBuyOnline = ::canBuyUnitOnline(unit)
      local canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
      local canBuyIngame = !canBuyOnline && (::canBuyUnit(unit) || canBuyNotResearchedUnit)
      local forceShowBuyButton = false
      local priceText = ""

      if (canBuyIngame)
      {
        local price = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
        priceText = price.getTextAccordingToBalance()
        if (priceText.len())
          priceText = ::loc("ui/colon") + priceText
      }

      actionText = ::loc("mainmenu/btnOrder") + priceText

      if (isGift && canUseIngameShop())
      {
        if (getShopItemsTable().len() == 0)
        {
          //Override for ingameShop.
          //There is rare posibility, that shop data is empty.
          //Because of external error.
          canBuyOnline = false
        }
        else if (!unit.isBought() && unit.getEntitlements().map(
            @(id) getBundleId(id)
          ).filter(
            @(bundleId) bundleId != "" && getShopItem(bundleId) != null
          ).len() == 0)
        {
          actionText = ::loc("mainemnu/comingsoon")
          disabled = true
          forceShowBuyButton = true
        }
      }

      icon       = isGift ? ( canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg"
                            : "#ui/gameuiskin#store_icon.svg")
                        : isSpecial || canBuyNotResearchedUnit ? "#ui/gameuiskin#shop_warpoints_premium"
                            : "#ui/gameuiskin#shop_warpoints"

      showAction = inMenu && (canBuyIngame || canBuyOnline || forceShowBuyButton)
      isLink     = !canUseIngameShop() && canBuyOnline
      if (canBuyOnline)
        actionFunc = @() OnlineShopModel.showGoods({ unitName = unit.name }, "unit_context_menu")
      else
        actionFunc = @() ::buyUnit(unit)
    }
    else if (action == "research")
    {
      if (::isUnitResearched(unit))
        continue

      local isInResearch = ::isUnitInResearch(unit)
      local isSquadronVehicle = unit.isSquadronVehicle()
      local isInClan = ::is_in_clan()
      local reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      local squadronExp = min(::clan_get_exp(), reqExp)
      local canFlushSquadronExp = ::has_feature("ClanVehicles") && isSquadronVehicle
        && squadronExp > 0
      if (isSquadronVehicle && isInClan && isInResearch && !canFlushSquadronExp && !needChosenResearchOfSquadron)
        continue

      local countryExp = ::shop_get_country_excess_exp(::getUnitCountry(unit), ::get_es_unit_type(unit))
      local getReqExp = reqExp < countryExp ? reqExp : countryExp
      local needToFlushExp = !isSquadronVehicle && shopResearchMode && countryExp > 0
      local squadronExpText = ::Cost().setSap(squadronExp).tostring()

      actionText = needToFlushExp || (isSquadronResearchMode && needChosenResearchOfSquadron)
        ? ::format(::loc("mainmenu/btnResearch")
          + (needToFlushExp || canFlushSquadronExp ? " (%s)" : ""),
          isSquadronVehicle
            ? squadronExpText
            : ::Cost().setRp(getReqExp).tostring())
        : canFlushSquadronExp && (isInResearch || isSquadronResearchMode)
          ? ::format(::loc("mainmenu/btnInvestSquadronExp") + " (%s)", squadronExpText)
            : isInResearch && setResearchManually && !isSquadronVehicle
              ? ::loc("mainmenu/btnConvert")
              : ::loc("mainmenu/btnResearch")
      showAction = inMenu && (!isInResearch || (::has_feature("SpendGold") && ::has_feature("SpendFreeRP")))
        && (::isUnitFeatureLocked(unit) || ::canResearchUnit(unit)
          || canFlushSquadronExp || (isSquadronVehicle && !::is_in_clan()))
      disabled = !showAction
      actionFunc = needToFlushExp
        || (isSquadronResearchMode && (needChosenResearchOfSquadron || canFlushSquadronExp))
        ? function() {onSpendExcessExp?()}
        : canFlushSquadronExp && isInResearch
          ? function() { unitActions.flushSquadronExp(unit) }
          : !setResearchManually
            ? function () { onCloseShop?() }
            : isInResearch && !isSquadronVehicle
              ? function () { ::gui_modal_convertExp(unit) }
              : function () {
                  if (!::checkForResearch(unit))
                    return

                  unitActions.research(unit)
                }
    }
    else if (action == "testflight" || action == "testflightforced")
    {
      local shouldSkipUnitCheck = action == "testflightforced"

      actionText = unit.unitType.getTestFlightText()
      icon       = unit.unitType.testFlightIcon
      showAction = inMenu && ::isTestFlightAvailable(unit, shouldSkipUnitCheck)
      actionFunc = function () {
        ::queues.checkAndStart(@() ::gui_start_testflight(unit, null, shouldSkipUnitCheck),
          null, "isCanNewflight")
      }
    }
    else if (action == "info")
    {
      actionText = ::loc("mainmenu/btnAircraftInfo")
      icon       = "#ui/gameuiskin#btn_info.svg"
      showAction = ::isUnitDescriptionValid(unit)
      isLink     = ::has_feature("WikiUnitInfo")
      actionFunc = function () {
        if (::has_feature("WikiUnitInfo"))
          openUrl(::format(::loc("url/wiki_objects"), unit.name), false, false, "unit_actions")
        else
          ::showInfoMsgBox(::colorize("activeTextColor", ::getUnitName(unit, false)) + "\n" + ::loc("profile/wiki_link"))
      }
    }
    else if (action == "find_in_market")
    {
      actionText = ::loc("msgbox/btn_find_on_marketplace")
      icon       = "#ui/gameuiskin#gc.svg"
      showAction = canBuyUnitOnMarketplace(unit)
      isLink     = true
      actionFunc = function(){
        local item = ::ItemsManager.findItemById(unit.marketplaceItemdefId)
        if (item && item.hasLink())
          item.openLink()
      }
    }
    else if (action == "changeUnitsGroup")
    {
      actionText = ::loc("mainmenu/changeUnitsGroup")
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      iconRotation = 90
      showAction = inMenu && hasSlotbarByUnitsGroups && crew != null && slotbar!= null
      actionFunc = function () {
        ::queues.checkAndStart(
          function() {
            ::g_squad_utils.checkSquadUnreadyAndDo(
              @() selectGroupHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
          }, null, "isCanModifyCrew")
      }
    }

    actions.append({
      actionName   = action
      text         = actionText
      show         = showAction
      disabled     = disabled
      icon         = icon
      action       = actionFunc
      haveWarning  = haveWarning
      haveDiscount = haveDiscount
      isLink       = isLink
      iconRotation = iconRotation
    })
  }

  return actions
})

local showMenu = function showMenu(params) {
  local actions = getActions(params)
  if (actions.len() == 0)
    return

  ::gui_handlers.ActionsList.open(params.unitObj, {
    handler = null
    closeOnUnhover = params?.closeOnUnhover ?? true
    onDeactivateCb = @() unitContextMenuState(null)
    actions = actions
  })
}

unitContextMenuState.subscribe(function (v) {
  if (v != null)
    showMenu(v)
})

return showMenu
