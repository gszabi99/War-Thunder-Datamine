local protectionAnalysis = require("scripts/dmViewer/protectionAnalysis.nut")
local { getCrewPoints, getSkillCategories, categoryHasNonGunnerSkills, getSkillCategoryCrewLevel, getSkillCategoryMaxCrewLevel
} = require("scripts/crew/crewSkills.nut")
local { getSkillCategoryName } = require("scripts/crew/crewSkillsView.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { slotInfoPanelButtons } = require("scripts/slotInfoPanel/slotInfoPanelButtons.nut")
local { SKILL_CATEGORY } = require("scripts/utils/genericTooltipTypes.nut")

const SLOT_INFO_CFG_SAVE_PATH = "show_slot_info_panel_tab"

::create_slot_info_panel <- function create_slot_info_panel(parent_scene, show_tabs, configSaveId)
{
  if (!::check_obj(parent_scene))
    return null
  local containerObj = parent_scene.findObject("slot_info")
  if (!::check_obj(containerObj))
    return null
  local params = {
    scene = containerObj
    showTabs = show_tabs
    configSavePath = SLOT_INFO_CFG_SAVE_PATH + "/" + configSaveId
  }
  return ::handlersManager.loadHandler(::gui_handlers.SlotInfoPanel, params)
}

local function getSkillCategoryView(crewData, unit) {
  local unitType = unit?.unitType ?? unitTypes.INVALID
  local crewUnitType = unitType.crewUnitType
  local unitName = unit?.name ?? ""
  local view = []
  foreach (skillCategory in getSkillCategories())
  {
    local isSupported = (skillCategory.crewUnitTypeMask & (1 << crewUnitType)) != 0
      && (unit.gunnersCount > 0 || categoryHasNonGunnerSkills(skillCategory))
    if (!isSupported)
      continue
    view.append({
      categoryName = getSkillCategoryName(skillCategory)
      categoryTooltip = SKILL_CATEGORY.getTooltipId(skillCategory.categoryName, unitName)
      categoryValue = getSkillCategoryCrewLevel(crewData, unit, skillCategory, crewUnitType)
      categoryMaxValue = getSkillCategoryMaxCrewLevel(skillCategory, crewUnitType)
    })
  }
  return view
}

class ::gui_handlers.SlotInfoPanel extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/slotInfoPanel.blk"
  showTabs = false
  configSavePath = ""
  isSceneForceHidden = false
  infoPanelObj = null
  listboxObj = null

  tabsInfo = [
      {
        tooltip = "#slotInfoPanel/unitInfo/tooltip",
        imgId = "slot_info_vehicle_icon",
        imgBg = "#ui/gameuiskin#slot_testdrive.svg",
        discountId = "unit_lb_discount",
        contentId = "air_info_content",
        fillerFunction = function() { updateAirInfo(true) }
        reqFeature = ""
      },
      {
        tooltip = "#slotInfoPanel/crewInfo/tooltip",
        imgId = "",
        imgBg = "#ui/gameuiskin#slot_crew.svg",
        discountId = "crew_lb_discount",
        contentId = "crew_info_content",
        fillerFunction = function() { updateCrewInfo(true) }
        reqFeature = "CrewInfo"
      },
      {
        tooltip = "#mainmenu/btnFavoritesUnlockAchievement",
        imgId = "",
        imgBg = "#ui/gameuiskin#sh_unlockachievement.svg",
        discountId = "",
        contentId = "unlockachievement_content",
        fillerFunction = function() { showUnlockAchievementInfo() }
        reqFeature = "Profile"
      }
    ]

  favUnlocksHandlerWeak = null

  function initScreen()
  {
    infoPanelObj = scene.findObject("slot_info_side_panel")
    infoPanelObj.show(true)
    ::dmViewer.init(this)

    //Must be before replace fill tabs
    local buttonsPlace = scene.findObject("buttons_place")
    if (::check_obj(buttonsPlace))
    {
      local data = "".join(slotInfoPanelButtons.value.map(@(view) ::handyman.renderCached("gui/commonParts/button", view)))
      guiScene.replaceContentFromText(buttonsPlace, data, data.len(), this)
    }

    for (local i = tabsInfo.len() - 1; i >= 0; i--)
      if (tabsInfo[i].reqFeature != "" && !::has_feature(tabsInfo[i].reqFeature))
        tabsInfo.remove(i)

    local showTabsCount = showTabs ? tabsInfo.len() : 1

    listboxObj = scene.findObject("slot_info_listbox")
    if (::checkObj(listboxObj))
    {
      local view = { items = [] }
      for(local i = 0; i < showTabsCount; i++)
      {
        view.items.append({
          tooltip = tabsInfo[i].tooltip,
          imgId = tabsInfo[i].imgId,
          imgBg = tabsInfo[i].imgBg
          discountId = tabsInfo[i].discountId
        })
      }
      local data = ::handyman.renderCached("gui/SlotInfoTabItem", view)
      guiScene.replaceContentFromText(listboxObj, data, data.len(), this)

      updateUnitIcon()
      local savedIndex = ::g_login.isProfileReceived() ?
        ::load_local_account_settings(configSavePath, 0) : 0
      listboxObj.setValue(::min(savedIndex, showTabsCount - 1))
      updateContentVisibility()

      listboxObj.show(view.items.len() > 1)
    }

    local unitInfoObj = scene.findObject("air_info_content_info")
    if (::checkObj(unitInfoObj))
    {
      local handler = ::handlersManager.getActiveBaseHandler()
      local hasSlotbar = handler?.getSlotbar()
      unitInfoObj["max-height"] = unitInfoObj[hasSlotbar ? "maxHeightWithSlotbar" : "maxHeightWithoutSlotbar"]
    }

    // Fixes DM selector being locked after battle.
    ::dmViewer.update()
  }

  function getCurShowUnitName()
  {
    return ::hangar_get_current_unit_name()
  }

  function getCurShowUnit()
  {
    return ::getAircraftByName(getCurShowUnitName())
  }

  function onUnitInfoTestDrive()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return

    ::queues.checkAndStart(@() ::gui_start_testflight(unit), null, "isCanNewflight")
  }

  function onAirInfoWeapons()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return

    ::open_weapons_for_unit(unit)
  }

  function onProtectionAnalysis()
  {
    local unit = getCurShowUnit()
    checkedCrewModify(
      @() ::handlersManager.animatedSwitchScene(@() protectionAnalysis.open(unit)))
  }

  function onShowExternalDmPartsChange(obj)
  {
    if (::check_obj(obj))
      ::dmViewer.showExternalPartsArmor(obj.getValue())
  }

  function onShowHiddenXrayPartsChange(obj)
  {
    if (::check_obj(obj))
      ::dmViewer.showExternalPartsXray(obj.getValue())
  }

  function onCollapseButton()
  {
    if(listboxObj)
      listboxObj.setValue(listboxObj.getValue() < 0 ? 0 : -1)
  }

  function onAirInfoToggleDMViewer(obj)
  {
    ::dmViewer.toggle(obj.getValue())
  }

  function onDMViewerHintTimer(obj, dt)
  {
    ::dmViewer.placeHint(obj)
  }

  function updateContentVisibility(obj = null)
  {
    local currentIndex = listboxObj.getValue()
    local isPanelHidden = currentIndex == -1
    local collapseBtnContainer = scene.findObject("slot_collapse")
    if(::checkObj(collapseBtnContainer))
      collapseBtnContainer.collapsed = isPanelHidden ? "yes" : "no"
    showSceneBtn("slot_info_content", ! isPanelHidden)
    updateVisibleTabContent(true)
    if (::g_login.isProfileReceived())
      ::save_local_account_settings(configSavePath, currentIndex)
  }

  function updateVisibleTabContent(isTabSwitch = false)
  {
    if (isSceneForceHidden || !::check_obj(listboxObj))
      return
    local currentIndex = listboxObj.getValue()
    local isPanelHidden = currentIndex == -1
    foreach(index, tabInfo in tabsInfo)
    {
      local discountObj = listboxObj.findObject(tabInfo.discountId)
      if (::check_obj(discountObj))
        discountObj.type = isPanelHidden ? "box_left" : "box_up"
      if(isPanelHidden)
        continue

      local isActive = index == currentIndex
      if (isTabSwitch)
        showSceneBtn(tabInfo.contentId, isActive)
      if(isActive)
        tabInfo.fillerFunction.call(this)
    }
  }

  function updateHeader(text, isPremium = false)
  {
    local header = scene.findObject("header_background")
    if(!::check_obj(header))
      return

    header.type = isPremium ? "transparent" : ""
    header.findObject("content_header").setValue(text)
    header.findObject("header_premium_background").show(isPremium)
    header.findObject("premium_vehicle_icon").show(isPremium)
  }

  function updateAirInfo(force = false)
  {
    local unit = updateUnitIcon()

    local contentObj = scene.findObject("air_info_content")
    if ( !::checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    updateTestDriveButtonText(unit)
    updateWeaponryDiscounts(unit)
    ::showAirInfo(unit, true, contentObj, null, {showRewardsInfoOnlyForPremium = true})
    ::showBtn("aircraft-name", false, scene)
    updateHeader(::getUnitName(unit), ::isUnitSpecial(unit))
  }

  function checkUpdateAirInfo()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return

    local isAirInfoValid = ::check_unit_mods_update(unit)
                           && ::check_secondary_weapon_mods_recount(unit)
    if (!isAirInfoValid)
      doWhenActiveOnce("updateAirInfo")
  }

  function onSceneActivate(show)
  {
    if (show && isSceneForceHidden)
      return

    if (show)
    {
      ::dmViewer.init(this)
      doWhenActiveOnce("updateVisibleTabContent")
    }
    base.onSceneActivate(show)
    if (::check_obj(infoPanelObj))
      infoPanelObj.show(show)
  }

  function onEventShopWndVisible(p)
  {
    isSceneForceHidden = ::getTblValue("isShopShow", p, false)
    onSceneActivate(!isSceneForceHidden)
  }

  function onEventModalWndDestroy(p)
  {
    if (isSceneActiveNoModals())
      checkUpdateAirInfo()
    base.onEventModalWndDestroy(p)
  }

  function onEventHangarModelLoading(params)
  {
    doWhenActiveOnce("updateAirInfo")
    doWhenActiveOnce("updateCrewInfo")
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function onEventUnitModsRecount(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit && unit.name == getCurShowUnitName())
      doWhenActiveOnce("updateAirInfo")
  }

  function onEventSecondWeaponModsUpdated(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit && unit.name == getCurShowUnitName())
      doWhenActiveOnce("updateAirInfo")
  }

  function onEventMeasureUnitsChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function onEventCrewSkillsChanged(params)
  {
    doWhenActiveOnce("updateCrewInfo")
  }

  function onEventQualificationIncreased(params)
  {
    doWhenActiveOnce("updateCrewInfo")
  }

  function updateCrewInfo(force = false)
  {
    local contentObj = scene.findObject("crew_info_content")
    if ( !::checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_country_sq(), -1)
    local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
    local crewData = ::getSlotItem(crewCountryId, crewIdInCountry)
    if (crewData == null)
      return

    local unitName = ::getTblValue("aircraft", crewData, null)
    local unit = ::getAircraftByName(unitName)
    if (unit == null)
      return

    local discountInfo = ::g_crew.getDiscountInfo(crewCountryId, crewIdInCountry)
    local maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo)
    local discountText = maxDiscount > 0? ("-" + maxDiscount + "%") : ""
    local discountTooltip = ::g_crew.getDiscountsTooltipByInfo(discountInfo)

    if (::checkObj(listboxObj))
    {
      local obj = listboxObj.findObject("crew_lb_discount")
      if (::checkObj(obj))
      {
        obj.setValue(discountText)
        obj.tooltip = discountTooltip
      }
    }

    local crewUnitType = unit.getCrewUnitType()
    local country  = ::getUnitCountry(unit)
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crewData, unit)
    local isMaxLevel = ::g_crew.isCrewMaxLevel(crewData, unit, country, crewUnitType)
    local crewLevelText = ::g_crew.getCrewLevel(crewData, unit, crewUnitType)
    if (isMaxLevel)
      crewLevelText += ::colorize("@commonTextColor",
                                  ::loc("ui/parentheses/space", { text = ::loc("options/quality_max") }))
    local needCurPoints = !isMaxLevel

    local view = {
      crewName   = ::g_crew.getCrewName(crewData)
      crewLevelText  = crewLevelText
      needCurPoints = needCurPoints
      crewPoints = needCurPoints && ::get_crew_sp_text(getCrewPoints(crewData))
      crewStatus = ::get_crew_status(crewData, unit)
      crewSpecializationLabel = ::loc("crew/trained") + ::loc("ui/colon")
      crewSpecializationIcon = specType.trainedIcon
      crewSpecialization = specType.getName()
      categoryRows = getSkillCategoryView(crewData, unit)
      discountText = discountText
      discountTooltip = discountTooltip
    }
    local blk = ::handyman.renderCached("gui/crew/crewInfo", view)
    guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    showSceneBtn("crew_name", false)
    updateHeader(::g_crew.getCrewName(crewData))
  }

  function showUnlockAchievementInfo()
  {
    if( ! favUnlocksHandlerWeak)
    {
      local contentObj = scene.findObject("favorite_unlocks_placeholder")
      if(! ::checkObj(contentObj))
        return
      favUnlocksHandlerWeak = ::handlersManager.loadHandler(
        ::gui_handlers.FavoriteUnlocksListView, { scene = contentObj}).weakref()
      registerSubHandler(favUnlocksHandlerWeak)
    }
    else
      favUnlocksHandlerWeak.onSceneActivate(true)

    local cur = ::g_unlocks.getTotalFavoriteCount()
    local text = ::loc("mainmenu/btnFavoritesUnlockAchievement") + ::loc("ui/parentheses/space", {
      text = ::colorize(::g_unlocks.canAddFavorite()? "" : "warningTextColor", cur + ::loc("ui/slash") + ::g_unlocks.favoriteUnlocksLimit)
    })

    updateHeader(text)
  }

  function onEventFavoriteUnlocksChanged(p)
  {
    showUnlockAchievementInfo()
  }

  function onAchievementsButtonClicked(obj)
  {
    ::gui_start_profile({ initialSheet = "UnlockAchievement" })
  }

  function onEventCrewChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
    doWhenActiveOnce("updateCrewInfo")
  }

  function updateUnitIcon()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return null

    local iconObj = scene.findObject("slot_info_vehicle_icon")
    if (::checkObj(iconObj))
      iconObj["background-image"] = unit.unitType.testFlightIcon

    return unit
  }

  function updateTestDriveButtonText(unit)
  {
    local obj = scene.findObject("btnTestdrive")
    if (!::check_obj(obj))
      return

    obj.setValue(unit.unitType.getTestFlightText())
  }

  function updateWeaponryDiscounts(unit)
  {
    local discount = unit ? ::get_max_weaponry_discount_by_unitName(unit.name) : 0
    local discountObj = scene.findObject("btnAirInfoWeaponry_discount")
    ::showCurBonus(discountObj, discount, "mods", true, true)
    if (::check_obj(discountObj))
      discountObj.show(discount > 0)

    if (::checkObj(listboxObj))
    {
      local obj = listboxObj.findObject("unit_lb_discount")
      if (::checkObj(obj))
      {
        obj.setValue(discount > 0? ("-" + discount + "%") : "")
        obj.tooltip = ::format(::loc("discount/mods/tooltip"), discount.tostring())
      }
    }
  }

  function onCrewButtonClicked(obj)
  {
    local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_country_sq(), -1)
    local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
    if (crewCountryId != -1 && crewIdInCountry != -1)
      ::gui_modal_crew({ countryId = crewCountryId, idInCountry = crewIdInCountry })
  }

  function onEventUnitWeaponChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function uncollapse() {
    if (listboxObj.getValue() < 0)
      onCollapseButton()
  }

  function onEventCountryChanged(p) {
    doWhenActiveOnce("updateCrewInfo")
  }
}
