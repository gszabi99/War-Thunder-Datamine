from "%scripts/dagui_natives.nut" import get_unlock_type, select_current_title
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import USE_STEAM_LOGIN_AUTO_SETTING_ID
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/utils_sa.nut" import buildTableRowNoPad
from "app" import APP_ID, isAppActive
from "%sqstd/platform.nut" import is_gdk

let { openSelectUnitWnd } = require("%scripts/unit/selectUnitModal.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalSharedSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { defer, setTimeout, clearTimer } = require("dagor.workcycle")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { getAllUnlocksWithBlkOrder, getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let time = require("%scripts/time.nut")
let externalIDsService = require("%scripts/user/externalIdsService.nut")
let { isMeXBOXPlayer, isMePS4Player, isPlatformPC, isPlatformSony } = require("%scripts/clientState/platform.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { getViralAcquisitionDesc, showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { fillProfileSummary, getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { makeConfigStrByList } = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { launchEmailRegistration, canEmailRegistration, emailRegistrationTooltip,
  needShowGuestEmailRegistration } = require("%scripts/user/suggestionEmailRegistration.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getPlayerSsoShortTokenAsync } = require("auth_wt")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { get_gui_regional_blk } = require("blkGetters")
let { userIdStr, userIdInt64, havePlayerTag, isGuestLogin } = require("%scripts/user/profileStates.nut")
let { getStats, clearStats } = require("%scripts/myStats.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { steam_is_running, steam_is_overlay_active } = require("steam")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getEditViewData, getShowcaseTypeBoxData, saveShowcase, getDiffByIndex, fillStatsValuesOfTerseInfo,
  getGameModeBoxIndex, getShowcaseByTerseInfo, getShowcaseIndexByTerseName, saveUnitToTerseInfo, trySetBestShowcaseMode,
  writeGameModeToTerseInfo, getShowcaseUnitsFilter, getShowcaseGameModeByIndex, getShowcaseByIndex } = require("%scripts/user/profileShowcase.nut")
let { fillGamercard } = require("%scripts/gamercard/fillGamercard.nut")
let { addGamercardScene } = require("%scripts/gamercard/gamercardHelpers.nut")
let { generateShowcaseInfo } = require("%scripts/user/profileShowcasesData.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { is_builtin_browser_active } = require("%scripts/onlineShop/browserWndHelpers.nut")
let { saveProfileAppearance, getProfileHeaderBackgrounds } = require("%scripts/user/profileAppearance.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { selectUnitWndFilters } = require("%scripts/user/showcase/showcaseValues.nut")
let { getShopCountry } = require("%scripts/shop/shopCountryInfo.nut")
let { gui_choose_image } = require("%scripts/chooseImage.nut")
let { openCollectionsPage, hasAvailableCollections } = require("%scripts/collections/collectionsHandler.nut")
let { openSkinsPage } = require("%scripts/user/skins/skinsHandler.nut")
let { openDecalsPage } = require("%scripts/user/decals/decalsHandler.nut")
let { openAchievementsPage } = require("%scripts/user/achievements/achievementsHandler.nut")
require("%scripts/user/userCard/userCard.nut") 
let { getAvatarIconIdByUserInfo } = require("%scripts/user/avatars.nut")

let seenUnlockMarkers = seenList.get(SEEN.UNLOCK_MARKERS)
let seenManualUnlocks = seenList.get(SEEN.MANUAL_UNLOCKS)

function getSkinCountry(skinName) {
  let len0 = skinName.indexof("/")
  return len0 ? getShopCountry(skinName.slice(0, len0)) : ""
}

function getUnlockFiltersList(uType, getCategoryFunc) {
  let categories = []
  let unlocks = getUnlocksByTypeInBlkOrder(uType)
  foreach (unlock in unlocks)
    if (isUnlockVisible(unlock))
      u.appendOnce(getCategoryFunc(unlock), categories, true)

  return categories
}

function guiStartProfile(params = {}) {
  let guiScene = get_gui_scene()
  if (guiScene?.isInAct()) {
    defer(@() loadHandler(gui_handlers.Profile, params))
    return
  }
  loadHandler(gui_handlers.Profile, params)
}

gui_handlers.Profile <- class (gui_handlers.UserCardHandler) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/profile/profile.tpl"
  initialSheet = ""
  initialUnlockId = ""
  curDifficulty = "any"
  curPlayerMode = 0
  curSubFilter = -1

  statsType = ETTI_VALUE_INHISORY

  pending_logout = false
  currentShowcaseName = ""

  presetSheetList = ["UserCard", "Records", "Statistics", "Medal", "UnlockAchievement", "UnlockSkin", "UnlockDecal", "Collections"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"
  defaultTabImageName = "unlockachievement"

  sheetsList = null
  customMenuTabs = null
  applyFilterTimer = null
  profileHeaderBackground = null

  unlockTypesToShow = [
    UNLOCKABLE_ACHIEVEMENT,
    UNLOCKABLE_CHALLENGE,
    UNLOCKABLE_TROPHY,
    UNLOCKABLE_TROPHY_PSN,
    UNLOCKABLE_TROPHY_XBOXONE,
    UNLOCKABLE_TROPHY_STEAM
  ]

  unlocksPages = [
    UNLOCKABLE_ACHIEVEMENT
    UNLOCKABLE_SKIN
    UNLOCKABLE_DECAL
    UNLOCKABLE_MEDAL
  ]

  curAchievementGroupName = ""
  filterUnitTag = ""
  filterCountryName = ""
  filterGroupName = ""
  initSkinId = ""
  isEditModeEnabled = false
  editModeTempData = null
  curUnitImageIdx = -1

  unlockFilters = {
    UnlockAchievement = null
    UnlockChallenge = null
    UnlockSkin = []
  }

  filterTable = {
    Medal = "country"
    UnlockSkin = "airCountry"
  }

  selectedDecoratorId = null
  skinsPageHandlerWeak = null
  decalsPageHandlerWeak = null
  achievementsPageHandlerWeak = null

  function initScreen() {
    this.editModeTempData = {}

    setBreadcrumbGoBackParams(this)
    if (!this.scene)
      return this.goBack()

    addGamercardScene(this.scene) 

    this.isOwnStats = true
    this.scene.findObject("profile_update").setUserData(this)

    let needShortSeparators = to_pixels("sw") > to_pixels("1@maxProfileFrameWidth + 2@framePadding")
    let frame = this.scene.findObject("wnd_frame")
    frame.needShortSeparators = needShortSeparators ? "yes" : "no"

    
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    
    let skinCountries = getUnlockFiltersList("skin", function(unlock) {
      let country = getSkinCountry(unlock.getStr("id", ""))
      return (country != "") ? country : null
    })
    this.unlockFilters.UnlockSkin = shopCountriesList.filter(@(c) isInArray(c, skinCountries))

    this.initStatsParams()
    this.updateCurrentStatsMode(this.curMode)
    this.initSheetsList()
    this.initTabs()
    let bntGetLinkObj = this.scene.findObject("btn_getLink")
    if (checkObj(bntGetLinkObj))
      bntGetLinkObj.tooltip = getViralAcquisitionDesc("mainmenu/getLinkDesc")

    this.initShortcuts()
    this.updateProfileAppearance()
  }

  function initSheetsList() {
    this.customMenuTabs = {}
    this.sheetsList = clone this.presetSheetList
    local hasAnyUnlocks = false
    local hasAnyMedals = false 

    let customCategoryConfig = getTblValue("customProfileMenuTab", get_gui_regional_blk(), null)
    local tabImage = null
    local tabText = null

    foreach (cb in getAllUnlocksWithBlkOrder()) {
      let unlockType = cb?.type ?? ""
      let unlockTypeId = get_unlock_type(unlockType)

      if (!this.unlockTypesToShow.contains(unlockTypeId) && !this.unlocksPages.contains(unlockTypeId))
        continue
      if (!isUnlockVisible(cb))
        continue

      hasAnyUnlocks = true
      if (unlockTypeId == UNLOCKABLE_MEDAL)
        hasAnyMedals = true

      if (cb?.customMenuTab == null)
        continue

      let lowerCaseTab = cb.customMenuTab.tolower()
      if (lowerCaseTab in this.customMenuTabs)
        continue

      this.sheetsList.append(lowerCaseTab)
      this.unlockFilters[lowerCaseTab] <- null

      let defaultImage = format(this.tabImageNameTemplate, this.defaultTabImageName)

      if (cb.customMenuTab in customCategoryConfig) {
        tabImage = customCategoryConfig[cb.customMenuTab]?.image ?? defaultImage
        tabText = this.tabLocalePrefix + (customCategoryConfig[cb.customMenuTab]?.title ?? cb.customMenuTab)
      }
      else {
        tabImage = defaultImage
        tabText = this.tabLocalePrefix + cb.customMenuTab
      }
      this.customMenuTabs[lowerCaseTab] <- {
        image = tabImage
        title = tabText
      }
    }

    let sheetsToHide = []
    if (!hasAnyMedals)
      sheetsToHide.append("Medal")
    if (!hasAnyUnlocks)
      sheetsToHide.append("UnlockAchievement")
    foreach (sheetName in sheetsToHide) {
      let idx = this.sheetsList.indexof(sheetName)
      if (idx != null)
        this.sheetsList.remove(idx)
    }
  }

  function initTabs() {
    let view = { tabs = [] }
    local curSheetIdx = 0
    local tabText = null

    foreach (idx, sheet in this.sheetsList) {
      if (sheet in this.customMenuTabs)
        tabText = this.customMenuTabs[sheet].title
      else
        tabText = $"{this.tabLocalePrefix}{sheet}"

      view.tabs.append({
        id = sheet
        tabName = tabText
        unseenIcon = sheet == "UnlockAchievement"
          ? makeConfigStrByList([seenUnlockMarkers.id, seenManualUnlocks.id])
          : null
        navImagesText = getNavigationImagesText(idx, this.sheetsList.len())
        hidden = !this.isSheetVisible(sheet)
      })

      if (this.initialSheet == sheet)
        curSheetIdx = idx
    }

    view.hasBottomLine <- true
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let sheetsListObj = this.scene.findObject("profile_sheet_list")
    this.guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(curSheetIdx)
  }

  function isSheetVisible(sheetName) {
    if (sheetName == "Medal")
      return hasFeature("ProfileMedals")
    else if (sheetName == "Collections")
      return hasAvailableCollections()
    return true
  }

  function initShortcuts() {
    local obj = this.scene.findObject("btn_profile_icon")
    if (checkObj(obj))
      obj.btnName = "X"
    obj = this.scene.findObject("profile_currentUser_btn_title")
    if (checkObj(obj))
      obj.btnName = "Y"
    this.scene.findObject("unseen_titles").setValue(SEEN.TITLES)
    this.scene.findObject("unseen_avatar").setValue(SEEN.AVATARS)
  }

  function updateButtons() {
    let sheet = this.getCurSheet()
    let isProfileOpened = sheet == "UserCard"
    let needHideChangeAccountBtn = steam_is_running() && loadLocalAccountSettings("disabledReloginSteamAccount", false)
    let buttonsList = {
      btn_changeAccount = isInMenu.get() && isProfileOpened && !isPlatformSony && !needHideChangeAccountBtn && !this.isEditModeEnabled
      btn_changeName = isInMenu.get() && isProfileOpened && !isMeXBOXPlayer() && !isMePS4Player() && !this.isEditModeEnabled
      btn_editPage = isInMenu.get() && isProfileOpened && !this.isEditModeEnabled
      btn_cancelEditPage = isInMenu.get() && isProfileOpened && this.isEditModeEnabled
      btn_applyEditPage = isInMenu.get() && isProfileOpened && this.isEditModeEnabled
      btn_getLink = !is_in_loading_screen() && isProfileOpened && hasFeature("Invites") && !isGuestLogin.get() && !this.isEditModeEnabled
      btn_codeApp = isPlatformPC && !is_gdk && hasFeature("AllowExternalLink") &&
        !havePlayerTag("gjpass") && isInMenu.get() && isProfileOpened && !this.isEditModeEnabled
      btn_EmailRegistration = isProfileOpened && (canEmailRegistration() || needShowGuestEmailRegistration()) && !this.isEditModeEnabled
      wnd_paginator_place = sheet == "Statistics"
      btn_achievements_url = (sheet == "UnlockAchievement") && hasFeature("AchievementsUrl")
        && hasFeature("AllowExternalLink")
      btn_SkinPreview = isInMenu.get() && sheet == "UnlockSkin"
      btn_leaderboard = sheet == "Records" && hasFeature("Leaderboards")
    }

    showObjectsByTable(this.scene, buttonsList)

    if (buttonsList.btn_EmailRegistration)
      this.scene.findObject("btn_EmailRegistration").tooltip = needShowGuestEmailRegistration()
        ? loc("mainmenu/guestEmailRegistration/desc")
        : emailRegistrationTooltip

    if (buttonsList.btn_codeApp)
      setDoubleTextToButton(this.scene, "btn_codeApp",
        loc("mainmenu/2step/getPass", { passName = getCurCircuitOverride("passName", "Gaijin Pass") }))
    if (buttonsList.btn_achievements_url)
      setDoubleTextToButton(this.scene, "btn_achievements_url",
        loc("mainmenu/showAchievements", {
          name = getCurCircuitOverride("operatorName", "Gaijin.Net") }))

    this.updateEditProfileButtons()
  }

  function updateEditProfileButtons() {
    let root = this.scene.findObject("root-box")
    if (!root)
      return
    root.isEditModeEnabled = this.isEditModeEnabled ? "yes" : "no"
  }

  function onProfileEditBtn() {
    if (this.isEditModeEnabled)
      return

    this.setEditMode(true)
  }

  function onProfileTitleSelect(titleName, handler) {
    handler.fillTitleName(titleName, false)
    if (handler.isEditModeEnabled)
      handler.editModeTempData.title <- titleName
    else
      handler.saveProfileTitle(titleName)
  }

  function onProfileEditCancelBtn() {
    this.setEditMode(!this.isEditModeEnabled)
    if (this.editModeTempData?.title) {
      let stats = getStats()
      this.fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles", false)
    }

    if (this.editModeTempData?.terseInfo)
      this.fillShowcase(this.terseInfo, getStats())

    this.resetHeaderBackgroundImage()
    this.resetAvatarFrameImage()
    this.resetAvatarImage()
  }

  function saveProfileTitle(title) {
    addTask(select_current_title(title),
      {},
      function() {
        clearStats()
        getStats()
      }
    )
  }

  function setEditMode(val) {
    this.isEditModeEnabled = val
    this.updateButtons()
    if (val)
      this.editModeTempData = {}
    else {
      this.onHeaderBackgroundListHide()
      this.onChooseImageWndHide()
    }
    let showcase = getShowcaseByTerseInfo(this.terseInfo)
    if (showcase?.onChangeEditMode)
      showcase.onChangeEditMode(val, this.terseInfo, this.scene)
  }

  function onIconChoosen(imageType, data) {
    if (imageType == "pilotIcon") {
      this.fillProfileIcon(data.unlockId)
      if (this.isEditModeEnabled)
        this.editModeTempData.pilotIcon <- data.unlockId
      return
    }

    this.fillProfileAvatarFrame(data)
    if (this.isEditModeEnabled)
      this.editModeTempData.avatarFrameId <- data.id
  }

  function fillProfileIcon(icon) {
    if (!checkObj(this.scene))
      return

    this.changeAvatarImage(icon)
  }

  function fillProfileAvatarFrame(data) {
    if (!checkObj(this.scene))
      return
    this.changeFrameImage(data.id)
  }

  function hasEditProfileChanges() {
    if (!this.isEditModeEnabled)
      return false

    if (this.editModeTempData?.title && this.editModeTempData?.title != getStats().title)
      return true

    if (this.editModeTempData?.terseInfo)
      return true

    if (this.editModeTempData?.headerBackgroundId && this.editModeTempData.headerBackgroundId != this.currentHeaderBackgroundId)
      return true

    if (this.editModeTempData?.avatarFrameId && this.editModeTempData.avatarFrameId != this.currentAvatarFrameId)
      return true

    if (this.editModeTempData?.pilotIcon && this.editModeTempData.pilotIcon != this.currentAvatarId)
      return true

    return false
  }

  function askAboutSaveProfile(cb) {
    this.msgBox("safe_unfinished", loc("hotkeys/msg/wizardSaveUnfinished"),
    [
      ["ok", function() {
        this.onProfileEditApplyBtn()
        cb()
      }],
      ["cancel", function() {
        this.onProfileEditCancelBtn()
        cb()
      }]
    ], "cancel")
  }

  function switchToCollectionSheet() {
    let obj = this.scene.findObject("profile_sheet_list")
    let count = obj.childrenCount()
    for (local i = 0; i < count; i++) {
      if (obj.getChild(i).id == "Collections") {
        obj.setValue(i)
        return
      }
    }
  }

  function onEventGotoCollection(id) {
    this.selectedDecoratorId = id
    this.switchToCollectionSheet()
  }

  function onSheetChange(_obj) {
    let sheet = this.getCurSheet()
    if (this.hasEditProfileChanges()) {
      this.askAboutSaveProfile(@() this.onSheetChange(null))
      return
    }
    if (this.isEditModeEnabled)
      this.setEditMode(false)

    foreach (btn in ["btn_top_place", "btn_pagePrev", "btn_pageNext", "checkbox_only_for_bought"])
      showObjById(btn, false, this.scene)

    let pageHasProfileHeader = this.isPageHasProfileHandler(sheet)
    showObjById("profile_header", pageHasProfileHeader, this.scene)

    let accountImage = this.scene.findObject("profile_header_picture")
    accountImage.height = pageHasProfileHeader ? "1@maxAccountHeaderHeight" : "1@minAccountHeaderHeight"

    if (!this.isProfileInited) {
      fillGamercard(getProfileInfo(), "profile-", this.scene)
      if (pageHasProfileHeader)
        this.updateStats()
    }

    if (sheet == "UserCard") {
      this.showSheetDiv("usercard")
    }
    else if (sheet == "Statistics") {
      this.showServiceRecordsSheet()
    }
    else if (sheet == "Records") {
      this.showSheetDiv("stats")
      this.fillModeListBox(this.scene.findObject("stats-container"), this.curMode)
    }
    else if (sheet == "UnlockDecal") {
      this.showDecalsSheet()
    }
    else if (sheet == "Medal") {
      this.showMedalsSheet()
    }
    else if (sheet in this.unlockFilters) {
      if (!this.unlockFilters[sheet] || (this.unlockFilters[sheet].len() < 1)) {
        this.showAchievementsSheet()
      }
      else
        this.showSkinsSheet()
    }
    else if (sheet == "Collections") {
      this.showCollectionsSheet()
    }
    else
      this.showSheetDiv("")

    this.updateButtons()
  }

  function showSheetDiv(name, pages = false, subPages = false) {
    local show = false
    local showed_div = null
    foreach (div in ["usercard", "records", "achievements", "skins", "stats", "medals", "decals", "collections"]) {
      show = div == name
      let divObj = this.scene.findObject($"{div}-container")
      if (checkObj(divObj)) {
        divObj.show(show)
        divObj.enable(show)
        if (show) {
          this.updateDifficultySwitch(divObj)
          showed_div = divObj
        }
      }
    }
    showObjById("pages_list", pages, this.scene)
    showObjById("unit_type_list", subPages, this.scene)
    return showed_div
  }

  function onPageChange(_obj) {
    local pageIdx = 0
    let sheet = this.getCurSheet()
    if (!(sheet in this.unlockFilters) || !this.unlockFilters[sheet])
      return

    pageIdx = this.scene.findObject("pages_list").getValue()
    if (pageIdx < 0 || pageIdx >= this.unlockFilters[sheet].len())
      return
  }

  function onSubPageChange(_obj = null) {
    let subSwitch = this.getObj("unit_type_list")
    if (subSwitch?.isValid()) {
      let value = subSwitch.getValue()
      let unitType = unitTypes.getByEsUnitType(value)
      this.curSubFilter = unitType.esUnitType
      this.filterUnitTag = unitType.tag
    }
  }

  function onOnlyForBoughtCheck(_obj) {
    this.onSubPageChange()
  }

  function onCodeAppClick(_obj) {
    openUrl(getCurCircuitOverride("twoStepCodeAppURL", loc("url/2step/codeApp")))
  }

  function getHandlerRestoreData() {
    let data = {
     openData = {
        initialSheet = this.getCurSheet()
        filterUnitTag = this.filterUnitTag
      }
    }
    return data
  }

  function onEventBeforeStartShowroom(_p) {
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function getCurSheet() {
    let obj = this.scene.findObject("profile_sheet_list")
    let sheetIdx = obj.getValue()
    if ((sheetIdx < 0) || (sheetIdx >= obj.childrenCount()))
      return ""

    return obj.getChild(sheetIdx).id
  }

  function calcStat(func, diff, mode, fm_idx = null) {
    local value = 0

    for (local idx = 0; idx < 3; idx++) 
      if (idx == diff || diff < 0)

        for (local pm = 0; pm < 2; pm++)  
          if (mode == pm || mode < 0)

            if (fm_idx != null)
              value += func(idx, fm_idx, pm)
            else
              value += func(idx, pm)

    return value
  }

  function getStatRowData(name, func, mode, fm_idx = null, timeFormat = false) {
    let row = [{ text = name, tdalign = "left" }]
    for (local diff = 0; diff < 3; diff++) {
      local value = 0
      if (fm_idx == null || fm_idx >= 0)
        value = this.calcStat(func, diff, mode, fm_idx)
      else
        for (local i = 0; i < 3; i++)
          value += this.calcStat(func, diff, mode, i)

      let s = timeFormat ? time.secondsToString(value) : value
      let tooltip = ["#mainmenu/arcadeInstantAction", "#mainmenu/instantAction", "#mainmenu/fullRealInstantAction"][diff]
      row.append({ id = diff.tostring(), text = s.tostring(), tooltip = tooltip })
    }
    return buildTableRowNoPad("", row)
  }

  function updateStats() {
    let myStats = getStats()
    if (!myStats || !checkObj(this.scene))
      return
    let needFrequentRequestShowcase = !this.isProfileInited
    this.isProfileInited = true
    this.fillProfileStats(myStats)
    this.updateShowcase(needFrequentRequestShowcase)
  }

  function openChooseTitleWnd(_obj) {
    let cachedHandler = this
    let curTitle = this.editModeTempData?.title ?? ""
    gui_handlers.ChooseTitle.open({
      onCompleteFunc = @(titleName) cachedHandler.onProfileTitleSelect(titleName, cachedHandler)
      curTitle
    })
  }

  function showCollectionsSheet(decoratorId = null) {
    let collectionsDiv = this.showSheetDiv("collections", true)
    openCollectionsPage({
      scene = collectionsDiv
      parent = this
      selectedDecoratorId = decoratorId ?? this.selectedDecoratorId
    })
  }

  function showSkinsSheet() {
    let holder = this.showSheetDiv("skins", true)
    if (this.skinsPageHandlerWeak != null)
      return

    let skinsPageHandler = openSkinsPage({
      scene = holder
      parent = this
      openParams = {
        initCountry = this.filterCountryName
        initUnitType = this.filterUnitTag
        initSkinId = this.initSkinId
      }
    })
    this.registerSubHandler(skinsPageHandler)
    this.skinsPageHandlerWeak = skinsPageHandler.weakref()
  }

  function showDecalsSheet() {
    let holder = this.showSheetDiv("decals", true)
    if (this.decalsPageHandlerWeak != null)
      return

    let decalsPageHandler = openDecalsPage({
      scene = holder
      parent = this
      openParams = {
        initCategory = this.filterGroupName
      }
    })
    this.registerSubHandler(decalsPageHandler)
    this.decalsPageHandlerWeak = decalsPageHandler.weakref()
  }

  function showAchievementsSheet() {
    let holder = this.showSheetDiv("achievements", true)
    if (this.achievementsPageHandlerWeak != null)
      return
    let achievementsPageHandler = openAchievementsPage({
      scene = holder
      parent = this
      openParams = {
        initCategory = this.curAchievementGroupName
        initialUnlockId = this.initialUnlockId
      }
    })
    this.registerSubHandler(achievementsPageHandler)
    this.achievementsPageHandlerWeak = achievementsPageHandler.weakref()
  }

  function fillProfileStats(stats) {
    this.fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles")
    if ("uid" in stats && stats.uid != userIdStr.get())
      externalIDsService.reqPlayerExternalIDsByUserId(stats.uid)
    this.fillClanInfo(getProfileInfo())
    this.scene.findObject("profile_loading").show(false)
  }

  function onProfileStatsModeChange(obj) {
    if (!checkObj(this.scene))
      return
    let myStats = getStats()
    if (!myStats)
      return

    this.curMode = obj.getValue()

    this.setCurrentWndDifficulty(this.curMode)
    this.updateCurrentStatsMode(this.curMode)
    fillProfileSummary(this.scene.findObject("stats_table"), myStats.summary, this.curMode)
  }

  function onUpdate(_obj, _dt) {
    if (this.pending_logout && isAppActive() && !steam_is_overlay_active() && !is_builtin_browser_active()) {
      this.pending_logout = false
      this.guiScene.performDelayed(this, function() {
        startLogout()
      })
    }
  }

  function onChangeName() {
    local textLocId = "mainmenu/questionChangeName"
    local afterOkFunc = @() this.guiScene.performDelayed(this, function() { this.pending_logout = true })

    if (steam_is_running() && !hasFeature("AllowSteamAccountLinking")) {
      textLocId = "mainmenu/questionChangeNameSteam"
      afterOkFunc = @() null
    }

    this.msgBox("question_change_name", loc(textLocId),
      [
        ["ok", function() {
          openUrl(getCurCircuitOverride("changeNameURL", loc("url/changeName")), false, false, "profile_page")
          afterOkFunc()
        }],
        ["cancel", function() { }]
      ], "cancel")
  }

  function onChangeAccount() {
    this.msgBox("question_change_name", loc("mainmenu/questionChangePlayer"),
      [
        ["yes", function() {
          saveLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, false)
          startLogout()
        }],
        ["no", @() null ]
      ], "no", { cancel_fn = @() null })
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function onChangePilotIcon() {
    if (!this.isValid())
      return
    if (this.isEditModeEnabled == false) {
      this.onProfileEditBtn()
      if (!this.isEditModeEnabled)
        return
    }

    let chooseImageScene = showObjById("chooseImage", true)
    if (chooseImageScene.findObject("wnd_frame")?.isVisible())
      return
    gui_choose_image(this.onIconChoosen, this, chooseImageScene)
    this.onHeaderBackgroundListHide()
  }

  function openViralAcquisitionWnd() {
    showViralAcquisitionWnd()
  }

  function onEventProfileUpdated(_params) {
    fillGamercard(getProfileInfo(), "profile-", this.scene)
  }

  function onEventMyStatsUpdated(_params) {
    let sheet = this.getCurSheet()
    if (sheet == "Statistics")
      this.showServiceRecordsSheet()

    if (this.isPageHasProfileHandler(sheet))
      this.updateStats()
    else
      this.isProfileInited = false
  }

  function onEventClanInfoUpdate(_params) {
    this.fillClanInfo(getProfileInfo())
  }

  function getPlayerStats() {
    return getStats()
  }

  function onBindEmail() {
    if (needShowGuestEmailRegistration())
      getPlayerSsoShortTokenAsync("onGetStokenForGuestEmail")
    else
      launchEmailRegistration()
    this.doWhenActiveOnce("updateButtons")
  }

  function onOpenAchievementsUrl() {
    openUrl(getCurCircuitOverride("achievementsURL", loc("url/achievements")).subst(
        { appId = APP_ID, name = getProfileInfo().name }),
      false, false, "profile_page")
  }

  function onCloseOrCancelEditMode() {
    if (!this.scene.isValid())
      return

    if (this.hasEditProfileChanges()) {
      this.askAboutSaveProfile(@() null)
      return
    }

    if (this.isEditModeEnabled) {
      this.setEditMode(false)
      this.resetHeaderBackgroundImage()
      this.resetAvatarFrameImage()
      this.resetAvatarImage()
      return
    }

    base.goBack()
  }

  function goBack() {
    if (!this.scene.isValid())
      return

    if (this.hasEditProfileChanges()) {
      this.askAboutSaveProfile(@() this.isEditModeEnabled ? null : this.goBack())
      return
    }

    base.goBack()
  }

  onLeaderboard = @() loadHandler(gui_handlers.LeaderboardWindow, { userId = userIdInt64.get() })

  function onShowcaseSelect(obj) {
    if (!this.isEditModeEnabled)
      return

    let selectedShowcase = getShowcaseByIndex(obj.getValue())
    if (selectedShowcase == null)
      return
    if (selectedShowcase?.isDisabled()) {
      let prevValue = getShowcaseIndexByTerseName(this.currentShowcaseName)
      obj.setValue(prevValue)
      showInfoMsgBox("".concat(loc("msgbox/showcase_unavailable"), "\n", selectedShowcase.textForDisabled()))
      return
    }

    this.currentShowcaseName = selectedShowcase.terseName
    this.editModeTempData.terseInfo <- generateShowcaseInfo(this.currentShowcaseName)
    let userStats = getStats()
    trySetBestShowcaseMode(userStats, this.editModeTempData.terseInfo)
    this.fillShowcase(this.editModeTempData.terseInfo, userStats, false)
    this.fillShowcaseGameModes(selectedShowcase, this.editModeTempData.terseInfo)
    this.updateEditModeSecondTitle(this.editModeTempData.terseInfo)
  }

  function setEditModeSecondTitle(text) {
    let hasTitle = (text ?? "") != ""
    let secondTitleObj = showObjById("edit_second_title", hasTitle, this.scene)
    if (secondTitleObj && hasTitle) {
      let textObj = secondTitleObj.findObject("edit_second_title_text")
      textObj.setValue(text)
    }
  }

  function updateEditModeSecondTitle(terseInfo) {
    let showcase = getShowcaseByTerseInfo(terseInfo)
    this.setEditModeSecondTitle(
      showcase?.hasSecondTitleInEditMode
        ? showcase.getSecondTitle(terseInfo)
        : ""
    )
  }

  function fillShowcaseEdit(terseInfo) {
    let data = getEditViewData(terseInfo, this.getScaleParams())
    let nest = this.scene.findObject("showcase_edit");
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)

    let showcase = getShowcaseByTerseInfo(terseInfo)
    this.fillShowcaseGameModes(showcase, terseInfo)
    this.updateEditModeSecondTitle(terseInfo)
  }

  function fillShowcaseGameModes(showcase, terseInfo) {
    let showcaseTypesBox = showObjById("showcase_gamemodes", showcase?.hasGameMode, this.scene)
    if (!showcase?.hasGameMode)
      return

    let data = getShowcaseTypeBoxData(terseInfo, this.getScaleParams())
    this.guiScene.replaceContentFromText(showcaseTypesBox, data, data.len(), this)

    let index = getGameModeBoxIndex(terseInfo)
    if (index >= 0)
      showcaseTypesBox.setValue(index)
  }

  function onProfileEditApplyBtn() {
    this.saveProfileAppearance()

    if (this.editModeTempData?.title && this.editModeTempData?.title != getStats().title)
      this.saveProfileTitle(this.editModeTempData.title)

    if (this.editModeTempData?.terseInfo) {
      let handler = this
      let showcaseData = getShowcaseByTerseInfo(this.editModeTempData.terseInfo)
      if (showcaseData?.canBeSaved && !showcaseData.canBeSaved(this.editModeTempData.terseInfo))
        return
      let showcaseToSave = this.editModeTempData.terseInfo
      let showcaseOnError = this.terseInfo
      saveShowcase(showcaseToSave,
        @() handler?.isValid() ? handler.onSaveShowcaseComplete(showcaseToSave) : null,
        @() handler?.isValid() ? handler.onSaveShowcaseError(showcaseOnError) : null
      )
    }
    this.setEditMode(!this.isEditModeEnabled)
  }

  function onSaveShowcaseComplete(savedShowcase) {
    this.terseInfo = savedShowcase
    this.fillShowcase(savedShowcase, getStats())
  }

  function onSaveShowcaseError(showcaseForRestore) {
    this.terseInfo = showcaseForRestore
    this.currentShowcaseName = this.terseInfo.schType
    this.fillShowcase(showcaseForRestore, getStats())
  }

  function tryCreateTerseInfoForEdit() {
    if (this.editModeTempData?.terseInfo != null)
      return
    this.editModeTempData.terseInfo <- clone this.terseInfo
    this.editModeTempData.terseInfo.showcase <- clone this.terseInfo.showcase
  }

  function onShowcaseGameModeSelect(obj) {
    if (!this.isEditModeEnabled)
      return
    let gameMode = getShowcaseGameModeByIndex(obj.getValue(), this.editModeTempData?.terseInfo ?? this.terseInfo)
    if (!gameMode)
      return
    this.tryCreateTerseInfoForEdit()
    writeGameModeToTerseInfo(this.editModeTempData.terseInfo, gameMode.mode)
    this.fillShowcase(this.editModeTempData.terseInfo, getStats(), false)
  }

  function getPageProfileStats() {
    return getStats()
  }

  function fillShowcase(terseInfo, userStats, needFillEdit = true) {
    this.fillShowcaseTitle(terseInfo)
    this.fillShowcaseMid(terseInfo, userStats)
    if (needFillEdit)
      this.fillShowcaseEdit(terseInfo)
  }

  function updateShowcase(needFrequentRequest = false) {
    let userStats = this.getPageProfileStats()
    if (userStats == null)
      return

    this.terseInfo = this.terseInfo ?? generateShowcaseInfo(this.currentShowcaseName, needFrequentRequest)
    let terseInfo = this.editModeTempData?.terseInfo ?? this.terseInfo
    if (terseInfo == null)
      return

    trySetBestShowcaseMode(userStats, terseInfo)
    this.fillShowcase(terseInfo, userStats)
  }

  function onEventAllShowcasesDataUpdated(_data) {
    if (this.isEditModeEnabled)
      return
    this.terseInfo = generateShowcaseInfo(this.currentShowcaseName)
    if (!this.terseInfo)
      return
    let userStats = this.getPageProfileStats()
    if (userStats == null)
      return
    trySetBestShowcaseMode(userStats, this.terseInfo)
    this.fillShowcase(this.terseInfo, userStats)
  }

  function onUnitSelect(unit) {
    this.tryCreateTerseInfoForEdit()
    saveUnitToTerseInfo(this.editModeTempData.terseInfo, unit, this.curUnitImageIdx)
    this.fillShowcaseMid(this.editModeTempData.terseInfo, this.getPageProfileStats())
    this.updateEditModeSecondTitle(this.editModeTempData.terseInfo)
  }

  function onShowcaseCustomFunc(obj) {
    this.tryCreateTerseInfoForEdit()
    let terseInfo = this?.editModeTempData.terseInfo
    getShowcaseByTerseInfo(terseInfo)?.onClickFunction(obj, terseInfo, this.getPlayerStats(), this.scene)
  }

  function onUnitImageClick(obj) {
    if (this.isEditModeEnabled == false) {
      this.setEditMode(true)
      return
    }
    this.curUnitImageIdx = obj?.imageIdx ? to_integer_safe(obj.imageIdx) : 0
    let handler = this
    let terseInfo = this?.editModeTempData.terseInfo ?? this.terseInfo
    let additionalUnitsFilter = getShowcaseUnitsFilter(terseInfo, this.curUnitImageIdx)
    let showcase = getShowcaseByTerseInfo(terseInfo)

    openSelectUnitWnd({
      unitsFilter = @(unit) isUnitBought(unit) && unit.isVisibleInShop()
        && additionalUnitsFilter(unit),
      userstat = this.getPageProfileStats()?.userstat,
      onUnitSelectFunction = @(unit) handler.onUnitSelect(unit),
      diffsForSort = showcase?.getDiffsForUnitsSort(terseInfo)
      showRecordsTableUnits = true
      filtersData = selectUnitWndFilters
    })
  }

  function onDeleteUnitClick(obj) {
    this.curUnitImageIdx = obj?.imageIdx ? to_integer_safe(obj.imageIdx) : -1
    this.onUnitSelect(null)
  }

  function onSelectFavUnitDiff(obj) {
    let diff = getDiffByIndex(obj.getValue())
    this.tryCreateTerseInfoForEdit()
    this.editModeTempData.terseInfo.showcase.difficulty <- diff
    fillStatsValuesOfTerseInfo(this.scene, this.editModeTempData.terseInfo, getStats())
  }

  function saveProfileAppearance() {
    let params = {}

    if (this.editModeTempData?.avatarFrameId != null && this.editModeTempData.avatarFrameId != this.currentAvatarFrameId)
      params.frame <- this.editModeTempData.avatarFrameId

    if (this.editModeTempData?.headerBackgroundId != null && this.editModeTempData.headerBackgroundId != this.currentHeaderBackgroundId)
      params.background <- this.editModeTempData.headerBackgroundId

    if (this.editModeTempData?.pilotIcon != null && this.editModeTempData.pilotIcon != this.currentAvatarId)
      params.pilotIcon <- this.editModeTempData.pilotIcon

    if (params.len() == 0)
      return

    let cbError = Callback(function() {
      this.setCurrentHeaderBackground()
      this.setCurrentAvatarFrame()
      this.setCurrentAvatar()
    }, this)

    saveProfileAppearance(params, null, cbError)
  }

  function updateHeaderBackgroundsListSelection() {
    let listObj = this.scene.findObject("header_backgrounds_list")
    for (local i = 0; i < listObj.childrenCount(); i++) {
      if (listObj.getChild(i).id == (this.editModeTempData?.headerBackgroundId ?? this.currentHeaderBackgroundId)) {
        listObj.setValue(i)
        break
      }
    }
  }

  function updateProfileAppearance() {
    let userInfo = getUserInfo(userIdStr.get())
    if (userInfo == null)
      return

    let headerBackgroundId = userInfo.background != "" ? userInfo.background : "profile_header_default"
    if (headerBackgroundId != this.currentHeaderBackgroundId) {
      this.currentHeaderBackgroundId = headerBackgroundId
      if (!this.isEditModeEnabled || this.editModeTempData?.headerBackgroundId == null)
        this.setCurrentHeaderBackground()
    }

    let avatarFrameId = userInfo.frame != "" ? userInfo.frame : ""
    if (avatarFrameId != this.currentAvatarFrameId) {
      this.currentAvatarFrameId = avatarFrameId
      if (!this.isEditModeEnabled || this.editModeTempData?.avatarFrameId == null)
        this.setCurrentAvatarFrame()
    }

    let avatarId = getAvatarIconIdByUserInfo(userInfo)
    if (avatarId != this.currentAvatarId) {
      this.currentAvatarId = avatarId
      if (!this.isEditModeEnabled || this.editModeTempData?.avatarId == null)
        this.setCurrentAvatar()
    }
  }

  function onEventUserInfoManagerDataUpdated(param) {
    if (userIdStr.get() not in param.usersInfo)
      return
    this.updateProfileAppearance()
  }

  function fillHeaderBackgroundsList(filterText = "") {
    if (this.profileHeaderBackground == null)
      this.profileHeaderBackground = getProfileHeaderBackgrounds()

    local items = null
    if (filterText == "")
      items = this.profileHeaderBackground
    else {
      let searchString = filterText.tolower()
      items = this.profileHeaderBackground.filter(@(unlock)(unlock.searchName.contains(searchString)))
    }

    let data = handyman.renderCached("%gui/profile/headerBackgroundItems.tpl", { items })
    let listObj = this.scene.findObject("header_backgrounds_list")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    this.updateHeaderBackgroundsListSelection()
  }

  function onHeaderBackgroundSelect(obj) {
    if (!this.isEditModeEnabled)
      return

    let index = obj.getValue()
    if (index < 0)
      return
    let item = obj.getChild(index)
    this.editModeTempData.headerBackgroundId <- item["id"]
    this.changeHeaderBackgroundImage(this.editModeTempData.headerBackgroundId)
  }

  function onHeaderBackgroundListSwitch() {
    let backgroundListObj = this.scene.findObject("background_edit")
    let isVisible = backgroundListObj.isVisible()
    backgroundListObj.show(!isVisible)
    if (isVisible)
      return

    this.onChooseImageWndHide()

    let filterObj = this.getHeaderBackgroundsFilterObj()
    if (filterObj.getValue() == "")
      this.fillHeaderBackgroundsList()
    else {
      this.resetHeaderBackgroundsFilter()
      this.updateHeaderBackgroundsListSelection()
    }
  }

  function onHeaderBackgroundListHide() {
    this.scene.findObject("background_edit").show(false)
  }

  function onChooseImageWndHide() {
    this.scene.findObject("chooseImage").show(false)
  }

  function resetHeaderBackgroundImage() {
    this.setCurrentHeaderBackground()
    this.editModeTempData.headerBackgroundId <- null
  }

  function resetAvatarFrameImage() {
    this.setCurrentAvatarFrame()
    this.editModeTempData.avatarFrameId <- null
  }

  function resetAvatarImage() {
    this.setCurrentAvatar()
    this.editModeTempData.pilotIcon <- null
  }

  getHeaderBackgroundsFilterObj = @() this.scene.findObject("filter_header")
  resetHeaderBackgroundsFilter = @() this.getHeaderBackgroundsFilterObj().setValue("")

  function onFilterCancel(filterObj) {
    if (filterObj.getValue() != "")
      filterObj.setValue("")
    else
      this.onHeaderBackgroundListHide()
  }

  function applyFilterBackground(obj) {
    clearTimer(this.applyFilterTimer)
    let filterText = obj.getValue()
    if (filterText == "") {
      this.fillHeaderBackgroundsList()
      return
    }

    let applyCallback = Callback(@() this.fillHeaderBackgroundsList(filterText), this)
    this.applyFilterTimer = setTimeout(0.5, @() applyCallback())
  }
}

let openProfileSheetParamsFromPromo = {
  UnlockAchievement = @(p1, p2, ...) {
    curAchievementGroupName = p2 == "" ? p1 : $"{p1}/{p2}"
  }
  Medal = @(p1, _p2, ...) { filterCountryName = p1 }
  UnlockSkin = @(p1, p2, p3) {
    filterCountryName = p1
    filterUnitTag = p2
    initSkinId = p3
  }
  UnlockDecal = @(p1, _p2, ...) { filterGroupName = p1 }
}

function openProfileFromPromo(params, sheet = null) {
  sheet = sheet ?? params?[0]
  let launchParams = openProfileSheetParamsFromPromo?[sheet](
    params?[1], params?[2] ?? "", params?[3] ?? "") ?? {}
  launchParams.__update({ initialSheet = sheet })
  guiStartProfile(launchParams)
}

addPromoAction("profile", @(_handler, params, _obj) openProfileFromPromo(params))

return {
  guiStartProfile
}