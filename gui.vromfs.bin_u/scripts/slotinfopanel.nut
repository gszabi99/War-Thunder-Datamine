//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { FAVORITE_UNLOCKS_LIMIT, getFavoriteUnlocksNum,
  canAddFavorite } = require("%scripts/unlocks/favoriteUnlocks.nut")
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
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getCrewSpText } = require("%scripts/crew/crewPoints.nut")

let function getSkillCategoryView(crewData, unit) {
  let unitType = unit?.unitType ?? unitTypes.INVALID
  let crewUnitType = unitType.crewUnitType
  let unitName = unit?.name ?? ""
  let view = []
  foreach (skillCategory in getSkillCategories()) {
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

let class SlotInfoPanel extends gui_handlers.BaseGuiHandlerWT {
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
        fillerFunction = function() { this.updateAirInfo(true) }
      },
      {
        tooltip = "#slotInfoPanel/crewInfo/tooltip",
        imgId = "",
        imgBg = "#ui/gameuiskin#slot_crew.svg",
        discountId = "crew_lb_discount",
        contentId = "crew_info_content",
        fillerFunction = function() { this.updateCrewInfo(true) }
      },
      {
        tooltip = "#mainmenu/btnFavoritesUnlockAchievement",
        imgId = "",
        imgBg = "#ui/gameuiskin#sh_unlockachievement.svg",
        discountId = "",
        contentId = "unlockachievement_content",
        fillerFunction = function() { this.showUnlockAchievementInfo() }
      }
    ]

  favUnlocksHandlerWeak = null

  function initScreen() {
    this.infoPanelObj = this.scene.findObject("slot_info_side_panel")
    this.infoPanelObj.show(true)
    ::dmViewer.init(this)

    //Must be before replace fill tabs
    let buttonsPlace = this.scene.findObject("buttons_place")
    if (checkObj(buttonsPlace)) {
      let data = "".join(slotInfoPanelButtons.value.map(@(view) handyman.renderCached("%gui/commonParts/button.tpl", view)))
      this.guiScene.replaceContentFromText(buttonsPlace, data, data.len(), this)
    }

    let showTabsCount = this.showTabs ? this.tabsInfo.len() : 1

    this.listboxObj = this.scene.findObject("slot_info_listbox")
    if (checkObj(this.listboxObj)) {
      let view = { items = [] }
      for (local i = 0; i < showTabsCount; i++) {
        view.items.append({
          tooltip = this.tabsInfo[i].tooltip,
          imgId = this.tabsInfo[i].imgId,
          imgBg = this.tabsInfo[i].imgBg
          discountId = this.tabsInfo[i].discountId
        })
      }
      let data = handyman.renderCached("%gui/SlotInfoTabItem.tpl", view)
      this.guiScene.replaceContentFromText(this.listboxObj, data, data.len(), this)

      let unit = this.getCurShowUnit()
      this.updateUnitIcon(unit)

      let savedIndex = ::g_login.isProfileReceived() ?
        loadLocalAccountSettings(this.configSavePath, 0) : 0
      this.listboxObj.setValue(min(savedIndex, showTabsCount - 1))
      this.updateContentVisibility()

      this.listboxObj.show(view.items.len() > 1)
    }

    let unitInfoObj = this.scene.findObject("air_info_content_info")
    if (checkObj(unitInfoObj)) {
      let handler = handlersManager.getActiveBaseHandler()
      let hasSlotbar = handler?.getSlotbar()
      unitInfoObj["max-height"] = unitInfoObj[hasSlotbar ? "maxHeightWithSlotbar" : "maxHeightWithoutSlotbar"]
    }

    // Fixes DM selector being locked after battle.
    ::dmViewer.update()

    this.updateSceneVisibility()
  }

  function getCurShowUnitName() {
    return getShowedUnitName()
  }

  function getCurShowUnit() {
    return getShowedUnit()
  }

  function onUnitInfoTestDrive() {
    let unit = this.getCurShowUnit()
    if (!unit)
      return

    ::queues.checkAndStart(@() ::gui_start_testflight({ unit }), null, "isCanNewflight")
  }

  function onAirInfoWeapons() {
    let unit = this.getCurShowUnit()
    if (!unit)
      return

    ::open_weapons_for_unit(unit)
  }

  function onProtectionAnalysis() {
    let unit = this.getCurShowUnit()
    this.checkedCrewModify(
      @() handlersManager.animatedSwitchScene(@() protectionAnalysis.open(unit)))
  }

  function onShowExternalDmPartsChange(obj) {
    if (checkObj(obj))
      ::dmViewer.showExternalPartsArmor(obj.getValue())
  }

  function onShowHiddenXrayPartsChange(obj) {
    if (checkObj(obj))
      ::dmViewer.showExternalPartsXray(obj.getValue())
  }

  function onShowExtendedHintsChange(obj) {
    saveLocalAccountSettings("dmViewer/needShowExtHints", obj.getValue())
    ::dmViewer.resetXrayCache()
  }

  function onCollapseButton() {
    if (this.listboxObj)
      this.listboxObj.setValue(this.listboxObj.getValue() < 0 ? 0 : -1)
  }

  function onAirInfoToggleDMViewer(obj) {
    ::dmViewer.toggle(obj.getValue())
  }

  function onDMViewerHintTimer(obj, _dt) {
    ::dmViewer.placeHint(obj)
  }

  function updateContentVisibility(_obj = null) {
    let currentIndex = this.listboxObj.getValue()
    let isPanelHidden = currentIndex == -1
    let collapseBtnContainer = this.scene.findObject("slot_collapse")
    if (checkObj(collapseBtnContainer))
      collapseBtnContainer.collapsed = isPanelHidden ? "yes" : "no"
    this.showSceneBtn("slot_info_content", ! isPanelHidden)
    this.updateVisibleTabContent(true)
    if (::g_login.isProfileReceived())
      saveLocalAccountSettings(this.configSavePath, currentIndex)
  }

  function updateVisibleTabContent(isTabSwitch = false) {
    if (this.isSceneForceHidden || !checkObj(this.listboxObj))
      return
    let currentIndex = this.listboxObj.getValue()
    let isPanelHidden = currentIndex == -1
    foreach (index, tabInfo in this.tabsInfo) {
      let discountObj = this.listboxObj.findObject(tabInfo.discountId)
      if (checkObj(discountObj))
        discountObj.type = isPanelHidden ? "box_left" : "box_up"
      if (isPanelHidden)
        continue

      let isActive = index == currentIndex
      if (isTabSwitch)
        this.showSceneBtn(tabInfo.contentId, isActive)
      if (isActive)
        tabInfo.fillerFunction.call(this)
    }
  }

  function updateHeader(text, isPremium = false) {
    let header = this.scene.findObject("header_background")
    if (!checkObj(header))
      return

    header.type = isPremium ? "transparent" : ""
    header.findObject("content_header").setValue(text)
    header.findObject("header_premium_background").show(isPremium)
    header.findObject("premium_vehicle_icon").show(isPremium)
  }

  function updateAirInfo(force = false) {
    let unit = this.getCurShowUnit()
    this.updateUnitIcon(unit)

    let contentObj = this.scene.findObject("air_info_content")
    if (!checkObj(contentObj) || (! contentObj.isVisible() && ! force))
      return

    this.updateTestDriveButtonText(unit)
    this.updateWeaponryDiscounts(unit)
    ::showAirInfo(unit, true, contentObj, null, { showRewardsInfoOnlyForPremium = true })
    showObjById("aircraft-name", false, this.scene)
    this.updateHeader(getUnitName(unit), ::isUnitSpecial(unit))
  }

  function checkUpdateAirInfo() {
    let unit = this.getCurShowUnit()
    if (!unit)
      return

    let isAirInfoValid = ::check_unit_mods_update(unit)
                           && ::check_secondary_weapon_mods_recount(unit)
    if (!isAirInfoValid)
      this.doWhenActiveOnce("updateAirInfo")
  }

  function canShowScene() {
    return !this.isSceneForceHidden && this.getCurShowUnit() != null
  }

  function updateSceneVisibility() {
    let canShow = this.canShowScene()
    if (this.isSceneVisibilityAllowed == canShow)
      return
    this.isSceneVisibilityAllowed = canShow
    this.onSceneActivate(canShow)
  }

  function onSceneActivate(show) {
    if (show && !this.canShowScene())
      return

    if (show) {
      ::dmViewer.init(this)
      this.doWhenActiveOnce("updateVisibleTabContent")
    }
    base.onSceneActivate(show)
    if (checkObj(this.infoPanelObj))
      this.infoPanelObj.show(show)
  }

  function onEventShopWndVisible(p) {
    this.isSceneForceHidden = p?.isShopShow ?? false
    this.updateSceneVisibility()
  }

  function onEventModalWndDestroy(p) {
    base.onEventModalWndDestroy(p)
    if (this.isSceneActiveNoModals())
      this.checkUpdateAirInfo()
  }

  function onEventHangarModelLoading(_params) {
    this.doWhenActiveOnce("updateAirInfo")
    this.doWhenActiveOnce("updateCrewInfo")
    this.updateSceneVisibility()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    this.doWhenActiveOnce("updateAirInfo")
  }

  function onEventUnitModsRecount(params) {
    let unit = getTblValue("unit", params)
    if (unit && unit.name == this.getCurShowUnitName())
      this.doWhenActiveOnce("updateAirInfo")
  }

  function onEventSecondWeaponModsUpdated(params) {
    let unit = getTblValue("unit", params)
    if (unit && unit.name == this.getCurShowUnitName())
      this.doWhenActiveOnce("updateAirInfo")
  }

  function onEventMeasureUnitsChanged(_params) {
    this.doWhenActiveOnce("updateAirInfo")
  }

  function onEventCrewSkillsChanged(_params) {
    this.doWhenActiveOnce("updateCrewInfo")
  }

  function onEventQualificationIncreased(_params) {
    this.doWhenActiveOnce("updateCrewInfo")
  }

  function updateCrewInfo(force = false) {
    let contentObj = this.scene.findObject("crew_info_content")
    if (!checkObj(contentObj) || (! contentObj.isVisible() && ! force))
      return

    let crewCountryId = find_in_array(shopCountriesList, profileCountrySq.value, -1)
    let crewIdInCountry = getTblValue(crewCountryId, ::selected_crews, -1)
    let crewData = getCrew(crewCountryId, crewIdInCountry)
    if (crewData == null)
      return

    let unit = ::g_crew.getCrewUnit(crewData)
    if (unit == null)
      return

    let discountInfo = ::g_crew.getDiscountInfo(crewCountryId, crewIdInCountry)
    let maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo)
    let discountText = maxDiscount > 0 ? ("-" + maxDiscount + "%") : ""
    let discountTooltip = ::g_crew.getDiscountsTooltipByInfo(discountInfo)

    if (checkObj(this.listboxObj)) {
      let obj = this.listboxObj.findObject("crew_lb_discount")
      if (checkObj(obj)) {
        obj.setValue(discountText)
        obj.tooltip = discountTooltip
      }
    }

    let crewUnitType = unit.getCrewUnitType()
    let country  = getUnitCountry(unit)
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
      crewPoints = needCurPoints && getCrewSpText(getCrewPoints(crewData))
      crewStatus = ::get_crew_status(crewData, unit)
      crewSpecializationLabel = loc("crew/trained") + loc("ui/colon")
      crewSpecializationIcon = specType.trainedIcon
      crewSpecialization = specType.getName()
      categoryRows = getSkillCategoryView(crewData, unit)
      discountText = discountText
      discountTooltip = discountTooltip
    }
    let blk = handyman.renderCached("%gui/crew/crewInfo.tpl", view)
    this.guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    this.showSceneBtn("crew_name", false)
    this.updateHeader(::g_crew.getCrewName(crewData))
  }

  function showUnlockAchievementInfo() {
    if (! this.favUnlocksHandlerWeak) {
      let contentObj = this.scene.findObject("favorite_unlocks_placeholder")
      if (! checkObj(contentObj))
        return
      this.favUnlocksHandlerWeak = handlersManager.loadHandler(
        gui_handlers.FavoriteUnlocksListView, { scene = contentObj }).weakref()
      this.registerSubHandler(this.favUnlocksHandlerWeak)
    }
    else
      this.favUnlocksHandlerWeak.onSceneActivate(true)

    let cur = getFavoriteUnlocksNum()
    let text = loc("mainmenu/btnFavoritesUnlockAchievement") + loc("ui/parentheses/space", {
      text = colorize(canAddFavorite() ? "" : "warningTextColor", cur + loc("ui/slash") + FAVORITE_UNLOCKS_LIMIT)
    })

    this.updateHeader(text)
  }

  function onEventFavoriteUnlocksChanged(_p) {
    if (!this.showTabs)
      return

    let currentIndex = this.tabsInfo.findindex(@(e) e.contentId == "unlockachievement_content")
    if (this.listboxObj.getValue() == currentIndex) {
      this.showUnlockAchievementInfo()
    }
    else {
      this.listboxObj.setValue(currentIndex)
    }
  }

  function onAchievementsButtonClicked(_obj) {
    ::gui_start_profile({ initialSheet = "UnlockAchievement" })
  }

  function onEventCrewChanged(_params) {
    this.doWhenActiveOnce("updateAirInfo")
    this.doWhenActiveOnce("updateCrewInfo")
    this.updateSceneVisibility()
  }

  function updateUnitIcon(unit) {
    if (!unit)
      return

    let iconObj = this.scene.findObject("slot_info_vehicle_icon")
    if (checkObj(iconObj))
      iconObj["background-image"] = unit.unitType.testFlightIcon
  }

  function updateTestDriveButtonText(unit) {
    let obj = this.scene.findObject("btnTestdrive")
    if (!checkObj(obj))
      return

    obj.setValue(unit.unitType.getTestFlightText())
  }

  function updateWeaponryDiscounts(unit) {
    let discount = unit ? ::get_max_weaponry_discount_by_unitName(unit.name) : 0
    let discountObj = this.scene.findObject("btnAirInfoWeaponry_discount")
    ::showCurBonus(discountObj, discount, "mods", true, true)
    if (checkObj(discountObj))
      discountObj.show(discount > 0)

    if (checkObj(this.listboxObj)) {
      let obj = this.listboxObj.findObject("unit_lb_discount")
      if (checkObj(obj)) {
        obj.setValue(discount > 0 ? ("-" + discount + "%") : "")
        obj.tooltip = format(loc("discount/mods/tooltip"), discount.tostring())
      }
    }
  }

  function onCrewButtonClicked(_obj) {
    let crewCountryId = find_in_array(shopCountriesList, profileCountrySq.value, -1)
    let crewIdInCountry = getTblValue(crewCountryId, ::selected_crews, -1)
    if (crewCountryId != -1 && crewIdInCountry != -1)
      ::gui_modal_crew({ countryId = crewCountryId, idInCountry = crewIdInCountry })
  }

  function onEventUnitWeaponChanged(_params) {
    this.doWhenActiveOnce("updateAirInfo")
  }

  function uncollapse() {
    if (this.listboxObj.getValue() < 0)
      this.onCollapseButton()
  }

  function onEventCountryChanged(_p) {
    this.doWhenActiveOnce("updateCrewInfo")
  }
}

gui_handlers.SlotInfoPanel <- SlotInfoPanel

const SLOT_INFO_CFG_SAVE_PATH = "show_slot_info_panel_tab"

let function createSlotInfoPanel(parentScene, showTabs, configSaveId) {
  if (!checkObj(parentScene))
    return null

  let scene = parentScene.findObject("slot_info")
  if (!checkObj(scene))
    return null

  return handlersManager.loadHandler(SlotInfoPanel, {
    scene
    showTabs
    configSavePath = $"{SLOT_INFO_CFG_SAVE_PATH}/{configSaveId}"
  })
}

return {
  createSlotInfoPanel
}