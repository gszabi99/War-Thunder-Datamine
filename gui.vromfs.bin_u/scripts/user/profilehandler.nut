from "%scripts/dagui_natives.nut" import save_profile, get_unlock_type, is_app_active, select_current_title
from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import USE_STEAM_LOGIN_AUTO_SETTING_ID
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { saveLocalSharedSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { deferOnce, defer } = require("dagor.workcycle")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, isInMenu, handlersManager, loadHandler, is_in_loading_screen
} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnlockById, getAllUnlocksWithBlkOrder, getUnlocksByTypeInBlkOrder
} = require("%scripts/unlocks/unlocksCache.nut")
let regexp2 = require("regexp2")
let time = require("%scripts/time.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let externalIDsService = require("%scripts/user/externalIdsService.nut")
let avatars = require("%scripts/user/avatars.nut")
let { isMeXBOXPlayer, isMePS4Player, isPlatformPC, isPlatformSony
} = require("%scripts/clientState/platform.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { askPurchaseDecorator, askConsumeDecoratorCoupon,
  findDecoratorCouponOnMarketplace } = require("%scripts/customization/decoratorAcquire.nut")
let { getViralAcquisitionDesc, showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { fillProfileSummary, getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { canStartPreviewScene, useDecorator, showDecoratorAccessRestriction,
  getDecoratorDataToUse } = require("%scripts/customization/contentPreview.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")
let { makeConfig, makeConfigStrByList } = require("%scripts/seen/bhvUnseen.nut")
let { getUnlockIds } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { placePriceTextToButton, warningIfGold, setDoubleTextToButton
} = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { openCollectionsWnd } = require("%scripts/collections/collectionsWnd.nut")
let { launchEmailRegistration, canEmailRegistration, emailRegistrationTooltip,
  needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { getUnlockCondsDescByCfg, getUnlockMultDescByCfg, getUnlockNameText, getUnlockMainCondDescByCfg,
  getLocForBitValues, buildUnlockDesc, fillUnlockManualOpenButton, updateUnseenIcon, updateLockStatus,
  fillUnlockImage, fillUnlockProgressBar, fillUnlockDescription, doPreviewUnlockPrize, fillReward,
  fillUnlockTitle, fillUnlockPurchaseButton
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { APP_ID } = require("app")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isUnlockVisible, getUnlockCost, canDoUnlock,
  canOpenUnlockManually, isUnlockOpened, findUnusableUnitForManualUnlock, canClaimUnlockRewardForUnit
} = require("%scripts/unlocks/unlocksModule.nut")
let { openUnlockManually, buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let openUnlockUnitListWnd = require("%scripts/unlocks/unlockUnitListWnd.nut")
let { isUnlockFav, canAddFavorite, unlockToFavorites, fillUnlockFav,
  toggleUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getManualUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { getCachedDataByType, getDecorator, getDecoratorById,
  getCachedDecoratorsListByType} = require("%scripts/customization/decorCache.nut")
let { getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { getPlayerSsoShortTokenAsync } = require("auth_wt")
let { set_option } = require("%scripts/options/optionsExt.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PILOT } = require("%scripts/options/optionsExtNames.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getEsUnitType, getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { get_gui_regional_blk } = require("blkGetters")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { userIdStr, userIdInt64, havePlayerTag, isGuestLogin } = require("%scripts/user/profileStates.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { openTrophyRewardsList } = require("%scripts/items/trophyRewardList.nut")
let { rewardsSortComparator } = require("%scripts/items/trophyReward.nut")
let { getStats, clearStats } = require("%scripts/myStats.nut")
let { findItemById, canGetDecoratorFromTrophy } = require("%scripts/items/itemsManager.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { steam_is_running, steam_is_overlay_active } = require("steam")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { addTask } = require("%scripts/tasker.nut")
let { getEditViewData, getShowcaseTypeBoxData, saveShowcase, getGameModeBoxIndex,
   writeGameModeToTerseInfo, getShowcaseGameModeByIndex } = require("%scripts/user/profileShowcase.nut")

require("%scripts/user/userCard.nut") //for load UserCardHandler before Profile handler

enum profileEvent {
  AVATAR_CHANGED = "AvatarChanged"
}

enum OwnUnitsType {
  ALL = "all",
  BOUGHT = "only_bought",
}

let profileSelectedFiltersCache = {
  unit = []
  rank = []
  country = []
}

let seenUnlockMarkers = seenList.get(SEEN.UNLOCK_MARKERS)
let seenManualUnlocks = seenList.get(SEEN.MANUAL_UNLOCKS)

function getSkinCountry(skinName) {
  let len0 = skinName.indexof("/")
  return len0 ? ::getShopCountry(skinName.slice(0, len0)) : ""
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

local cachedTerseInfo = null

gui_handlers.Profile <- class (gui_handlers.UserCardHandler) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/profile/profile.blk"
  initialSheet = ""

  curDifficulty = "any"
  curPlayerMode = 0
  curSubFilter = -1
  curFilterType = ""
  airStatsInited = false

  airStatsList = null
  statsType = ETTI_VALUE_INHISORY
  statsMode = ""
  statsCountries = null
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0
  pending_logout = false

  presetSheetList = ["UserCard", "Records", "Statistics", "Medal", "UnlockAchievement", "UnlockSkin", "UnlockDecal"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"
  defaultTabImageName = "unlockachievement"

  sheetsList = null
  customMenuTabs = null

  curPage = ""
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

  unlocksTree = null
  skinsCache = null
  uncollapsedChapterName = null
  curAchievementGroupName = ""
  initialUnlockId = ""
  previewUnlockId = ""
  filterUnitTag = ""
  initSkinId = ""
  initDecalId = ""
  filterGroupName = null
  isEditModeEnabled = false
  editModeTempData = null

  unlockFilters = {
    UnlockAchievement = null
    UnlockChallenge = null
    UnlockSkin = []
  }

  filterTable = {
    Medal = "country"
    UnlockSkin = "airCountry"
  }

  function initScreen() {
    this.terseInfo = cachedTerseInfo
    this.editModeTempData = {}
    this.selMedalIdx = {}
    setBreadcrumbGoBackParams(this)
    if (!this.scene)
      return this.goBack()

    this.countryStats = profileSelectedFiltersCache.country
    this.unitStats = profileSelectedFiltersCache.unit
    this.rankStats = profileSelectedFiltersCache.rank

    this.isOwnStats = true
    this.scene.findObject("profile_update").setUserData(this)

    let needShortSeparators = to_pixels("sw") > to_pixels("1@maxProfileFrameWidth + 2@framePadding")
    let frame = this.scene.findObject("wnd_frame")
    frame.needShortSeparators = needShortSeparators ? "yes" : "no"

    //prepare options
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    this.unlocksTree = {}

    //fill skins filters
    let skinCountries = getUnlockFiltersList("skin", function(unlock) {
      let country = getSkinCountry(unlock.getStr("id", ""))
      return (country != "") ? country : null
    })
    this.unlockFilters.UnlockSkin = shopCountriesList.filter(@(c) isInArray(c, skinCountries))

    let medalCountries = getUnlockFiltersList("medal", @(unlock) unlock?.country)
    this.medalsFilters = shopCountriesList.filter(@(c) isInArray(c, medalCountries))

    this.initStatsParams()
    this.initSheetsList()
    this.initTabs()

    let bntGetLinkObj = this.scene.findObject("btn_getLink")
    if (checkObj(bntGetLinkObj))
      bntGetLinkObj.tooltip = getViralAcquisitionDesc("mainmenu/getLinkDesc")

    this.initShortcuts()
  }

  function initSheetsList() {
    this.customMenuTabs = {}
    this.sheetsList = clone this.presetSheetList
    local hasAnyUnlocks = false
    local hasAnyMedals = false //skins and decals tab also have resources without unlocks

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
        tabText = this.tabLocalePrefix + sheet

      view.tabs.append({
        id = sheet
        tabName = tabText
        unseenIcon = sheet == "UnlockAchievement"
          ? makeConfigStrByList([seenUnlockMarkers.id, seenManualUnlocks.id])
          : null
        navImagesText = ::get_navigation_images_text(idx, this.sheetsList.len())
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

  function updateDecalButtons(decor) {
    if (!decor) {
      showObjectsByTable(this.scene, {
        btn_buy_decorator              = false
        btn_fav                        = false
        btn_preview                    = false
        btn_use_decorator              = false
        btn_store                      = false
        btn_marketplace_consume_coupon = false
        btn_marketplace_find_coupon    = false
        btn_go_to_collection           = false
      })
      return
    }

    let canBuy = decor.canBuyUnlock(null)
    let canConsumeCoupon = !canBuy && decor.canGetFromCoupon(null)
    let canFindOnMarketplace = !canBuy && !canConsumeCoupon
      && decor.canBuyCouponOnMarketplace(null)
    let canFindInStore = !canBuy && !canConsumeCoupon && !canFindOnMarketplace
      && canGetDecoratorFromTrophy(decor)

    let buyBtnObj = showObjById("btn_buy_decorator", canBuy, this.scene)
    if (canBuy && buyBtnObj?.isValid())
      placePriceTextToButton(this.scene, "btn_buy_decorator", loc("mainmenu/btnOrder"), decor.getCost())

    let canFav = !decor.isUnlocked() && canDoUnlock(decor.unlockBlk)
    let favBtnObj = showObjById("btn_fav", canFav, this.scene)
    if (canFav)
      favBtnObj.setValue(isUnlockFav(decor.unlockId)
        ? loc("preloaderSettings/untrackProgress")
        : loc("preloaderSettings/trackProgress"))

    let canUse = decor.isUnlocked() && canStartPreviewScene(false)
    let canPreview = !canUse && decor.canPreview()

    showObjectsByTable(this.scene, {
      btn_preview                    = isInMenu() && canPreview
      btn_use_decorator              = isInMenu() && canUse
      btn_store                      = isInMenu() && canFindInStore
      btn_go_to_collection           = isInMenu() && isCollectionItem(decor)
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon    = canFindOnMarketplace
    })
  }

  function updateButtons() {
    let sheet = this.getCurSheet()
    let isProfileOpened = sheet == "UserCard"
    let needHideChangeAccountBtn = steam_is_running() && loadLocalAccountSettings("disabledReloginSteamAccount", false)
    let buttonsList = {
      btn_changeAccount = isInMenu() && isProfileOpened && !isPlatformSony && !needHideChangeAccountBtn && !this.isEditModeEnabled
      btn_changeName = isInMenu() && isProfileOpened && !isMeXBOXPlayer() && !isMePS4Player() && !this.isEditModeEnabled
      btn_editPage = isInMenu() && isProfileOpened && !this.isEditModeEnabled
      btn_cancelEditPage = isInMenu() && isProfileOpened && this.isEditModeEnabled
      btn_applyEditPage = isInMenu() && isProfileOpened && this.isEditModeEnabled
      btn_getLink = !is_in_loading_screen() && isProfileOpened && hasFeature("Invites") && !isGuestLogin.value && !this.isEditModeEnabled
      btn_codeApp = isPlatformPC && hasFeature("AllowExternalLink") &&
        !havePlayerTag("gjpass") && isInMenu() && isProfileOpened && !this.isEditModeEnabled
      btn_EmailRegistration = isProfileOpened && (canEmailRegistration() || needShowGuestEmailRegistration()) && !this.isEditModeEnabled
      paginator_place = (sheet == "Statistics") && this.airStatsList && (this.airStatsList.len() > this.statsPerPage)
      btn_achievements_url = (sheet == "UnlockAchievement") && hasFeature("AchievementsUrl")
        && hasFeature("AllowExternalLink")
      btn_SkinPreview = isInMenu() && sheet == "UnlockSkin"
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

    this.updateDecalButtons(this.getCurDecal())
    this.updateEditProfileButtons()
  }

  function updateEditProfileButtons() {
    this.scene.isEditModeEnabled = this.isEditModeEnabled ? "yes" : "no"
  }

  function onProfileEditBtn() {
    this.setEditMode(!this.isEditModeEnabled)
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
    if (this.editModeTempData?.icon)
      this.fillProfileIcon(getProfileInfo().icon)

    if (this.editModeTempData?.terseInfo)
      this.fillShowcase(this.terseInfo, getStats())
  }

  function saveProfileIcon(newIcon) {
    set_option(USEROPT_PILOT, newIcon)
    save_profile(false)
    broadcastEvent(profileEvent.AVATAR_CHANGED)
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

  function onProfileEditApplyBtn() {
    this.setEditMode(!this.isEditModeEnabled)
    let newIcon = this.editModeTempData?.icon
    if (newIcon && newIcon != ::get_option(USEROPT_PILOT).value)
      this.saveProfileIcon(newIcon)

    if (this.editModeTempData?.title && this.editModeTempData?.title != getStats().title)
      this.saveProfileTitle(this.editModeTempData.title)

    if (this.editModeTempData?.terseInfo) {
      let handler = this
      let showcaseToSave = this.editModeTempData.terseInfo
      let showcaseOnError = this.terseInfo
      saveShowcase(showcaseToSave,
        @() handler?.isValid() ? handler.onSaveShowcaseComplete(showcaseToSave) : null,
        @() handler?.isValid() ? handler.onSaveShowcaseError(showcaseOnError) : null
      )
    }
  }

  function setEditMode(val) {
    this.isEditModeEnabled = val
    this.updateButtons()
    if (val)
      this.editModeTempData = {}
  }

  function onIconChoosen(option) {
    let value = ::get_option(USEROPT_PILOT).value
    if (value == option.idx)
      return

    this.fillProfileIcon(option.idx)
    if (this.isEditModeEnabled)
      this.editModeTempData.icon <- option.idx
    else
      this.saveProfileIcon(option.idx)
  }

  function fillProfileIcon(iconIdx) {
    if (!checkObj(this.scene))
      return
    let obj = this.scene.findObject("profile-icon")
    if (obj)
      obj.setValue(iconIdx)
  }

  function hasEditProfileChanges() {
    if (!this.isEditModeEnabled)
      return false
    let newIcon = this.editModeTempData?.icon
    if (newIcon && newIcon != ::get_option(USEROPT_PILOT).value)
      return true

    if (this.editModeTempData?.title && this.editModeTempData?.title != getStats().title)
      return true

    if (this.editModeTempData?.terseInfo)
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

  function onMarketplaceFindCoupon() {
    findDecoratorCouponOnMarketplace(this.getCurDecal())
  }

  function onMarketplaceConsumeCoupon() {
    askConsumeDecoratorCoupon(this.getCurDecal(), null)
  }

  function onBuyDecorator() {
    askPurchaseDecorator(this.getCurDecal(), null)
  }

  function onDecalPreview() {
    this.getCurDecal()?.doPreview()
  }

  function onDecalUse() {
    let decor = this.getCurDecal()
    if (!decor)
      return

    let resourceType = decor.decoratorType.resourceType
    let decorData = getDecoratorDataToUse(decor.id, resourceType)
    if (decorData.decorator == null) {
      showDecoratorAccessRestriction(decor, getPlayerCurUnit(), true)
      return
    }

    useDecorator(decor, decorData.decoratorUnit, decorData.decoratorSlot)
  }

  function onGotoCollection() {
    openCollectionsWnd({ selectedDecoratorId = this.getCurDecal()?.id })
  }

  function onToggleFav() {
    let decal = this.getCurDecal()
    toggleUnlockFav(decal?.unlockId)
    this.updateDecalButtons(decal)
  }

  function onSheetChange(_obj) {
    let sheet = this.getCurSheet()
    if (this.hasEditProfileChanges()) {
      this.askAboutSaveProfile(@() this.onSheetChange(null))
      return
    }
    if (this.isEditModeEnabled)
      this.setEditMode(false)

    this.curFilterType = ""
    foreach (btn in ["btn_top_place", "btn_pagePrev", "btn_pageNext", "checkbox_only_for_bought"])
      showObjById(btn, false, this.scene)

    let pageHasProfileHeader = this.isPageHasProfileHandler(sheet)
    showObjById("profile_header", pageHasProfileHeader, this.scene)

    let accountImage = this.scene.findObject("profile_header_picture")
    accountImage.height = pageHasProfileHeader ? "1@maxAccountHeaderHeight" : "1@minAccountHeaderHeight"

    if (!this.isProfileInited) {
      ::fill_gamer_card(getProfileInfo(), "profile-", this.scene)
      if (pageHasProfileHeader)
        this.updateStats()
    }

    if (sheet == "UserCard") {
      this.showSheetDiv("usercard")
    }
    else if (sheet == "Statistics") {
      this.showSheetDiv("records")
      this.fillAirStats()
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
        //challange and achievents
        this.showSheetDiv("unlocks")
        this.curPage = this.getPageIdByName(sheet)
        this.fillUnlocksList()
      }
      else {
        this.showSheetDiv("skins", true, true)
        let pageList = this.scene.findObject("pages_list")
        let curCountry = this.filterCountryName || profileCountrySq.value
        local selIdx = 0

        let view = { items = [] }
        foreach (idx, item in this.unlockFilters[sheet]) {
          selIdx = item == curCountry ? idx : selIdx
          view.items.append(
            {
              image = getCountryIcon(item)
              tooltip = $"#{item}"
            }
          )
        }

        let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
        this.guiScene.replaceContentFromText(pageList, data, data.len(), this)  // fill countries listbox
        pageList.setValue(selIdx)
        if (selIdx <= 0)
          this.onPageChange(null)
      }
    }
    else
      this.showSheetDiv("")

    this.updateButtons()
  }

  function getPageIdByName(name) {
    let start = name.indexof("Unlock")
    if (start != null)
      return name.slice(start + 6)
    return name
  }

  function showSheetDiv(name, pages = false, subPages = false) {
    foreach (div in ["usercard", "records", "unlocks", "skins", "stats", "medals", "decals"]) {
      let show = div == name
      let divObj = this.scene.findObject($"{div}-container")
      if (checkObj(divObj)) {
        divObj.show(show)
        divObj.enable(show)
        if (show)
          this.updateDifficultySwitch(divObj)
      }
    }
    showObjById("pages_list", pages, this.scene)
    showObjById("unit_type_list", subPages, this.scene)
  }

  function onDecalCategorySelect(listObj) {
    let categoryId = listObj.getChild(listObj.getValue()).id
    this.openDecalCategory(listObj, categoryId)
    saveLocalByAccount("wnd/decalsCategory", categoryId)
    this.fillDecalsList()
  }

  function fillDecalsList() {
    let listObj = this.scene.findObject("decals_group_list")
    if (!listObj?.isValid())
      return

    let idx = listObj.getValue()
    if (idx == -1)
      return

    let categoryObj = listObj.getChild(idx)
    let isCollapsable = categoryObj?.collapse_header == "yes"
    let decalsListObj = this.scene.findObject("decals_zone")
    showObjById("decals_separator", !isCollapsable, this.scene)
    if (isCollapsable) {
      this.guiScene.replaceContentFromText(decalsListObj, "", 0, null)
      this.onDecalSelect()
      return
    }

    let [categoryId, groupId = "other"] = categoryObj.id.split("/")
    let markup = this.getDecalsMarkup(categoryId, groupId)
    this.guiScene.replaceContentFromText(decalsListObj, markup, markup.len(), this)

    if (this.initDecalId != "") {
      let decalIdx = findChildIndex(decalsListObj, @(c) c.id == this.initDecalId)
      this.initDecalId = ""
      decalsListObj.setValue(decalIdx != -1 ? decalIdx : 0)
      return
    }

    decalsListObj.setValue(0)
    this.onDecalSelect()
  }

  isDecalGroup = @(categoryId) categoryId.indexof("/") != null

  function openDecalCategory(listObj, categoryId) {
    if (this.isDecalGroup(categoryId))
      return

    local visible = false
    let total = listObj.childrenCount()
    for (local i = 0; i < total; ++i) {
      let categoryObj = listObj.getChild(i)
      if (this.isDecalGroup(categoryObj.id)) {
        categoryObj.enable(visible)
        categoryObj.show(visible)
        continue
      }

      let isCollapsable = "collapsed" in categoryObj
      if (!isCollapsable)
        continue

      categoryObj.collapsed = categoryObj.id == categoryId ? "no" : "yes"
      visible = categoryObj.collapsed == "no"
    }
  }

  function onDecalSelect() {
    let decal = this.getCurDecal()
    this.updateDecalInfo(decal)
    this.updateDecalButtons(decal)
  }

  function updateDecalInfo(decor) {
    let infoObj = showObjById("decal_info", decor != null, this.scene)
    if (!decor)
      return

    let img = decor.decoratorType.getImage(decor)
    let imgObj = infoObj.findObject("decalImage")
    imgObj["background-image"] = img

    let title = decor.getName()
    infoObj.findObject("decalTitle").setValue(title)

    let desc = decor.getDesc()
    infoObj.findObject("decalDesc").setValue(desc)

    let cfg = decor.unlockBlk != null
      ? buildUnlockDesc(::build_conditions_config(decor.unlockBlk))
      : null

    let progressObj = infoObj.findObject("decalProgress")
    if (cfg != null) {
      let progressData = cfg.getProgressBarData()
      progressObj.show(progressData.show)
      if (progressData.show)
        progressObj.setValue(progressData.value)
    }
    else
      progressObj.show(false)

    infoObj.findObject("decalMainCond").setValue(getUnlockMainCondDescByCfg(cfg , { showSingleStreakCondText = true }))
    infoObj.findObject("decalMultDecs").setValue(getUnlockMultDescByCfg(cfg))
    infoObj.findObject("decalConds").setValue(getUnlockCondsDescByCfg(cfg))
    infoObj.findObject("decalPrice").setValue(this.getDecalObtainInfo(decor))
  }

  function getDecalObtainInfo(decor) {
    if (decor.isUnlocked())
      return ""

    if (decor.canBuyUnlock(null))
      return decor.getCostText()

    if (decor.canGetFromCoupon(null))
      return " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_get_from_coupon")))

    if (decor.canBuyCouponOnMarketplace(null))
      return " ".concat(loc("currency/gc/sign/colored"),
        colorize("currencyGCColor", loc("shop/object/can_be_found_on_marketplace")))

    if (canGetDecoratorFromTrophy(decor))
      return loc("mainmenu/itemCanBeReceived")

    return ""
  }

  function getCurDecal() {
    if (this.getCurSheet() != "UnlockDecal")
      return null

    let listObj = this.scene.findObject("decals_zone")
    if (!listObj?.isValid())
      return null

    let idx = listObj.getValue()
    if (idx == -1 || idx >= listObj.childrenCount())
      return null

    let decalId = listObj.getChild(idx).id
    return getDecorator(decalId, decoratorTypes.DECALS)
  }

  function onPageChange(_obj) {
    local pageIdx = 0
    let sheet = this.getCurSheet()
    if (!(sheet in this.unlockFilters) || !this.unlockFilters[sheet])
      return

    pageIdx = this.scene.findObject("pages_list").getValue()
    if (pageIdx < 0 || pageIdx >= this.unlockFilters[sheet].len())
      return

    let filter = this.unlockFilters[sheet][pageIdx]
    this.curPage = ("page" in filter) ? filter.page : this.getPageIdByName(sheet)

    this.curFilterType = this.filterTable?[sheet] ?? ""
    if (this.curFilterType != "")
      this.curFilter = filter

    if (this.getCurSheet() == "UnlockSkin")
      this.refreshUnitTypeControl()
  }

  function onSubPageChange(_obj = null) {
    let subSwitch = this.getObj("unit_type_list")
    if (subSwitch?.isValid()) {
      let value = subSwitch.getValue()
      let unitType = unitTypes.getByEsUnitType(value)
      this.curSubFilter = unitType.esUnitType
      this.filterUnitTag = unitType.tag
      this.refreshOwnUnitControl(value)
    }
    this.fillUnlocksList()
  }

  function onOnlyForBoughtCheck(_obj) {
    this.onSubPageChange()
  }

  function refreshUnitTypeControl() {
    let unitypeListObj = this.scene.findObject("unit_type_list")
    if (! checkObj(unitypeListObj))
      return

    if (! unitypeListObj.childrenCount()) {
      local filterUnitType = unitTypes.getByTag(this.filterUnitTag)
      if (!filterUnitType.isAvailable())
        filterUnitType = unitTypes.getByEsUnitType(getEsUnitType(getPlayerCurUnit()))

      let view = { items = [] }
      foreach (unitType in unitTypes.types)
        if (unitType.isAvailable())
          view.items.append(
            {
              image = unitType.testFlightIcon
              tooltip = unitType.getArmyLocName()
              selected = filterUnitType == unitType
            }
          )

      let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
      this.guiScene.replaceContentFromText(unitypeListObj, data, data.len(), this)
    }

    local indexForSelection = -1
    let previousSelectedIndex = unitypeListObj.getValue()
    let total = unitypeListObj.childrenCount()
    for (local i = 0; i < total; i++) {
      let obj = unitypeListObj.getChild(i)
      let unitType = unitTypes.getByEsUnitType(i)
      let isVisible = this.getSkinsCache(this.curFilter, unitType.esUnitType, OwnUnitsType.ALL).len() > 0
      if (isVisible && (indexForSelection == -1 || previousSelectedIndex == i))
        indexForSelection = i;
      obj.enable(isVisible)
      obj.show(isVisible)
    }

    this.refreshOwnUnitControl(indexForSelection)

    if (indexForSelection > -1)
      unitypeListObj.setValue(indexForSelection)

    this.onSubPageChange(unitypeListObj)
  }

  function recacheSkins() {
    this.skinsCache = {}
    foreach (skinName, decorator in getCachedDecoratorsListByType(decoratorTypes.SKINS)) {
      let unit = getAircraftByName(getPlaneBySkinId(skinName))
      if (!unit)
        continue

      if (! unit.isVisibleInShop())
        continue

      if (!decorator || !decorator.isVisible())
        continue

      let unitType = getEsUnitType(unit)
      let unitCountry = getUnitCountry(unit)

      if (! (unitCountry in this.skinsCache))
        this.skinsCache[unitCountry] <- {}
      if (! (unitType in this.skinsCache[unitCountry]))
        this.skinsCache[unitCountry][unitType] <- {}

      if (! (OwnUnitsType.ALL in this.skinsCache[unitCountry][unitType]))
        this.skinsCache[unitCountry][unitType][OwnUnitsType.ALL] <- []
      this.skinsCache[unitCountry][unitType][OwnUnitsType.ALL].append(decorator)

      if (! unit.isBought())
        continue

      if (! (OwnUnitsType.BOUGHT in this.skinsCache[unitCountry][unitType]))
              this.skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT] <- []
      this.skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT].append(decorator)
    }
  }

  function getSkinsCache(country, unitType, ownType) {
    if (! this.skinsCache)
      this.recacheSkins()
    return this.skinsCache?[country][unitType][ownType] ?? []
  }

  function getCurrentOwnType() {
    let ownSwitch = this.scene.findObject("checkbox_only_for_bought")
    let ownType = (! checkObj(ownSwitch) || ! ownSwitch.getValue()) ? OwnUnitsType.ALL : OwnUnitsType.BOUGHT
    return ownType
  }

  function refreshOwnUnitControl(unitType) {
    let ownSwitch = this.scene.findObject("checkbox_only_for_bought")
    local tooltip = loc("profile/only_for_bought/hint")
    local enabled = true
    if (this.getSkinsCache(this.curFilter, unitType, OwnUnitsType.BOUGHT).len() < 1) {
      if (ownSwitch.getValue() == true)
        ownSwitch.setValue(false)
      tooltip = loc("profile/only_for_bought_disabled/hint")
      enabled = false
    }
    ownSwitch.tooltip = tooltip
    ownSwitch.enable(enabled)
    ownSwitch.show(true)
  }

  function fillUnlocksList() {
    this.isPageFilling = true

    this.guiScene.setUpdatesEnabled(false, false)
    let lowerCurPage = this.curPage.tolower()
    let pageTypeId = get_unlock_type(lowerCurPage)
    if (pageTypeId == UNLOCKABLE_MEDAL)
      return

    this.updateUnlocksTree(pageTypeId)
    local data = ""
    local curIndex = 0
    if (pageTypeId == UNLOCKABLE_SKIN) {
      let itemsView = this.getSkinsView()
      data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", { items = itemsView })
      let skinId = this.initSkinId
      curIndex = itemsView.findindex(@(p) p.id == skinId) ?? 0
    }

    let containerObjId = pageTypeId == UNLOCKABLE_SKIN ? "skins_group_list" : "unlocks_group_list"
    let unlocksObj = this.scene.findObject(containerObjId)
    let isAchievementPage = pageTypeId == UNLOCKABLE_ACHIEVEMENT
    if (isAchievementPage && this.curAchievementGroupName == "")
      this.curAchievementGroupName = this.initialUnlockId == ""
        ? this.findGroupName(@(g) g.len() > 0)
        : this.findGroupName((@(g) g.contains(this.initialUnlockId)).bindenv(this))

    let ediff = getShopDiffCode()
    let markerUnlockIds = getUnlockIds(ediff)
    let manualUnlockIds = getManualUnlocks().map(@(unlock) unlock.id)
    let view = { items = [] }

    foreach (chapterName, chapterItem in this.unlocksTree) {
      if (isAchievementPage && chapterName == this.curAchievementGroupName)
        curIndex = view.items.len()

      local markerSeenIds = markerUnlockIds.filter(@(id) chapterItem.rootItems.contains(id)
        || chapterItem.groups.findindex(@(g) g.contains(id)) != null)
      local manualSeenIds = manualUnlockIds.filter(@(id) (chapterItem.rootItems.contains(id)
        || chapterItem.groups.findindex(@(g) g.contains(id)) != null) && canClaimUnlockRewardForUnit(id))

      view.items.append({
        itemTag = "campaign_item"
        id = chapterName
        itemText = $"#unlocks/chapter/{chapterName}"
        isCollapsable = chapterItem.groups.len() > 0
        unseenIcon = (markerSeenIds.len() == 0 && manualSeenIds.len() == 0) ? null : makeConfigStrByList([
          makeConfig(SEEN.UNLOCK_MARKERS, markerSeenIds),
          makeConfig(SEEN.MANUAL_UNLOCKS, manualSeenIds)
        ])
      })

      if (chapterItem.groups.len() > 0)
        foreach (groupName, groupItem in chapterItem.groups) {
          let id = $"{chapterName}/{groupName}"
          if (isAchievementPage && id == this.curAchievementGroupName)
            curIndex = view.items.len()

          markerSeenIds = markerSeenIds.filter(@(unlockId) groupItem.contains(unlockId))
          manualSeenIds = manualUnlockIds.filter(@(unlockId) groupItem.contains(unlockId)
            && canClaimUnlockRewardForUnit(unlockId))

          view.items.append({
            id = id
            itemText = chapterItem.rootItems.indexof(groupName) != null ? $"#{groupName}/name" : $"#unlocks/group/{groupName}"
            unseenIcon = (markerSeenIds.len() == 0 && manualSeenIds.len() == 0) ? null : makeConfigStrByList([
              makeConfig(SEEN.UNLOCK_MARKERS, markerSeenIds),
              makeConfig(SEEN.MANUAL_UNLOCKS, manualSeenIds)
            ])
          })
        }
    }
    data = "".concat(data, handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view))
    this.guiScene.replaceContentFromText(unlocksObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)
    this.collapse(this.curAchievementGroupName != "" ? this.curAchievementGroupName : null)

    let total = unlocksObj.childrenCount()
    curIndex = total ? clamp(curIndex, 0, total - 1) : -1
    unlocksObj.setValue(curIndex)
    this.isPageFilling = false
    this.updateFavoritesCheckboxesInList()
  }

  function getSkinsView() {
    let itemsView = []
    let comma = loc("ui/comma")
    foreach (decorator in this.getSkinsCache(this.curFilter, this.curSubFilter, this.getCurrentOwnType())) {
      let unitId = getPlaneBySkinId(decorator.id)

      itemsView.append({
        id = decorator.id
        itemText = comma.concat(getUnitName(unitId), decorator.getName())
        itemIcon = decorator.isUnlocked() ? "#ui/gameuiskin#unlocked.svg" : "#ui/gameuiskin#locked.svg"
      })
    }
    return itemsView.sort(@(a, b) a.itemText <=> b.itemText)
  }

  function findGroupName(func) {
    foreach (chapterName, chapter in this.unlocksTree) {
      if (chapter.rootItems.findindex(func) != null)
        return chapterName

      let groupId = chapter.groups.findindex(func)
      if (groupId != null)
        return $"{chapterName}/{groupId}"
    }
    return ""
  }

  function updateUnlocksTree(pageTypeId) {
    this.unlocksTree = {}
    let lowerCurPage = this.curPage.tolower()
    let isCustomMenuTab = lowerCurPage in this.customMenuTabs
    let isUnlockTree = isCustomMenuTab || pageTypeId == -1 || pageTypeId == UNLOCKABLE_ACHIEVEMENT
    local chapter = ""
    local group = ""

    foreach (_idx, cb in getAllUnlocksWithBlkOrder()) {
      let name = cb.getStr("id", "")
      let unlockType = cb?.type ?? ""
      let unlockTypeId = get_unlock_type(unlockType)
      let isForceVisibleInTree = cb?.isForceVisibleInTree ?? false
      if (unlockTypeId != pageTypeId
          && (!isUnlockTree || !isInArray(unlockTypeId, this.unlockTypesToShow))
          && !isForceVisibleInTree)
        continue
      if (isUnlockTree && cb?.isRevenueShare)
        continue
      if (!isUnlockVisible(cb))
        continue
      if (isBattleTask(cb))
        continue

      if (isCustomMenuTab) {
        if (!cb?.customMenuTab || cb?.customMenuTab.tolower() != lowerCurPage)
          continue
      }
      else if (cb?.customMenuTab)
        continue

      if (this.curFilterType == "country" && cb.getStr("country", "") != this.curFilter)
        continue

      if (isUnlockTree) {
        let mode = cb?.mode
        if(mode != null) {
          if((mode % "condition").filter(@(v) v?.type == "battlepassSeason").len() > 0)
            continue
          if((mode % "hostCondition").filter(@(v) v?.type == "battlepassSeason").len() > 0)
            continue
        }
        let newChapter = cb.getStr("chapter", "")
        let newGroup = cb.getStr("group", "")
        if (newChapter != "") {
          chapter = newChapter
          group = newGroup
        }
        if (newGroup != "")
          group = newGroup
        if (!(chapter in this.unlocksTree))
          this.unlocksTree[chapter] <- { rootItems = [], groups = {} }
        if (group != "" && !(group in this.unlocksTree[chapter].groups))
          this.unlocksTree[chapter].groups[group] <- []
        if (group == "")
          this.unlocksTree[chapter].rootItems.append(name)
        else
          this.unlocksTree[chapter].groups[group].append(name)
        continue
      }
    }
  }

  function getSkinsUnitType(skinName) {
    let unit = this.getUnitBySkin(skinName)
    if (!unit)
      return ES_UNIT_TYPE_INVALID
    return getEsUnitType(unit)
  }

  function getUnitBySkin(skinName) {
    return getAircraftByName(getPlaneBySkinId(skinName))
  }

  function getDecalsMarkup(categoryId, groupId) {
    let decorCache = getCachedDataByType(decoratorTypes.DECALS)
    let decorators = decorCache.catToGroups?[categoryId][groupId]
    if (!decorators || decorators.len() == 0)
      return ""

    let view = {
      items = decorators.map(@(decorator) {
        id = decorator.id
        tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decorator.decoratorType.unlockedItemType)
        unlocked = true
        tag = "imgSelectable"
        image = decorator.decoratorType.getImage(decorator)
        imgRatio = decorator.decoratorType.getRatio(decorator)
        statusLock = decorator.isUnlocked() ? null : "achievement"
        imgClass = "profileMedals"
      })
    }
    return handyman.renderCached("%gui/commonParts/imgFrame.tpl", view)
  }

  function checkSkinVehicle(unitName) {
    let unit = getAircraftByName(unitName)
    if (unit == null)
      return false
    return unit.isVisibleInShop()
  }

  function collapse(itemName = null) {
    let listObj = this.scene.findObject("unlocks_group_list")
    if (!listObj || !this.unlocksTree || this.unlocksTree.len() == 0)
      return

    let chapterRegexp = regexp2("/[^\\s]+")
    let chapterName = itemName && chapterRegexp.replace("", itemName)
    this.uncollapsedChapterName = chapterName ?
      (chapterName == this.uncollapsedChapterName) ? null : chapterName
      : this.uncollapsedChapterName
    local newValue = -1

    this.guiScene.setUpdatesEnabled(false, false)
    let total = listObj.childrenCount()
    for (local i = 0; i < total; i++) {
      let obj = listObj.getChild(i)
      let iName = obj?.id
      let isUncollapsedChapter = iName == this.uncollapsedChapterName
      if (iName == (isUncollapsedChapter ? this.curAchievementGroupName : chapterName))
        newValue = i

      if (iName in this.unlocksTree) { //chapter
        obj.collapsed = isUncollapsedChapter ? "no" : "yes"
        continue
      }

      let iChapter = iName && chapterRegexp.replace("", iName)
      let visible = iChapter == this.uncollapsedChapterName
      obj.enable(visible)
      obj.show(visible)
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      listObj.setValue(newValue)
  }

  function onCollapseDecals(obj) {
    this.doCollapse(obj, this.scene.findObject("decals_group_list"))
  }

  function onCollapse(obj) {
    this.doCollapse(obj, this.scene.findObject("unlocks_group_list"))
  }

  function doCollapse(obj, listBoxObj) {
    if (!obj || !listBoxObj)
      return
    let id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_") {
      this.collapse(id.slice(4))
      let listItemCount = listBoxObj.childrenCount()
      for (local i = 0; i < listItemCount; i++) {
        let listItemId = listBoxObj.getChild(i)?.id
        if (listItemId == id.slice(4)) {
          listBoxObj.setValue(i)
          break
        }
      }
    }
  }

  function onCodeAppClick(_obj) {
    openUrl(getCurCircuitOverride("twoStepCodeAppURL", loc("url/2step/codeApp")))
  }

  function onGroupCollapse(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    this.collapse(obj.getChild(value).id)
  }

  function openCollapsedGroup(group, name) {
    this.collapse(group)
    let reqBlockName = group + (name ? ($"/{name}") : "")
    let listBoxObj = this.scene.findObject("unlocks_group_list")
    if (!checkObj(listBoxObj))
      return

    let listItemCount = listBoxObj.childrenCount()
    for (local i = 0; i < listItemCount; i++) {
      let listItemId = listBoxObj.getChild(i).id
      if (reqBlockName == listItemId)
        return listBoxObj.setValue(i)
    }
  }

  function getSkinDesc(decor) {
    return "\n".join([
      decor.getDesc(),
      decor.getTypeDesc(),
      decor.getLocParamsDesc(),
      decor.getRestrictionsDesc(),
      decor.getLocationDesc(),
      decor.getTagsDesc()
    ], true)
  }

  function getSubUnlocksView(config) {
    if (!config)
      return null

    return getLocForBitValues(config.type, config.names)
      .map(function(name, i) {
        let isUnlocked = is_bit_set(config.curVal, i)
        let text = config?.compareOR && i > 0
          ? $"{loc("hints/shortcut_separator")}\n{name}"
          : name
        return {
          unlocked = isUnlocked ? "yes" : "no"
          text
        }
      })
  }

  function updateUnlockFav(name, objDesc) {
    fillUnlockFav(name, objDesc)
  }

  function fillSkinDescr(name) {
    let unitName = getPlaneBySkinId(name)
    let unitNameLoc = (unitName != "") ? getUnitName(unitName) : ""
    let unlockBlk = getUnlockById(name)
    let config = unlockBlk ? ::build_conditions_config(unlockBlk) : null
    let progressData = config?.getProgressBarData()
    let canAddFav = !!unlockBlk
    let decorator = getDecoratorById(name)

    let skinView = {
      unitName = unitNameLoc
      skinName = decorator.getName()

      image = config?.image ?? decoratorTypes.SKINS.getImage(decorator)
      ratio = config?.imgRatio ?? decoratorTypes.SKINS.getRatio(decorator)
      status = decorator.isUnlocked() ? "unlocked" : "locked"

      skinDesc = this.getSkinDesc(decorator)
      unlockProgress = progressData?.value
      hasProgress = progressData?.show
      skinPrice = decorator.getCostText()
      mainCond = getUnlockMainCondDescByCfg(config, { showSingleStreakCondText = true })
      multDesc = getUnlockMultDescByCfg(config)
      conds = getUnlockCondsDescByCfg(config)
      conditions = this.getSubUnlocksView(config)
      canAddFav
    }

    this.guiScene.setUpdatesEnabled(false, false)
    let markUpData = handyman.renderCached("%gui/profile/profileSkins.tpl", skinView)
    let objDesc = showObjById("skin_desc", true, this.scene)
    this.guiScene.replaceContentFromText(objDesc, markUpData, markUpData.len(), this)

    if (canAddFav)
      fillUnlockFav(name, objDesc)

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function unlockToFavorites(obj) {
    if (obj?.isChecked != null)
      obj.isChecked = obj.isChecked == "yes" ? "no" : "yes"
    unlockToFavorites(obj, Callback(this.updateFavoritesCheckboxesInList, this))
  }

  function updateFavoritesCheckboxesInList() {
    if (this.isPageFilling)
      return

    let canAddFav = canAddFavorite()
    foreach (unlockId in this.getCurUnlockList()) {
      let unlockObj = this.scene.findObject(this.getUnlockBlockId(unlockId))
      if (!checkObj(unlockObj))
        continue

      let cbObj = unlockObj.findObject("checkbox_favorites")
      if (checkObj(cbObj))
        cbObj.inactiveColor = (canAddFav || isUnlockFav(unlockId)) ? "no" : "yes"
    }
  }

  function unlockToFavoritesByActivateItem(obj) {
    let childrenCount = obj.childrenCount()
    let index = obj.getValue()
    if (index < 0 || index >= childrenCount)
      return

    let checkBoxObj = obj.getChild(index).findObject("checkbox_favorites")
    if (!checkObj(checkBoxObj))
      return

    this.unlockToFavorites(checkBoxObj)
  }

  function onManualOpenUnlock(obj) {
    let unlockId = obj?.unlockId ?? ""
    if (unlockId == "")
      return

    let unit = findUnusableUnitForManualUnlock(unlockId)
    if (unit) {
      this.msgBox("cantClaimReward", loc("msgbox/cantClaimManualUnlockPrize",
        { unitname = getUnitName(unit) }), [["ok"]], "ok")
      return
    }

    let onSuccess = Callback(@() this.updateUnlockBlock(unlockId), this)
    openUnlockManually(unlockId, onSuccess)
  }

  function onBuyUnlock(obj) {
    let unlockId = getTblValue("unlockId", obj)
    if (u.isEmpty(unlockId))
      return

    let cost = getUnlockCost(unlockId)

    let title = warningIfGold(
      loc("onlineShop/needMoneyQuestion", { purchase = colorize("unlockHeaderColor",
        getUnlockNameText(-1, unlockId)),
        cost = cost.getTextAccordingToBalance()
      }), cost)
    purchaseConfirmation("question_buy_unlock", title, @() buyUnlock(unlockId,
      Callback(@() this.updateUnlockBlock(unlockId), this),
      Callback(@() this.onUnlockGroupSelect(null), this)))
  }

  function updateUnlockBlock(unlockData) {
    local unlock = unlockData
    if (u.isString(unlockData))
      unlock = getUnlockById(unlockData)

    let unlockObj = this.scene.findObject(this.getUnlockBlockId(unlock.id))
    if (checkObj(unlockObj))
      this.fillUnlockInfo(unlock, unlockObj)
  }

  function onPrizePreview(obj) {
    this.previewUnlockId = obj.unlockId
    let unlockCfg = ::build_conditions_config(getUnlockById(obj.unlockId))
    deferOnce(@() doPreviewUnlockPrize(unlockCfg))
  }

  function showUnlockPrizes(obj) {
    let trophy = findItemById(obj.trophyId)
    let content = trophy.getContent()
      .map(@(i) u.isDataBlock(i) ? convertBlk(i) : {})
      .sort(rewardsSortComparator)

    openTrophyRewardsList({ rewardsArray = content })
  }

  function showUnlockUnits(obj) {
    openUnlockUnitListWnd(obj.unlockId, Callback(@(unit) this.showUnitInShop(unit), this))
  }

  function showUnitInShop(unitName) {
    if (!unitName)
      return

    broadcastEvent("ShowUnitInShop", { unitName })
    let handler = this
    defer(@() handler.goBack())
  }

  function fillUnlockInfo(unlockBlk, unlockObj) {
    let itemData = ::build_conditions_config(unlockBlk)
    buildUnlockDesc(itemData)
    unlockObj.show(true)
    unlockObj.enable(true)

    ::g_unlock_view.fillUnlockConditions(itemData, unlockObj, this)
    fillUnlockProgressBar(itemData, unlockObj)
    fillUnlockDescription(itemData, unlockObj)
    fillUnlockImage(itemData, unlockObj)
    fillReward(itemData, unlockObj)
    ::g_unlock_view.fillStages(itemData, unlockObj, this)
    fillUnlockTitle(itemData, unlockObj)
    fillUnlockFav(itemData.id, unlockObj)
    fillUnlockPurchaseButton(itemData, unlockObj)
    fillUnlockManualOpenButton(itemData, unlockObj)
    updateLockStatus(itemData, unlockObj)
    updateUnseenIcon(itemData, unlockObj)
  }

  function printUnlocksList(unlocksList) {
    let achievaAmount = unlocksList.len()
    let unlocksListObj = showObjById("unlocks_list", true, this.scene)
    showObjById("item_desc", false, this.scene)
    local blockAmount = unlocksListObj.childrenCount()

    this.guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievaAmount) {
      let unlockItemBlk = "%gui/profile/unlockItem.blk"
      for (; blockAmount < achievaAmount; blockAmount++)
        this.guiScene.createElementByObject(unlocksListObj, unlockItemBlk, "expandable", this)
    }
    else if (blockAmount > achievaAmount) {
      for (; blockAmount > achievaAmount; blockAmount--) {
        unlocksListObj.getChild(blockAmount - 1).show(false)
        unlocksListObj.getChild(blockAmount - 1).enable(false)
      }
    }

    local selIdx = null
    for (local i = 0; i < unlocksList.len(); ++i) {
      let curUnlock = getUnlockById(unlocksList[i])
      let unlockObj = unlocksListObj.getChild(i)
      unlockObj.id = this.getUnlockBlockId(curUnlock.id)
      unlockObj.holderId = curUnlock.id
      this.fillUnlockInfo(curUnlock, unlockObj)

      if (selIdx == null
          && (this.initialUnlockId == curUnlock.id
            || (this.initialUnlockId == "" && canOpenUnlockManually(curUnlock))))
        selIdx = i
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (unlocksListObj.childrenCount() > 0)
      unlocksListObj.setValue(selIdx ?? 0)

    seenUnlockMarkers.markSeen(getUnlockIds(getCurrentGameModeEdiff())
      .filter(@(unlock) unlocksList.contains(unlock)))
  }


  function getUnlockBlockId(unlockId) {
    return $"{unlockId}_block"
  }

  function onUnlockSelect(obj) {
    if (obj?.isValid())
      this.initialUnlockId = ""
  }

  function onUnlockGroupSelect(_obj) {
    let isSkinPage = this.curPage.tolower() == "skin"
    let list = this.scene.findObject(isSkinPage ? "skins_group_list" : "unlocks_group_list")
    let index = list.getValue()
    local unlocksList = []
    if ((index >= 0) && (index < list.childrenCount())) {
      let curObj = list.getChild(index)
      if (isSkinPage)
        this.fillSkinDescr(curObj.id)
      else {
        let id = curObj.id
        let isGroup = (id in this.unlocksTree)
        if (isGroup)
          unlocksList = this.unlocksTree[id].rootItems
        else
          foreach (chapterName, chapterItem in this.unlocksTree)
            if (chapterName.len() + 1 < id.len()
                && id.slice(0, chapterName.len()) == chapterName
                && id.slice(chapterName.len() + 1) in chapterItem.groups) {
              unlocksList = chapterItem.groups[id.slice(chapterName.len() + 1)]
              break
            }
        this.printUnlocksList(unlocksList)
        if (!isSkinPage) {
          this.curAchievementGroupName = id
          if (isGroup && id != this.uncollapsedChapterName)
            this.onGroupCollapse(list)
        }
      }
    }
  }

  function onSkinPreview(_obj) {
    let list = this.scene.findObject("skins_group_list")
    let index = list.getValue()
    if ((index < 0) || (index >= list.childrenCount()))
      return

    let skinId = list.getChild(index).id
    let decorator = getDecoratorById(skinId)
    this.initSkinId = skinId
    if (decorator && canStartPreviewScene(true, true))
      this.guiScene.performDelayed(this, @() decorator.doPreview())
  }

  function getHandlerRestoreData() {
    let data = {
     openData = {
        initialSheet = this.getCurSheet()
        initSkinId = this.initSkinId
        initialUnlockId = this.previewUnlockId
        initDecalId = this.getCurDecal()?.id ?? ""
        filterCountryName = this.curFilter
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

    for (local idx = 0; idx < 3; idx++) //difficulty
      if (idx == diff || diff < 0)

        for (local pm = 0; pm < 2; pm++)  //players
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
    return ::buildTableRowNoPad("", row)
  }

  function updateStats() {
    let myStats = getStats()
    if (!myStats || !checkObj(this.scene))
      return
    this.isProfileInited = true
    this.fillProfileStats(myStats)
    this.updateShowcase()
  }

  function openChooseTitleWnd(_obj) {
    let cachedHandler = this
    let curTitle = this.editModeTempData?.title ?? ""
    gui_handlers.ChooseTitle.open({
      onCompleteFunc = @(titleName) cachedHandler.onProfileTitleSelect(titleName, cachedHandler)
      curTitle
    })
  }

  function openProfileTab(tab, selectedBlock) {
    let obj = this.scene.findObject("profile_sheet_list")
    if (checkObj(obj)) {
      let num = u.find_in_array(this.sheetsList, tab)
      if (num < 0)
        return
      obj.setValue(num)
      this.openCollapsedGroup(selectedBlock, null)
    }
  }

  function showDecalsSheet() {
    this.showSheetDiv("decals", true)

    let decorCache = getCachedDataByType(decoratorTypes.DECALS)
    let view = { items = [] }
    foreach (categoryId in decorCache.categories) {
      let groups = decorCache.catToGroupNames[categoryId]
      let hasGroups = groups.len() > 1 || groups[0] != "other"
      view.items.append({
        id = categoryId
        itemTag = "campaign_item"
        itemText = $"#decals/category/{categoryId}"
        isCollapsable = hasGroups
        onCollapseFunc = "onCollapseDecals"
      })

      if (hasGroups)  {
        view.items.extend(groups.map(@(groupId) {
          id = $"{categoryId}/{groupId}"
          itemText = $"#decals/group/{groupId}"
        }))
      }
    }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    let categoriesListObj = this.scene.findObject("decals_group_list")
    this.guiScene.replaceContentFromText(categoriesListObj, data, data.len(), this)

    let selCategory = this.filterGroupName ?? loadLocalByAccount("wnd/decalsCategory", "")
    if (this.isDecalGroup(selCategory))
      this.openDecalCategory(categoriesListObj, selCategory.split("/")[0])

    let selIdx = view.items.findindex(@(c) c.id == selCategory) ?? 0
    categoriesListObj.setValue(selIdx)

    this.guiScene.applyPendingChanges(false)
    categoriesListObj.getChild(selIdx).scrollToView()
  }

  function fillProfileStats(stats) {
    this.fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles")
    if ("uid" in stats && stats.uid != userIdStr.value)
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

    ::set_current_wnd_difficulty(this.curMode)
    this.updateCurrentStatsMode(this.curMode)
    fillProfileSummary(this.scene.findObject("stats_table"), myStats.summary, this.curMode)
  }

  function onUpdate(_obj, _dt) {
    if (this.pending_logout && ::is_app_active() && !steam_is_overlay_active() && !::is_builtin_browser_active()) {
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
    avatars.openChangePilotIconWnd(this.onIconChoosen, this)
  }

  function openViralAcquisitionWnd() {
    showViralAcquisitionWnd()
  }

  function onEventProfileUpdated(_params) {
    ::fill_gamer_card(getProfileInfo(), "profile-", this.scene)
  }

  function onEventMyStatsUpdated(_params) {
    let sheet = this.getCurSheet()
    if (sheet == "Statistics")
      this.fillAirStats()

    if (this.isPageHasProfileHandler(sheet))
      this.updateStats()
    else
      this.isProfileInited = false
  }

  function onEventClanInfoUpdate(_params) {
    this.fillClanInfo(getProfileInfo())
  }

  function initAirStats() {
    let myStats = getStats()
    if (!myStats || !checkObj(this.scene))
      return

    this.initAirStatsPage()
  }

  function fillAirStats() {
    let myStats = getStats()
    if (!this.airStatsInited || !myStats || !myStats.userstat)
      return this.initAirStats()

    this.fillAirStatsScene(myStats.userstat)
  }

  function getPlayerStats() {
    return getStats()
  }

  function getCurUnlockList() {
    let list = this.scene.findObject("unlocks_group_list")
    let index = list.getValue()
    local unlocksList = []
    if ((index < 0) || (index >= list.childrenCount()))
      return unlocksList

    let curObj = list.getChild(index)
    let id = curObj.id
    if (id in this.unlocksTree)
      unlocksList = this.unlocksTree[id].rootItems
    else
      foreach (chapterName, chapterItem in this.unlocksTree) {
        let subsectionName = cutPrefix(id,$"{chapterName}/", null)
        if (!subsectionName)
          continue

        unlocksList = chapterItem?.groups?[subsectionName] ?? []
        if (unlocksList.len() > 0)
          return unlocksList
      }
    return unlocksList
  }

  function onGroupCancel(_obj) {
    if (showConsoleButtons.value && this.getCurSheet() == "UnlockSkin") {
      move_mouse_on_child_by_value(this.scene.findObject("pages_list"))
      return
    }
    let handler = this
    defer(@() handler.goBack())
  }

  function onBindEmail() {
    if (needShowGuestEmailRegistration())
      getPlayerSsoShortTokenAsync("onGetStokenForGuestEmail")
    else
      launchEmailRegistration()
    this.doWhenActiveOnce("updateButtons")
  }

  function onEventUnlocksCacheInvalidate(_p) {
    let curSheet = this.getCurSheet()
    if (curSheet == "UnlockAchievement")
      this.fillUnlocksList()
    else if (curSheet == "UnlockDecal")
      this.fillDecalsList()
  }

  function onEventRegionalUnlocksChanged(_params) {
    if (this.getCurSheet() == "UnlockAchievement")
      this.fillUnlocksList()
  }

  function onEventUnlockMarkersCacheInvalidate(_) {
    if (this.getCurSheet() == "UnlockAchievement")
      this.fillUnlocksList()
  }

  function onEventInventoryUpdate(_p) {
    let curSheet = this.getCurSheet()
    if (curSheet == "UnlockAchievement")
      this.fillUnlocksList()
    else if (curSheet == "UnlockDecal")
      this.fillDecalsList()
  }

  function onOpenAchievementsUrl() {
    openUrl(getCurCircuitOverride("achievementsURL", loc("url/achievements")).subst(
        { appId = APP_ID, name = getProfileInfo().name }),
      false, false, "profile_page")
  }

  function isMedalUnlocked(name) {
    return isUnlockOpened(name, UNLOCKABLE_MEDAL)
  }

  function goBack() {
    if (!this.scene.isValid())
      return

    if (this.hasEditProfileChanges()) {
      this.askAboutSaveProfile(@() this.goBack())
      return
    }
    if (this.isEditModeEnabled)
      this.setEditMode(false)

    base.goBack()
  }

  onLeaderboard = @() loadHandler(gui_handlers.LeaderboardWindow, { userId = userIdInt64.get() })

  function onShowcaseSelect(_obj) {

  }

  function fillShowcaseEdit(terseInfo) {
    local data = getEditViewData()
    let nest = this.scene.findObject("showcase_edit");
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)

    data = getShowcaseTypeBoxData(terseInfo)
    let showcaseTypesBox = nest.findObject("showcase_gamemodes")
    this.guiScene.replaceContentFromText(showcaseTypesBox, data, data.len(), this)

    let index = getGameModeBoxIndex(terseInfo)
    if (index >= 0)
      showcaseTypesBox.setValue(index)
  }

  function onSaveShowcaseComplete(savedShowcase) {
    this.terseInfo = savedShowcase
    cachedTerseInfo = savedShowcase
    this.fillShowcase(savedShowcase, getStats())
  }

  function onSaveShowcaseError(showcaseForRestore) {
    this.terseInfo = showcaseForRestore
    cachedTerseInfo = showcaseForRestore
    this.fillShowcase(showcaseForRestore, getStats())
  }

  function onShowcaseGameModeSelect(obj) {
    if (!this.isEditModeEnabled)
      return
    let gameMode = getShowcaseGameModeByIndex(obj.getValue(), this.editModeTempData?.terseInfo ?? this.terseInfo)
    if (!gameMode)
      return
    if (this.editModeTempData?.terseInfo == null) {
      this.editModeTempData.terseInfo <- clone this.terseInfo
      this.editModeTempData.terseInfo.showcase <- clone this.terseInfo.showcase
    }
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

  function onUserInfoRequestComplete(responce, stats = null) {
    base.onUserInfoRequestComplete(responce, stats)
    cachedTerseInfo = this.terseInfo
  }

}

let openProfileSheetParamsFromPromo = {
  UnlockAchievement = @(p1, p2, ...) {
    uncollapsedChapterName = p2 != "" ? p1 : null
    curAchievementGroupName = p1 + (p2 != "" ? ($"/{p2}") : "")
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

addListenersWithoutEnv({
  SignOut = @(_p) profileSelectedFiltersCache.each(@(f) f.clear())
})

return {
  guiStartProfile
}
