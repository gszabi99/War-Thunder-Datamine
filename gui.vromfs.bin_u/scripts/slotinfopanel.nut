from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let protectionAnalysis = require("%scripts/dmViewer/protectionAnalysis.nut")
let { getCrewPoints, getSkillCategories, categoryHasNonGunnerSkills, getSkillCategoryCrewLevel, getSkillCategoryMaxCrewLevel
} = require("%scripts/crew/crewSkills.nut")
let { getSkillCategoryName } = require("%scripts/crew/crewSkillsView.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { slotInfoPanelButtons } = require("%scripts/slotInfoPanel/slotInfoPanelButtons.nut")
let { SKILL_CATEGORY } = require("%scripts/utils/genericTooltipTypes.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getShowedUnit, getShowedUnitName } = require("%scripts/slotbar/playerCurUnit.nut")
let { getCrew } = require("%scripts/crew/crew.nut")

const SLOT_INFO_CFG_SAVE_PATH = "show_slot_info_panel_tab"

::create_slot_info_panel <- function create_slot_info_panel(parent_scene, show_tabs, configSaveId)
{
  if (!checkObj(parent_scene))
    return null
  let containerObj = parent_scene.findObject("slot_info")
  if (!checkObj(containerObj))
    return null
  let params = {
    scene = containerObj
    showTabs = show_tabs
    configSavePath = SLOT_INFO_CFG_SAVE_PATH + "/" + configSaveId
  }
  return ::handlersManager.loadHandler(::gui_handlers.SlotInfoPanel, params)
}

let function getSkillCategoryView(crewData, unit) {
  let unitType = unit?.unitType ?? unitTypes.INVALID
  let crewUnitType = unitType.crewUnitType
  let unitName = unit?.name ?? ""
  let view = []
  foreach (skillCategory in getSkillCategories())
  {
    let isSupported = (skillCategory.crewUnitTypeMask & (1 << crewUnitType)) != 0
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

::gui_handlers.SlotInfoPanel <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/slotInfoPanel.blk"
  showTabs = false
  configSavePath = ""
  isSceneVisibilityAllowed = true
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
    let buttonsPlace = scene.findObject("buttons_place")
    if (checkObj(buttonsPlace))
    {
      let data = "".join(slotInfoPanelButtons.value.map(@(view) ::handyman.renderCached("%gui/commonParts/button", view)))
      guiScene.replaceContentFromText(buttonsPlace, data, data.len(), this)
    }

    for (local i = tabsInfo.len() - 1; i >= 0; i--)
      if (tabsInfo[i].reqFeature != "" && !hasFeature(tabsInfo[i].reqFeature))
        tabsInfo.remove(i)

    let showTabsCount = showTabs ? tabsInfo.len() : 1

    listboxObj = scene.findObject("slot_info_listbox")
    if (checkObj(listboxObj))
    {
      let view = { items = [] }
      for(local i = 0; i < showTabsCount; i++)
      {
        view.items.append({
          tooltip = tabsInfo[i].tooltip,
          imgId = tabsInfo[i].imgId,
          imgBg = tabsInfo[i].imgBg
          discountId = tabsInfo[i].discountId
        })
      }
      let data = ::handyman.renderCached("%gui/SlotInfoTabItem", view)
      guiScene.replaceContentFromText(listboxObj, data, data.len(), this)

      let unit = getCurShowUnit()
      updateUnitIcon(unit)

      let savedIndex = ::g_login.isProfileReceived() ?
        ::load_local_account_settings(configSavePath, 0) : 0
      listboxObj.setValue(min(savedIndex, showTabsCount - 1))
      updateContentVisibility()

      listboxObj.show(view.items.len() > 1)
    }

    let unitInfoObj = scene.findObject("air_info_content_info")
    if (checkObj(unitInfoObj))
    {
      let handler = ::handlersManager.getActiveBaseHandler()
      let hasSlotbar = handler?.getSlotbar()
      unitInfoObj["max-height"] = unitInfoObj[hasSlotbar ? "maxHeightWithSlotbar" : "maxHeightWithoutSlotbar"]
    }

    // Fixes DM selector being locked after battle.
    ::dmViewer.update()

    updateSceneVisibility()
  }

  function getCurShowUnitName()
  {
    return getShowedUnitName()
  }

  function getCurShowUnit()
  {
    return getShowedUnit()
  }

  function onUnitInfoTestDrive()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    ::queues.checkAndStart(@() ::gui_start_testflight({ unit }), null, "isCanNewflight")
  }

  function onAirInfoWeapons()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    ::open_weapons_for_unit(unit)
  }

  function onProtectionAnalysis()
  {
    let unit = getCurShowUnit()
    checkedCrewModify(
      @() ::handlersManager.animatedSwitchScene(@() protectionAnalysis.open(unit)))
  }

  function onShowExternalDmPartsChange(obj)
  {
    if (checkObj(obj))
      ::dmViewer.showExternalPartsArmor(obj.getValue())
  }

  function onShowHiddenXrayPartsChange(obj)
  {
    if (checkObj(obj))
      ::dmViewer.showExternalPartsXray(obj.getValue())
  }

  function onShowExtendedHintsChange(obj) {
    ::save_local_account_settings("dmViewver/needShowExtHints", obj.getValue())
    ::dmViewer.resetXrayCache()
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
    let currentIndex = listboxObj.getValue()
    let isPanelHidden = currentIndex == -1
    let collapseBtnContainer = scene.findObject("slot_collapse")
    if(checkObj(collapseBtnContainer))
      collapseBtnContainer.collapsed = isPanelHidden ? "yes" : "no"
    this.showSceneBtn("slot_info_content", ! isPanelHidden)
    updateVisibleTabContent(true)
    if (::g_login.isProfileReceived())
      ::save_local_account_settings(configSavePath, currentIndex)
  }

  function updateVisibleTabContent(isTabSwitch = false)
  {
    if (isSceneForceHidden || !checkObj(listboxObj))
      return
    let currentIndex = listboxObj.getValue()
    let isPanelHidden = currentIndex == -1
    foreach(index, tabInfo in tabsInfo)
    {
      let discountObj = listboxObj.findObject(tabInfo.discountId)
      if (checkObj(discountObj))
        discountObj.type = isPanelHidden ? "box_left" : "box_up"
      if(isPanelHidden)
        continue

      let isActive = index == currentIndex
      if (isTabSwitch)
        this.showSceneBtn(tabInfo.contentId, isActive)
      if(isActive)
        tabInfo.fillerFunction.call(this)
    }
  }

  function updateHeader(text, isPremium = false)
  {
    let header = scene.findObject("header_background")
    if(!checkObj(header))
      return

    header.type = isPremium ? "transparent" : ""
    header.findObject("content_header").setValue(text)
    header.findObject("header_premium_background").show(isPremium)
    header.findObject("premium_vehicle_icon").show(isPremium)
  }

  function updateAirInfo(force = false)
  {
    let unit = getCurShowUnit()
    updateUnitIcon(unit)

    let contentObj = scene.findObject("air_info_content")
    if ( !checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    updateTestDriveButtonText(unit)
    updateWeaponryDiscounts(unit)
    ::showAirInfo(unit, true, contentObj, null, {showRewardsInfoOnlyForPremium = true})
    ::showBtn("aircraft-name", false, scene)
    updateHeader(::getUnitName(unit), ::isUnitSpecial(unit))
  }

  function checkUpdateAirInfo()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    let isAirInfoValid = ::check_unit_mods_update(unit)
                           && ::check_secondary_weapon_mods_recount(unit)
    if (!isAirInfoValid)
      doWhenActiveOnce("updateAirInfo")
  }

  function canShowScene()
  {
    return !isSceneForceHidden && getCurShowUnit() != null
  }

  function updateSceneVisibility()
  {
    let canShow = canShowScene()
    if (isSceneVisibilityAllowed == canShow)
      return
    isSceneVisibilityAllowed = canShow
    onSceneActivate(canShow)
  }

  function onSceneActivate(show)
  {
    if (show && !canShowScene())
      return

    if (show)
    {
      ::dmViewer.init(this)
      doWhenActiveOnce("updateVisibleTabContent")
    }
    base.onSceneActivate(show)
    if (checkObj(infoPanelObj))
      infoPanelObj.show(show)
  }

  function onEventShopWndVisible(p)
  {
    isSceneForceHidden = p?.isShopShow ?? false
    updateSceneVisibility()
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
    updateSceneVisibility()
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function onEventUnitModsRecount(params)
  {
    let unit = getTblValue("unit", params)
    if (unit && unit.name == getCurShowUnitName())
      doWhenActiveOnce("updateAirInfo")
  }

  function onEventSecondWeaponModsUpdated(params)
  {
    let unit = getTblValue("unit", params)
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
    let contentObj = scene.findObject("crew_info_content")
    if ( !checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    let crewCountryId = ::find_in_array(shopCountriesList, ::get_profile_country_sq(), -1)
    let crewIdInCountry = getTblValue(crewCountryId, ::selected_crews, -1)
    let crewData = getCrew(crewCountryId, crewIdInCountry)
    if (crewData == null)
      return

    let unit = ::g_crew.getCrewUnit(crewData)
    if (unit == null)
      return

    let discountInfo = ::g_crew.getDiscountInfo(crewCountryId, crewIdInCountry)
    let maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo)
    let discountText = maxDiscount > 0? ("-" + maxDiscount + "%") : ""
    let discountTooltip = ::g_crew.getDiscountsTooltipByInfo(discountInfo)

    if (checkObj(listboxObj))
    {
      let obj = listboxObj.findObject("crew_lb_discount")
      if (checkObj(obj))
      {
        obj.setValue(discountText)
        obj.tooltip = discountTooltip
      }
    }

    let crewUnitType = unit.getCrewUnitType()
    let country  = ::getUnitCountry(unit)
    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crewData, unit)
    let isMaxLevel = ::g_crew.isCrewMaxLevel(crewData, unit, country, crewUnitType)
    local crewLevelText = ::g_crew.getCrewLevel(crewData, unit, crewUnitType)
    if (isMaxLevel)
      crewLevelText += colorize("@commonTextColor",
                                  loc("ui/parentheses/space", { text = loc("options/quality_max") }))
    let needCurPoints = !isMaxLevel

    let view = {
      crewName   = ::g_crew.getCrewName(crewData)
      crewLevelText  = crewLevelText
      needCurPoints = needCurPoints
      crewPoints = needCurPoints && ::get_crew_sp_text(getCrewPoints(crewData))
      crewStatus = ::get_crew_status(crewData, unit)
      crewSpecializationLabel = loc("crew/trained") + loc("ui/colon")
      crewSpecializationIcon = specType.trainedIcon
      crewSpecialization = specType.getName()
      categoryRows = getSkillCategoryView(crewData, unit)
      discountText = discountText
      discountTooltip = discountTooltip
    }
    let blk = ::handyman.renderCached("%gui/crew/crewInfo", view)
    guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    this.showSceneBtn("crew_name", false)
    updateHeader(::g_crew.getCrewName(crewData))
  }

  function showUnlockAchievementInfo()
  {
    if( ! favUnlocksHandlerWeak)
    {
      let contentObj = scene.findObject("favorite_unlocks_placeholder")
      if(! checkObj(contentObj))
        return
      favUnlocksHandlerWeak = ::handlersManager.loadHandler(
        ::gui_handlers.FavoriteUnlocksListView, { scene = contentObj}).weakref()
      registerSubHandler(favUnlocksHandlerWeak)
    }
    else
      favUnlocksHandlerWeak.onSceneActivate(true)

    let cur = ::g_unlocks.getTotalFavoriteCount()
    let text = loc("mainmenu/btnFavoritesUnlockAchievement") + loc("ui/parentheses/space", {
      text = colorize(::g_unlocks.canAddFavorite()? "" : "warningTextColor", cur + loc("ui/slash") + ::g_unlocks.favoriteUnlocksLimit)
    })

    updateHeader(text)
  }

  function onEventFavoriteUnlocksChanged(p)
  {
    let currentIndex = tabsInfo.findindex(@(e) e.contentId == "unlockachievement_content")
    if(listboxObj.getValue() == currentIndex){
      showUnlockAchievementInfo()
    }
    else
    {
      listboxObj.setValue(currentIndex)
    }
  }

  function onAchievementsButtonClicked(obj)
  {
    ::gui_start_profile({ initialSheet = "UnlockAchievement" })
  }

  function onEventCrewChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
    doWhenActiveOnce("updateCrewInfo")
    updateSceneVisibility()
  }

  function updateUnitIcon(unit)
  {
    if (!unit)
      return

    let iconObj = scene.findObject("slot_info_vehicle_icon")
    if (checkObj(iconObj))
      iconObj["background-image"] = unit.unitType.testFlightIcon
  }

  function updateTestDriveButtonText(unit)
  {
    let obj = scene.findObject("btnTestdrive")
    if (!checkObj(obj))
      return

    obj.setValue(unit.unitType.getTestFlightText())
  }

  function updateWeaponryDiscounts(unit)
  {
    let discount = unit ? ::get_max_weaponry_discount_by_unitName(unit.name) : 0
    let discountObj = scene.findObject("btnAirInfoWeaponry_discount")
    ::showCurBonus(discountObj, discount, "mods", true, true)
    if (checkObj(discountObj))
      discountObj.show(discount > 0)

    if (checkObj(listboxObj))
    {
      let obj = listboxObj.findObject("unit_lb_discount")
      if (checkObj(obj))
      {
        obj.setValue(discount > 0? ("-" + discount + "%") : "")
        obj.tooltip = format(loc("discount/mods/tooltip"), discount.tostring())
      }
    }
  }

  function onCrewButtonClicked(obj)
  {
    let crewCountryId = ::find_in_array(shopCountriesList, ::get_profile_country_sq(), -1)
    let crewIdInCountry = getTblValue(crewCountryId, ::selected_crews, -1)
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
