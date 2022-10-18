from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

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
let { fillProfileSummary } = require("%scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require_native("guiOptions")
let { canStartPreviewScene, useDecorator, showDecoratorAccessRestriction,
  getDecoratorDataToUse } = require("%scripts/customization/contentPreview.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getSelectedChild, findChildIndex } = require("%sqDagui/daguiUtil.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getUnlockIds, getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let shopSearchWnd  = require("%scripts/shop/shopSearchWnd.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { openCollectionsWnd } = require("%scripts/collections/collectionsWnd.nut")
let { launchEmailRegistration, canEmailRegistration, emailRegistrationTooltip
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { getUnlockCondsDescByCfg, getUnlockMultDescByCfg, getUnlockNameText,
  getUnlockMainCondDescByCfg, getLocForBitValues } = require("%scripts/unlocks/unlocksViewModule.nut")
let { APP_ID } = require("app")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

enum profileEvent {
  AVATAR_CHANGED = "AvatarChanged"
}

enum OwnUnitsType
{
  ALL = "all",
  BOUGHT = "only_bought",
}

let selMedalIdx = {}

::gui_start_profile <- function gui_start_profile(params = {})
{
  if (!hasFeature("Profile"))
    return

  ::gui_start_modal_wnd(::gui_handlers.Profile, params)
}

::gui_handlers.Profile <- class extends ::gui_handlers.UserCardHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/profile/profile.blk"
  initialSheet = ""

  curDifficulty = "any"
  curPlayerMode = 0
  curFilter = ""
  curSubFilter = -1
  curFilterType = ""
  airStatsInited = false
  profileInited = false

  airStatsList = null
  statsType = ETTI_VALUE_INHISORY
  statsMode = ""
  statsCountries = null
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0

  pending_logout = false

  presetSheetList = ["Profile", "Statistics", "Medal", "UnlockAchievement", "UnlockSkin", "UnlockDecal"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"
  defaultTabImageName = "unlockachievement"

  sheetsList = null
  customMenuTabs = null

  curPage = ""
  isPageFilling = false

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

  unlocksTree = {}
  skinsCache = null
  uncollapsedChapterName = null
  curAchievementGroupName = ""
  curUnlockId = ""
  filterCountryName = null
  filterUnitTag = ""
  initSkinId = ""
  initDecalId = ""
  filterGroupName = null

  unlockFilters = {
    Medal = []
    UnlockAchievement = null
    UnlockChallenge = null
    UnlockSkin = []
  }

  filterTable = {
    Medal = "country"
    UnlockSkin = "airCountry"
  }

  function initScreen()
  {
    if (!this.scene)
      return this.goBack()

    this.isOwnStats = true
    this.scene.findObject("profile_update").setUserData(this)

    //prepare options
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    unlocksTree = {}

    this.initStatsParams()
    initSheetsList()
    initTabs()

    //fill skins filters
    if ("UnlockSkin" in unlockFilters)
    {
      let skinCountries = getUnlockFiltersList("skin", function(unlock)
        {
          let country = getSkinCountry(unlock.getStr("id", ""))
          return (country != "")? country : null
        })

      unlockFilters.UnlockSkin = ::u.filter(shopCountriesList, @(c) isInArray(c, skinCountries))
    }

    //fill medal filters
    if ("Medal" in unlockFilters)
    {
      let medalCountries = getUnlockFiltersList("medal", @(unlock) unlock?.country)
      unlockFilters.Medal = ::u.filter(shopCountriesList, @(c) isInArray(c, medalCountries))
    }

    let bntGetLinkObj = this.scene.findObject("btn_getLink")
    if (checkObj(bntGetLinkObj))
      bntGetLinkObj.tooltip = getViralAcquisitionDesc("mainmenu/getLinkDesc")

    this.initLeaderboardModes()
    initShortcuts()
  }

  function initSheetsList()
  {
    customMenuTabs = {}
    sheetsList = clone presetSheetList
    local hasAnyUnlocks = false
    local hasAnyMedals = false //skins and decals tab also have resources without unlocks

    let customCategoryConfig = getTblValue("customProfileMenuTab", ::get_gui_regional_blk(), null)
    local tabImage = null
    local tabText = null

    foreach(cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      let unlockType = cb?.type ?? ""
      let unlockTypeId = ::get_unlock_type(unlockType)

      if (!unlockTypesToShow.contains(unlockTypeId) && !unlocksPages.contains(unlockTypeId))
        continue
      if (!::is_unlock_visible(cb))
        continue

      hasAnyUnlocks = true
      if (unlockTypeId == UNLOCKABLE_MEDAL)
        hasAnyMedals = true

      if (cb?.customMenuTab == null)
        continue

      let lowerCaseTab = cb.customMenuTab.tolower()
      if (lowerCaseTab in customMenuTabs)
        continue

      sheetsList.append(lowerCaseTab)
      unlockFilters[lowerCaseTab]  <- null

      let defaultImage = format(tabImageNameTemplate, defaultTabImageName)

      if (cb.customMenuTab in customCategoryConfig)
      {
        tabImage = customCategoryConfig[cb.customMenuTab]?.image ?? defaultImage
        tabText = tabLocalePrefix + (customCategoryConfig[cb.customMenuTab]?.title ?? cb.customMenuTab)
      }
      else
      {
        tabImage = defaultImage
        tabText = tabLocalePrefix + cb.customMenuTab
      }
      customMenuTabs[lowerCaseTab] <- {
        image = tabImage
        title = tabText
      }
    }

    let sheetsToHide = []
    if (!hasAnyMedals)
      sheetsToHide.append("Medal")
    if (!hasAnyUnlocks)
      sheetsToHide.append("UnlockAchievement")
    foreach(sheetName in sheetsToHide)
    {
      let idx = sheetsList.indexof(sheetName)
      if (idx != null)
        sheetsList.remove(idx)
    }
  }

  function initTabs()
  {
    let view = { tabs = [] }
    local curSheetIdx = 0
    local tabImage = null
    local tabText = null

    foreach(idx, sheet in sheetsList)
    {
      if (sheet in customMenuTabs)
      {
        tabImage = customMenuTabs[sheet].image
        tabText = customMenuTabs[sheet].title
      }
      else
      {
        tabImage = format(tabImageNameTemplate, sheet.tolower())
        tabText = tabLocalePrefix + sheet
      }

      view.tabs.append({
        id = sheet
        tabImage = tabImage
        tabName = tabText
        unseenIcon = sheet == "UnlockAchievement" ? seenList.id : null
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
        hidden = !isSheetVisible(sheet)
      })

      if (initialSheet == sheet)
        curSheetIdx = idx
    }

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    let sheetsListObj = this.scene.findObject("profile_sheet_list")
    this.guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(curSheetIdx)
  }

  function isSheetVisible(sheetName)
  {
    if (sheetName == "Medal")
      return hasFeature("ProfileMedals")
    return true
  }

  function initShortcuts()
  {
    local obj = this.scene.findObject("btn_profile_icon")
    if (checkObj(obj))
      obj.btnName = "X"
    obj = this.scene.findObject("profile_currentUser_btn_title")
    if (checkObj(obj))
      obj.btnName = "Y"
    this.scene.findObject("unseen_titles").setValue(SEEN.TITLES)
    this.scene.findObject("unseen_avatar").setValue(SEEN.AVATARS)
  }

  function getUnlockFiltersList(uType, getCategoryFunc)
  {
    let categories = []
    let unlocks = ::g_unlocks.getUnlocksByType(uType)
    foreach(unlock in unlocks)
      if (::is_unlock_visible(unlock))
        ::u.appendOnce(getCategoryFunc(unlock), categories, true)

    return categories
  }

  function updateDecalButtons(decor) {
    if (!decor) {
      ::showBtnTable(this.scene, {
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
      && ::ItemsManager.canGetDecoratorFromTrophy(decor)

    let buyBtnObj = this.showSceneBtn("btn_buy_decorator", canBuy)
    if (canBuy && buyBtnObj?.isValid())
      placePriceTextToButton(this.scene, "btn_buy_decorator", loc("mainmenu/btnOrder"), decor.getCost())

    let canFav = !decor.isUnlocked() && ::g_unlocks.canDo(decor.unlockBlk)
    let favBtnObj = this.showSceneBtn("btn_fav", canFav)
    if (canFav)
      favBtnObj.setValue(::g_unlocks.isUnlockFav(decor.unlockId)
        ? loc("preloaderSettings/untrackProgress")
        : loc("preloaderSettings/trackProgress"))

    let canUse = decor.isUnlocked() && canStartPreviewScene(false)
    let canPreview = !canUse && decor.canPreview()

    ::showBtnTable(this.scene, {
      btn_preview                    = ::isInMenu() && canPreview
      btn_use_decorator              = ::isInMenu() && canUse
      btn_store                      = ::isInMenu() && canFindInStore
      btn_go_to_collection           = ::isInMenu() && isCollectionItem(decor)
      btn_marketplace_consume_coupon = canConsumeCoupon
      btn_marketplace_find_coupon    = canFindOnMarketplace
    })
  }

  function updateButtons()
  {
    let sheet = getCurSheet()
    let isProfileOpened = sheet == "Profile"
    let buttonsList = {
      btn_changeAccount = ::isInMenu() && isProfileOpened && !isPlatformSony && !::is_vendor_tencent()
      btn_changeName = ::isInMenu() && isProfileOpened && !isMeXBOXPlayer() && !isMePS4Player() && !::is_vendor_tencent()
      btn_getLink = !::is_in_loading_screen() && isProfileOpened && hasFeature("Invites")
      btn_codeApp = isPlatformPC && hasFeature("AllowExternalLink") &&
        !havePlayerTag("gjpass") && ::isInMenu() && isProfileOpened && !::is_vendor_tencent()
      btn_EmailRegistration = isProfileOpened && canEmailRegistration()
      paginator_place = (sheet == "Statistics") && airStatsList && (airStatsList.len() > this.statsPerPage)
      btn_achievements_url = (sheet == "UnlockAchievement") && hasFeature("AchievementsUrl")
        && hasFeature("AllowExternalLink") && !::is_vendor_tencent()
      btn_SkinPreview = ::isInMenu() && sheet == "UnlockSkin"
    }

    ::showBtnTable(this.scene, buttonsList)

    if (buttonsList.btn_EmailRegistration)
      this.scene.findObject("btn_EmailRegistration").tooltip = emailRegistrationTooltip

    updateDecalButtons(getCurDecal())
  }

  function onMarketplaceFindCoupon() {
    findDecoratorCouponOnMarketplace(getCurDecal())
  }

  function onMarketplaceConsumeCoupon() {
    askConsumeDecoratorCoupon(getCurDecal(), null)
  }

  function onBuyDecorator() {
    askPurchaseDecorator(getCurDecal(), null)
  }

  function onDecalPreview() {
    getCurDecal()?.doPreview()
  }

  function onDecalUse() {
    let decor = getCurDecal()
    if (!decor)
      return

    let resourceType = decor.decoratorType.resourceType
    let decorData = getDecoratorDataToUse(decor.id, resourceType)
    if (decorData.decorator == null) {
      showDecoratorAccessRestriction(decor, getPlayerCurUnit())
      return
    }

    useDecorator(decor, decorData.decoratorUnit, decorData.decoratorSlot)
  }

  function onGotoCollection() {
    openCollectionsWnd({ selectedDecoratorId = getCurDecal()?.id })
  }

  function onToggleFav() {
    let decal = getCurDecal()
    ::g_unlocks.toggleFav(decal?.unlockId)
    updateDecalButtons(decal)
  }

  function onSheetChange(_obj)
  {
    let sheet = getCurSheet()
    curFilterType = ""
    foreach(btn in ["btn_top_place", "btn_pagePrev", "btn_pageNext", "checkbox_only_for_bought"])
      this.showSceneBtn(btn, false)

    if (sheet == "Profile")
    {
      showSheetDiv("profile")
      if (!profileInited)
      {
        updateStats()
        profileInited = true
      }
    }
    else if (sheet=="Statistics")
    {
      showSheetDiv("stats")
      fillAirStats()
    }
    else if (sheet == "UnlockDecal")
    {
      showSheetDiv("decals", true)

      let decorCache = ::g_decorator.getCachedDataByType(::g_decorator_type.DECALS)
      let view = { items = [] }
      foreach (categoryId in decorCache.categories) {
        let groups = decorCache.catToGroupNames[categoryId]
        let hasGroups = groups.len() > 1 || groups[0] != "other"
        view.items.append({
          id = categoryId
          itemTag = "campaign_item"
          itemText = $"#decals/category/{categoryId}"
          isCollapsable = hasGroups
        })

        if (hasGroups)  {
          view.items.extend(groups.map(@(groupId) {
            id = $"{categoryId}/{groupId}"
            itemText = $"#decals/group/{groupId}"
          }))
        }
      }

      let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
      let categoriesListObj = this.scene.findObject("decals_group_list")
      this.guiScene.replaceContentFromText(categoriesListObj, data, data.len(), this)

      let selCategory = filterGroupName ?? ::loadLocalByAccount("wnd/decalsCategory", "")
      if (isDecalGroup(selCategory))
        openDecalCategory(categoriesListObj, selCategory.split("/")[0])

      let selIdx = view.items.findindex(@(c) c.id == selCategory) ?? 0
      categoriesListObj.setValue(selIdx)

      this.guiScene.applyPendingChanges(false)
      categoriesListObj.getChild(selIdx).scrollToView()
    }
    else if (sheet == "Medal")
    {
      showSheetDiv("medals", true)

      let selCategory = filterCountryName ?? profileCountrySq.value

      local selIdx = 0
      let view = { items = [] }
      foreach (idx, filter in unlockFilters[sheet])
      {
        if (filter == selCategory)
          selIdx = idx
        view.items.append({ text = $"#{filter}" })
      }

      let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
      let pageList = this.scene.findObject("medals_list")
      this.guiScene.replaceContentFromText(pageList, data, data.len(), this)

      let isEqualIdx = selIdx == pageList.getValue()
      pageList.setValue(selIdx)
      if (isEqualIdx) // func on_select don't call if same value is se already
        onPageChange(pageList)
    }
    else if (sheet in unlockFilters)
    {
      if ((!unlockFilters[sheet]) || (unlockFilters[sheet].len() < 1))
      {
        //challange and achievents
        showSheetDiv("unlocks")
        curPage = getPageIdByName(sheet)
        fillUnlocksList()
      }
      else
      {
        showSheetDiv("unlocks", true, true)
        let pageList = this.scene.findObject("pages_list")
        let curCountry = filterCountryName || profileCountrySq.value
        local selIdx = 0

        let view = { items = [] }
        foreach(idx, item in unlockFilters[sheet])
        {
          selIdx = item == curCountry ? idx : selIdx
          view.items.append(
            {
              image = ::get_country_icon(item)
              tooltip = "#" + item
            }
          )
        }

        let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
        this.guiScene.replaceContentFromText(pageList, data, data.len(), this)  // fill countries listbox
        pageList.setValue(selIdx)
        if (selIdx <= 0)
          onPageChange(null)
      }
    }
    else
      showSheetDiv("")

    updateButtons()
  }

  function getPageIdByName(name)
  {
    let start = name.indexof("Unlock")
    if (start!=null)
      return name.slice(start+6)
    return name
  }

  function showSheetDiv(name, pages = false, subPages = false)
  {
    foreach(div in ["profile", "unlocks", "stats", "medals", "decals"])
    {
      let show = div == name
      let divObj = this.scene.findObject(div + "-container")
      if (checkObj(divObj))
      {
        divObj.show(show)
        divObj.enable(show)
        if (show)
          this.updateDifficultySwitch(divObj)
      }
    }
    this.showSceneBtn("pages_list", pages)
    this.showSceneBtn("unit_type_list", subPages)
  }

  function onDecalCategorySelect(listObj) {
    let categoryId = listObj.getChild(listObj.getValue()).id
    openDecalCategory(listObj, categoryId)
    ::saveLocalByAccount("wnd/decalsCategory", categoryId)
    fillDecalsList()
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
    if (isCollapsable) {
      this.guiScene.replaceContentFromText(decalsListObj, "", 0, null)
      onDecalSelect()
      return
    }

    let [categoryId, groupId = "other"] = categoryObj.id.split("/")
    let markup = getDecalsMarkup(categoryId, groupId)
    this.guiScene.replaceContentFromText(decalsListObj, markup, markup.len(), this)

    if (initDecalId != "") {
      let decalIdx = findChildIndex(decalsListObj, @(c) c.id == initDecalId)
      initDecalId = ""
      decalsListObj.setValue(decalIdx != -1 ? decalIdx : 0)
      return
    }

    decalsListObj.setValue(0)
  }

  isDecalGroup = @(categoryId) categoryId.indexof("/") != null

  function openDecalCategory(listObj, categoryId) {
    if (isDecalGroup(categoryId))
      return

    local visible = false
    let total = listObj.childrenCount()
    for (local i = 0; i < total; ++i) {
      let categoryObj = listObj.getChild(i)
      if (isDecalGroup(categoryObj.id)) {
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
    let decal = getCurDecal()
    updateDecalInfo(decal)
    updateDecalButtons(decal)
  }

  function updateDecalInfo(decor) {
    let infoObj = this.showSceneBtn("decal_info", decor != null)
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
      ? ::build_unlock_desc(::build_conditions_config(decor.unlockBlk))
      : null

    let progressObj = infoObj.findObject("decalProgress")
    if (cfg != null) {
      let progressData = cfg.getProgressBarData()
      progressObj.show(progressData.show)
      if (progressData.show)
        progressObj.setValue(progressData.value)
    } else
      progressObj.show(false)

    infoObj.findObject("decalMainCond").setValue(getUnlockMainCondDescByCfg(cfg))
    infoObj.findObject("decalMultDecs").setValue(getUnlockMultDescByCfg(cfg))
    infoObj.findObject("decalConds").setValue(getUnlockCondsDescByCfg(cfg))
    infoObj.findObject("decalPrice").setValue(getDecalObtainInfo(decor))
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

    if (::ItemsManager.canGetDecoratorFromTrophy(decor))
      return loc("mainmenu/itemCanBeReceived")

    return ""
  }

  function getCurDecal() {
    if (getCurSheet() != "UnlockDecal")
      return null

    let listObj = this.scene.findObject("decals_zone")
    if (!listObj?.isValid())
      return null

    let idx = listObj.getValue()
    if (idx == -1)
      return null

    let decalId = listObj.getChild(idx).id
    return ::g_decorator.getDecorator(decalId, ::g_decorator_type.DECALS)
  }

  function onPageChange(_obj)
  {
    local pageIdx = 0
    let sheet = getCurSheet()
    if (!(sheet in unlockFilters) || !unlockFilters[sheet])
      return

    if(sheet=="Medal")
      pageIdx = this.scene.findObject("medals_list").getValue()
    else
      pageIdx = this.scene.findObject("pages_list").getValue()

    if (pageIdx < 0 || pageIdx >= unlockFilters[sheet].len())
      return

    let filter = unlockFilters[sheet][pageIdx]
    curPage = ("page" in filter)? filter.page : getPageIdByName(sheet)

    curFilterType = getTblValue(sheet, filterTable, "")

    if (curFilterType != "")
      curFilter = filter

    if (getCurSheet() == "UnlockSkin")
      refreshUnitTypeControl()
    else
      fillUnlocksList()
  }

  function onSubPageChange(_obj = null)
  {
    let subSwitch = this.getObj("unit_type_list")
    if (subSwitch?.isValid())
    {
      let value = subSwitch.getValue()
      let unitType = unitTypes.getByEsUnitType(value)
      curSubFilter = unitType.esUnitType
      filterUnitTag = unitType.tag
      refreshOwnUnitControl(value)
    }
    fillUnlocksList()
  }

  function onOnlyForBoughtCheck(_obj)
  {
    onSubPageChange()
  }

  function refreshUnitTypeControl()
  {
    let unitypeListObj = this.scene.findObject("unit_type_list")
    if ( ! checkObj(unitypeListObj))
      return

    if ( ! unitypeListObj.childrenCount())
    {
      local filterUnitType = unitTypes.getByTag(filterUnitTag)
      if (!filterUnitType.isAvailable())
        filterUnitType = unitTypes.getByEsUnitType(::get_es_unit_type(getPlayerCurUnit()))

      let view = { items = [] }
      foreach(unitType in unitTypes.types)
        if (unitType.isAvailable())
          view.items.append(
            {
              image = unitType.testFlightIcon
              tooltip = unitType.getArmyLocName()
              selected = filterUnitType == unitType
            }
          )

      let data = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
      this.guiScene.replaceContentFromText(unitypeListObj, data, data.len(), this)
    }

    local indexForSelection = -1
    let previousSelectedIndex = unitypeListObj.getValue()
    let total = unitypeListObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      let obj = unitypeListObj.getChild(i)
      let unitType = unitTypes.getByEsUnitType(i)
      let isVisible = getSkinsCache(curFilter, unitType.esUnitType, OwnUnitsType.ALL).len() > 0
      if (isVisible && (indexForSelection == -1 || previousSelectedIndex == i))
        indexForSelection = i;
      obj.enable(isVisible)
      obj.show(isVisible)
    }

    refreshOwnUnitControl(indexForSelection)

    if (indexForSelection > -1)
      unitypeListObj.setValue(indexForSelection)

    onSubPageChange(unitypeListObj)
  }

  function recacheSkins()
  {
    skinsCache = {}
    foreach(skinName, decorator in ::g_decorator.getCachedDecoratorsListByType(::g_decorator_type.SKINS))
    {
      let unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
      if (!unit)
        continue

      if ( ! unit.isVisibleInShop())
        continue

      if (!decorator || !decorator.isVisible())
        continue

      let unitType = ::get_es_unit_type(unit)
      let unitCountry = ::getUnitCountry(unit)

      if ( ! (unitCountry in skinsCache))
        skinsCache[unitCountry] <- {}
      if ( ! (unitType in skinsCache[unitCountry]))
        skinsCache[unitCountry][unitType] <- {}

      if ( ! (OwnUnitsType.ALL in skinsCache[unitCountry][unitType]))
        skinsCache[unitCountry][unitType][OwnUnitsType.ALL] <- []
      skinsCache[unitCountry][unitType][OwnUnitsType.ALL].append(decorator)

      if( ! unit.isBought())
        continue

      if ( ! (OwnUnitsType.BOUGHT in skinsCache[unitCountry][unitType]))
              skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT] <- []
      skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT].append(decorator)
    }
  }

  function getSkinsCache(country, unitType, ownType)
  {
    if ( ! skinsCache)
      recacheSkins()
    return skinsCache?[country][unitType][ownType] ?? []
  }

  function getCurrentOwnType()
  {
    let ownSwitch = this.scene.findObject("checkbox_only_for_bought")
    let ownType = ( ! checkObj(ownSwitch) || ! ownSwitch.getValue()) ? OwnUnitsType.ALL : OwnUnitsType.BOUGHT
    return ownType
  }

  function refreshOwnUnitControl(unitType)
  {
    let ownSwitch = this.scene.findObject("checkbox_only_for_bought")
    local tooltip = loc("profile/only_for_bought/hint")
    local enabled = true
    if(getSkinsCache(curFilter, unitType, OwnUnitsType.BOUGHT).len() < 1)
    {
      if(ownSwitch.getValue() == true)
        ownSwitch.setValue(false)
      tooltip = loc("profile/only_for_bought_disabled/hint")
      enabled = false
    }
    ownSwitch.tooltip = tooltip
    ownSwitch.enable(enabled)
    ownSwitch.show(true)
  }

  function fillUnlocksList()
  {
    isPageFilling = true

    this.guiScene.setUpdatesEnabled(false, false)
    local data = ""
    local curIndex = 0
    let lowerCurPage = curPage.tolower()
    let pageTypeId = ::get_unlock_type(lowerCurPage)
    let itemSelectFunc = pageTypeId == UNLOCKABLE_MEDAL ? onMedalSelect : null
    let containerObjId = pageTypeId == UNLOCKABLE_MEDAL ? "medals_zone" : "unlocks_group_list"
    unlocksTree = {}

    if (pageTypeId == UNLOCKABLE_SKIN)
    {
      let itemsView = getSkinsView()
      data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", { items = itemsView })
      let skinId = initSkinId
      curIndex = itemsView.findindex(@(p) p.id == skinId) ?? 0
    }
    else
    {
      let view = { items = [] }
      view.items = generateItems(pageTypeId)
      data = ::handyman.renderCached("%gui/commonParts/imgFrame", view)
    }

    let unlocksObj = this.scene.findObject(containerObjId)

    let isAchievementPage = pageTypeId == UNLOCKABLE_ACHIEVEMENT
    if (isAchievementPage && curAchievementGroupName == "")
      curAchievementGroupName = curUnlockId == ""
        ? findGroupName(@(g) g.len() > 0)
        : findGroupName((@(g) g.contains(curUnlockId)).bindenv(this))

    let ediff = getShopDiffCode()

    let view = { items = [] }
    foreach (chapterName, chapterItem in unlocksTree)
    {
      if (isAchievementPage && chapterName == curAchievementGroupName)
        curIndex = view.items.len()

      let chapterSeenIds = getUnlockIds(ediff).filter(@(u) chapterItem.rootItems.contains(u)
        || chapterItem.groups.findindex(@(g) g.contains(u)) != null)

      view.items.append({
        itemTag = "campaign_item"
        id = chapterName
        itemText = "#unlocks/chapter/" + chapterName
        isCollapsable = chapterItem.groups.len() > 0
        unseenIcon = chapterSeenIds.len() > 0
          ? bhvUnseen.makeConfigStr(seenList.id, chapterSeenIds)
          : null
      })

      if (chapterItem.groups.len() > 0)
        foreach (groupName, groupItem in chapterItem.groups)
        {
          let id = chapterName + "/" + groupName
          if (isAchievementPage && id == curAchievementGroupName)
            curIndex = view.items.len()

          let groupSeenIds = getUnlockIds(ediff).filter(@(u) groupItem.contains(u))

          view.items.append({
            id = id
            itemText = chapterItem.rootItems.indexof(groupName) != null ? $"#{groupName}/name" : $"#unlocks/group/{groupName}"
            unseenIcon = groupSeenIds.len() > 0
              ? bhvUnseen.makeConfigStr(seenList.id, groupSeenIds)
              : null
          })
        }
    }
    data += ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
    this.guiScene.replaceContentFromText(unlocksObj, data, data.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    if (pageTypeId == UNLOCKABLE_MEDAL)
      curIndex = selMedalIdx?[curFilter] ?? 0

    collapse(curAchievementGroupName != "" ? curAchievementGroupName : null)

    let total = unlocksObj.childrenCount()
    curIndex = total ? clamp(curIndex, 0, total - 1) : -1
    unlocksObj.setValue(curIndex)

    itemSelectFunc?(unlocksObj)

    isPageFilling = false
    updateFavoritesCheckboxesInList()
  }

  function getSkinsView()
  {
    let itemsView = []
    let comma = loc("ui/comma")
    foreach (decorator in getSkinsCache(curFilter, curSubFilter, getCurrentOwnType()))
    {
      let unitId = ::g_unlocks.getPlaneBySkinId(decorator.id)

      itemsView.append({
        id = decorator.id
        itemText = comma.concat(::getUnitName(unitId), decorator.getName())
        itemIcon = decorator.isUnlocked() ? "#ui/gameuiskin#unlocked.svg" : "#ui/gameuiskin#locked.svg"
      })
    }
    return itemsView.sort(@(a, b) a.itemText <=> b.itemText)
  }

  function findGroupName(func) {
    foreach (chapterName, chapter in unlocksTree) {
      if (chapter.rootItems.findindex(func) != null)
        return chapterName

      let groupId = chapter.groups.findindex(func)
      if (groupId != null)
        return $"{chapterName}/{groupId}"
    }
    return ""
  }

  function generateItems(pageTypeId)
  {
    let items = []
    let lowerCurPage = curPage.tolower()
    let isCustomMenuTab = lowerCurPage in customMenuTabs
    let isUnlockTree = isCustomMenuTab || pageTypeId == -1 || pageTypeId == UNLOCKABLE_ACHIEVEMENT
    local chapter = ""
    local group = ""

    foreach(_idx, cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      let name = cb.getStr("id", "")
      let unlockType = cb?.type ?? ""
      let unlockTypeId = ::get_unlock_type(unlockType)
      let isForceVisibleInTree = cb?.isForceVisibleInTree ?? false
      if (unlockTypeId != pageTypeId
          && (!isUnlockTree || !isInArray(unlockTypeId, unlockTypesToShow))
          && !isForceVisibleInTree)
        continue
      if (isUnlockTree && cb?.isRevenueShare)
        continue
      if (!::is_unlock_visible(cb))
        continue
      if (cb?.showAsBattleTask || ::BattleTasks.isBattleTask(cb))
        continue

      if (isCustomMenuTab)
      {
        if (!cb?.customMenuTab || cb?.customMenuTab.tolower() != lowerCurPage)
          continue
      }
      else if (cb?.customMenuTab)
        continue

      if (curFilterType == "country" && cb.getStr("country","") != curFilter)
        continue

      if (isUnlockTree)
      {
        let newChapter = cb.getStr("chapter","")
        let newGroup = cb.getStr("group","")
        if (newChapter != "")
        {
          chapter = newChapter
          group = newGroup
        }
        if(newGroup != "")
          group = newGroup
        if(!(chapter in unlocksTree))
          unlocksTree[chapter] <- {rootItems = [], groups = {}}
        if(group != "" && !(group in unlocksTree[chapter].groups))
          unlocksTree[chapter].groups[group] <- []
        if (group == "")
          unlocksTree[chapter].rootItems.append(name)
        else
          unlocksTree[chapter].groups[group].append(name)
        continue
      }

      if (pageTypeId == UNLOCKABLE_MEDAL)
        items.append({
          id = name
          tag = "imgSelectable"
          unlocked = ::is_unlocked_scripted(unlockTypeId, name)
          image = ::get_image_for_unlockable_medal(name)
          imgClass = "smallMedals"
          focusBorder = true
        })
    }
    return items;
  }

  function getSkinsUnitType(skinName)
  {
    let unit = getUnitBySkin(skinName)
    if( ! unit)
        return ES_UNIT_TYPE_INVALID
    return ::get_es_unit_type(unit)
  }

  function getUnitBySkin(skinName)
  {
    return ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
  }

  function getDecalsMarkup(categoryId, groupId)
  {
    let decorCache = ::g_decorator.getCachedDataByType(::g_decorator_type.DECALS)
    let decorators = decorCache.catToGroups?[categoryId][groupId]
    if (!decorators || decorators.len() == 0)
      return ""

    let view = {
      items = decorators.map(@(decorator) {
        id = decorator.id
        tooltipId = ::g_tooltip.getIdDecorator(decorator.id, decorator.decoratorType.unlockedItemType)
        unlocked = true
        tag = "imgSelectable"
        image = decorator.decoratorType.getImage(decorator)
        imgRatio = decorator.decoratorType.getRatio(decorator)
        statusLock = decorator.isUnlocked() ? null : "achievement"
      })
    }
    return ::handyman.renderCached("%gui/commonParts/imgFrame", view)
  }

  function checkSkinVehicle(unitName)
  {
    let unit = ::getAircraftByName(unitName)
    if (unit == null)
      return false
    if (!hasFeature("Tanks") && unit?.isTank())
      return false
    return unit.isVisibleInShop()
  }

  function collapse(itemName = null)
  {
    let listObj = this.scene.findObject("unlocks_group_list")
    if (!listObj || !unlocksTree || unlocksTree.len() == 0)
      return

    let chapterRegexp = regexp2("/[^\\s]+")
    let chapterName = itemName && chapterRegexp.replace("", itemName)
    uncollapsedChapterName = chapterName?
      (chapterName == uncollapsedChapterName)? null : chapterName
      : uncollapsedChapterName
    local newValue = -1

    this.guiScene.setUpdatesEnabled(false, false)
    let total = listObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      let obj = listObj.getChild(i)
      let iName = obj?.id
      let isUncollapsedChapter = iName == uncollapsedChapterName
      if (iName == (isUncollapsedChapter ? curAchievementGroupName : chapterName))
        newValue = i

      if (iName in unlocksTree) //chapter
      {
        obj.collapsed = isUncollapsedChapter? "no" : "yes"
        continue
      }

      let iChapter = iName && chapterRegexp.replace("", iName)
      let visible = iChapter == uncollapsedChapterName
      obj.enable(visible)
      obj.show(visible)
    }
    this.guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      listObj.setValue(newValue)
  }

  function onCollapse(obj)
  {
    if (!obj) return
    let id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
    {
      collapse(id.slice(4))
      let listBoxObj = this.scene.findObject("unlocks_group_list")
      let listItemCount = listBoxObj.childrenCount()
      for(local i = 0; i < listItemCount; i++)
      {
        let listItemId = listBoxObj.getChild(i)?.id
        if(listItemId == id.slice(4))
        {
          listBoxObj.setValue(i)
          break
        }
      }
    }
  }

  function onCodeAppClick(_obj)
  {
    openUrl(loc("url/2step/codeApp"))
  }

  function onGroupCollapse(obj)
  {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    collapse(obj.getChild(value).id)
  }

  function openCollapsedGroup(group, name)
  {
    collapse(group)
    let reqBlockName = group + (name? ("/" + name) : "")
    let listBoxObj = this.scene.findObject("unlocks_group_list")
    if (!checkObj(listBoxObj))
      return

    let listItemCount = listBoxObj.childrenCount()
    for(local i = 0; i < listItemCount; i++)
    {
      let listItemId = listBoxObj.getChild(i).id
      if(reqBlockName == listItemId)
        return listBoxObj.setValue(i)
    }
  }

  function getSkinCountry(skinName)
  {
    let len0 = skinName.indexof("/")
    if (len0)
      return ::getShopCountry(skinName.slice(0, len0))
    return ""
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

  function fillSkinDescr(name) {
    let unitName = ::g_unlocks.getPlaneBySkinId(name)
    let unitNameLoc = (unitName != "") ? ::getUnitName(unitName) : ""
    let unlockBlk = ::g_unlocks.getUnlockById(name)
    let config = unlockBlk ? ::build_conditions_config(unlockBlk) : null
    let progressData = config?.getProgressBarData()
    let canAddFav = !!unlockBlk
    let decorator = ::g_decorator.getDecoratorById(name)

    let skinView = {
      unitName = unitNameLoc
      skinName = decorator.getName()

      image = config?.image ?? ::g_decorator_type.SKINS.getImage(decorator)
      ratio = config?.imgRatio ?? ::g_decorator_type.SKINS.getRatio(decorator)
      status = decorator.isUnlocked() ? "unlocked" : "locked"

      skinDesc = getSkinDesc(decorator)
      unlockProgress = progressData?.value
      hasProgress = progressData?.show
      skinPrice = decorator.getCostText()
      mainCond = getUnlockMainCondDescByCfg(config)
      multDesc = getUnlockMultDescByCfg(config)
      conds = getUnlockCondsDescByCfg(config)
      conditions = getSubUnlocksView(config)
      canAddFav
    }

    this.guiScene.setUpdatesEnabled(false, false)
    let markUpData = ::handyman.renderCached("%gui/profile/profileSkins", skinView)
    let objDesc = this.showSceneBtn("item_desc", true)
    this.guiScene.replaceContentFromText(objDesc, markUpData, markUpData.len(), this)

    if (canAddFav)
      ::g_unlock_view.fillUnlockFav(name, objDesc)

    this.showSceneBtn("unlocks_list", false)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  unlockToFavorites = @(obj) ::g_unlocks.unlockToFavorites(obj,
    Callback(updateFavoritesCheckboxesInList, this))

  function updateFavoritesCheckboxesInList()
  {
    if (isPageFilling)
      return

    let canAddFav = ::g_unlocks.canAddFavorite()
    foreach (unlockId in getCurUnlockList())
    {
      let unlockObj = this.scene.findObject(getUnlockBlockId(unlockId))
      if (!checkObj(unlockObj))
        continue

      let cbObj = unlockObj.findObject("checkbox_favorites")
      if (checkObj(cbObj))
        cbObj.inactiveColor = (canAddFav || (unlockId in ::g_unlocks.getFavoriteUnlocks())) ? "no" : "yes"
    }
  }

  function unlockToFavoritesByActivateItem(obj)
  {
    let childrenCount = obj.childrenCount()
    let index = obj.getValue()
    if (index < 0 || index >= childrenCount)
      return

    let checkBoxObj = obj.getChild(index).findObject("checkbox_favorites")
    if (!checkObj(checkBoxObj))
      return

    checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  function onBuyUnlock(obj)
  {
    let unlockId = getTblValue("unlockId", obj)
    if (::u.isEmpty(unlockId))
      return

    let cost = ::get_unlock_cost(unlockId)
    this.msgBox("question_buy_unlock",
      ::warningIfGold(
        loc("onlineShop/needMoneyQuestion",
          { purchase = colorize("unlockHeaderColor", getUnlockNameText(-1, unlockId)),
            cost = cost.getTextAccordingToBalance()
          }),
        cost),
      [
        ["ok", @() ::g_unlocks.buyUnlock(unlockId,
            Callback(@() updateUnlockBlock(unlockId), this),
            Callback(@() onUnlockGroupSelect(null), this))
        ],
        ["cancel", @() null]
      ], "cancel")
  }

  function updateUnlockBlock(unlockData)
  {
    local unlock = unlockData
    if (::u.isString(unlockData))
      unlock = ::g_unlocks.getUnlockById(unlockData)

    let unlockObj = this.scene.findObject(getUnlockBlockId(unlock.id))
    if (checkObj(unlockObj))
      fillUnlockInfo(unlock, unlockObj)
  }

  function showUnlockPrizes(obj) {
    let trophy = ::ItemsManager.findItemById(obj.trophyId)
    let content = trophy.getContent()
      .map(@(i) ::buildTableFromBlk(i))
      .sort(::trophyReward.rewardsSortComparator)

    ::gui_start_open_trophy_rewards_list({ rewardsArray = content })
  }

  function showUnlockUnits(obj) {
    let unlockBlk = ::g_unlocks.getUnlockById(obj.unlockId)
    let allUnits = getUnitListByUnlockId(obj.unlockId).filter(@(u) u.isVisibleInShop())

    let unlockCfg = ::build_conditions_config(unlockBlk)
    shopSearchWnd.open(null, Callback(@(u) showUnitInShop(u), this), getShopDiffCode, {
      units = allUnits
      wndTitle = loc("mainmenu/showVehiclesTitle", {
        taskName = ::g_unlock_view.getUnlockTitle(unlockCfg)
      })
    })
  }

  function showUnitInShop(unitName) {
    if (!unitName)
      return

    ::broadcastEvent("ShowUnitInShop", { unitName })
    this.goBack()
  }

  function fillUnlockInfo(unlockBlk, unlockObj)
  {
    let itemData = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(itemData)
    unlockObj.show(true)
    unlockObj.enable(true)

    ::g_unlock_view.fillUnlockConditions(itemData, unlockObj, this)
    ::g_unlock_view.fillUnlockProgressBar(itemData, unlockObj)
    ::g_unlock_view.fillUnlockDescription(itemData, unlockObj)
    ::g_unlock_view.fillUnlockImage(itemData, unlockObj)
    ::g_unlock_view.fillReward(itemData, unlockObj)
    ::g_unlock_view.fillStages(itemData, unlockObj, this)
    ::g_unlock_view.fillUnlockTitle(itemData, unlockObj)
    ::g_unlock_view.fillUnlockFav(itemData.id, unlockObj)
    ::g_unlock_view.fillUnlockPurchaseButton(itemData, unlockObj)
    ::g_unlock_view.updateLockStatus(itemData, unlockObj)
  }

  function printUnlocksList(unlocksList)
  {
    let achievaAmount = unlocksList.len()
    let unlocksListObj = this.showSceneBtn("unlocks_list", true)
    this.showSceneBtn("item_desc", false)
    local blockAmount = unlocksListObj.childrenCount()

    this.guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievaAmount)
    {
      let unlockItemBlk = "%gui/profile/unlockItem.blk"
      for(; blockAmount < achievaAmount; blockAmount++)
        this.guiScene.createElementByObject(unlocksListObj, unlockItemBlk, "expandable", this)
    }
    else if (blockAmount > achievaAmount)
    {
      for(; blockAmount > achievaAmount; blockAmount--)
      {
        unlocksListObj.getChild(blockAmount - 1).show(false)
        unlocksListObj.getChild(blockAmount - 1).enable(false)
      }
    }

    local currentItemNum = 0
    local selIdx = 0
    foreach(unlock in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      if (unlock?.id == null) {
        let unlockConfigString = toString(unlock, 2) // warning disable: -declared-never-used
        ::script_net_assert_once("missing id in unlock after cashed", "ProfileHandler: Missing id in unlock after cashed")
        continue
      }

      if (!isInArray(unlock.id, unlocksList))
        continue

      let unlockObj = unlocksListObj.getChild(currentItemNum)
      unlockObj.id = getUnlockBlockId(unlock.id)
      unlockObj.holderId = unlock.id
      fillUnlockInfo(unlock, unlockObj)

      if (curUnlockId == unlock.id)
        selIdx = currentItemNum

      currentItemNum++
    }

    this.guiScene.setUpdatesEnabled(true, true)

    if (unlocksListObj.childrenCount() > 0)
      unlocksListObj.setValue(selIdx)

    seenList.markSeen(getUnlockIds(::get_current_ediff()).filter(@(u) unlocksList.contains(u)))
  }

  function getUnlockBlockId(unlockId)
  {
    return unlockId + "_block"
  }

  function onMedalSelect(obj)
  {
    if (!checkObj(obj))
      return

    let idx = obj.getValue()
    let itemObj = idx >= 0 && idx < obj.childrenCount() ? obj.getChild(idx) : null
    let name = checkObj(itemObj) && itemObj?.id
    let unlock = name && ::g_unlocks.getUnlockById(name)
    if (!unlock)
      return

    let containerObj = this.scene.findObject("medals_info")
    let descObj = checkObj(containerObj) && containerObj.findObject("medals_desc")
    if (!checkObj(descObj))
      return

    if (!isPageFilling)
      selMedalIdx[curFilter] <- idx

    let config = ::build_unlock_desc(::build_conditions_config(unlock))
    let rewardText = ::get_unlock_reward(name)
    let progressData = config.getProgressBarData()

    let view = {
      title = loc(name + "/name")
      image = ::get_image_for_unlockable_medal(name, true)
      unlockProgress = progressData.value
      hasProgress = progressData.show
      mainCond = getUnlockMainCondDescByCfg(config)
      multDesc = getUnlockMultDescByCfg(config)
      conds = getUnlockCondsDescByCfg(config)
      rewardText = rewardText != "" ? rewardText : null
    }

    let markup = ::handyman.renderCached("%gui/profile/profileMedal", view)
    this.guiScene.setUpdatesEnabled(false, false)
    this.guiScene.replaceContentFromText(descObj, markup, markup.len(), this)
    ::g_unlock_view.fillUnlockFav(name, containerObj)
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function onUnlockSelect(obj)
  {
    if (obj?.isValid())
      curUnlockId = getSelectedChild(obj)?.holderId ?? ""
  }

  function onUnlockGroupSelect(_obj) {
    let list = this.scene.findObject("unlocks_group_list")
    let index = list.getValue()
    local unlocksList = []
    if ((index >= 0) && (index < list.childrenCount()))
    {
      let curObj = list.getChild(index)
      if (curPage.tolower() == "skin")
        fillSkinDescr(curObj.id)
      else
      {
        let id = curObj.id
        let isGroup = (id in unlocksTree)
        if(isGroup)
          unlocksList = unlocksTree[id].rootItems
        else
          foreach(chapterName, chapterItem in unlocksTree)
            if (chapterName.len() + 1 < id.len()
                && id.slice(0, chapterName.len()) == chapterName
                && id.slice(chapterName.len() + 1) in chapterItem.groups)
            {
              unlocksList = chapterItem.groups[id.slice(chapterName.len() + 1)]
              break
            }
        printUnlocksList(unlocksList)
        if (curPage == "Achievement")
        {
          curAchievementGroupName = id
          if (isGroup && id != uncollapsedChapterName)
            onGroupCollapse(list)
        }
      }
    }
  }

  function onSkinPreview(_obj)
  {
    let list = this.scene.findObject("unlocks_group_list")
    let index = list.getValue()
    if ((index < 0) || (index >= list.childrenCount()))
      return

    let skinId = list.getChild(index).id
    let decorator = ::g_decorator.getDecoratorById(skinId)
    initSkinId = skinId
    if (decorator && canStartPreviewScene(true, true))
      this.guiScene.performDelayed(this, @() decorator.doPreview())
  }

  function getHandlerRestoreData() {
    let data = {
     openData = {
        initialSheet = getCurSheet()
        initSkinId = initSkinId
        initDecalId = getCurDecal()?.id ?? ""
        filterCountryName = curFilter
        filterUnitTag = filterUnitTag
      }
    }
    return data
  }

  function onEventBeforeStartShowroom(_p) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getCurSheet()
  {
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

        for(local pm=0; pm < 2; pm++)  //players
          if (mode == pm || mode < 0)

            if (fm_idx!=null)
              value += func(idx, fm_idx, pm)
            else
              value += func(idx, pm)

    return value
  }

  function getStatRowData(name, func, mode, fm_idx=null, timeFormat = false)
  {
    let row = [{ text = name, tdalign = "left"}]
    for (local diff=0; diff < 3; diff++)
    {
      local value = 0
      if (fm_idx==null || fm_idx >= 0)
        value = calcStat(func, diff, mode, fm_idx)
      else
        for (local i = 0; i < 3; i++)
          value += calcStat(func, diff, mode, i)

      let s = timeFormat ? time.secondsToString(value) : value
      let tooltip = ["#mainmenu/arcadeInstantAction", "#mainmenu/instantAction", "#mainmenu/fullRealInstantAction"][diff]
      row.append({ id = diff.tostring(), text = s.tostring(), tooltip = tooltip})
    }
    return ::buildTableRowNoPad("", row)
  }

  function updateStats()
  {
    let myStats = ::my_stats.getStats()
    if (!myStats || !checkObj(this.scene))
      return

    fillProfileStats(myStats)
  }

  function openChooseTitleWnd(_obj)
  {
    ::gui_handlers.ChooseTitle.open()
  }

  function openProfileTab(tab, selectedBlock)
  {
    let obj = this.scene.findObject("profile_sheet_list")
    if(checkObj(obj))
    {
      let num = ::find_in_array(sheetsList, tab)
      if(num < 0)
        return
      obj.setValue(num)
      openCollapsedGroup(selectedBlock, null)
    }
  }

  function fillProfileStats(stats)
  {
    this.fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles")
    if ("uid" in stats && stats.uid != ::my_user_id_str)
      externalIDsService.reqPlayerExternalIDsByUserId(stats.uid)
    this.fillClanInfo(::get_profile_info())
    this.fillModeListBox(this.scene.findObject("profile-container"), this.curMode)
    ::fill_gamer_card(::get_profile_info(), "profile-", this.scene)
    this.fillAwardsBlock(stats)
    this.fillShortCountryStats(stats)
    this.scene.findObject("profile_loading").show(false)
  }

  function onProfileStatsModeChange(obj)
  {
    if (!checkObj(this.scene))
      return
    let myStats = ::my_stats.getStats()
    if (!myStats)
      return

    this.curMode = obj.getValue()

    ::set_current_wnd_difficulty(this.curMode)
    this.updateCurrentStatsMode(this.curMode)
    fillProfileSummary(this.scene.findObject("stats_table"), myStats.summary, this.curMode)
    this.fillLeaderboard()
  }

  function onUpdate(_obj, _dt)
  {
    if (pending_logout && ::is_app_active() && !::steam_is_overlay_active() && !::is_builtin_browser_active())
    {
      pending_logout = false
      this.guiScene.performDelayed(this, function() {
        startLogout()
      })
    }
  }

  function onChangeName()
  {
    local textLocId = "mainmenu/questionChangeName"
    local afterOkFunc = @() this.guiScene.performDelayed(this, function() { pending_logout = true})

    if (::steam_is_running() && !hasFeature("AllowSteamAccountLinking"))
    {
      textLocId = "mainmenu/questionChangeNameSteam"
      afterOkFunc = @() null
    }

    this.msgBox("question_change_name", loc(textLocId),
      [
        ["ok", function() {
          openUrl(loc("url/changeName"), false, false, "profile_page")
          afterOkFunc()
        }],
        ["cancel", function() { }]
      ], "cancel")
  }

  function onChangeAccount()
  {
    this.msgBox("question_change_name", loc("mainmenu/questionChangePlayer"),
      [
        ["yes", function() {
          ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, null)
          startLogout()
        }],
        ["no", @() null ]
      ], "no", { cancel_fn = @() null })
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function onChangePilotIcon() {
    avatars.openChangePilotIconWnd(onIconChoosen, this)
  }

  function openViralAcquisitionWnd()
  {
    showViralAcquisitionWnd()
  }

  function onIconChoosen(option)
  {
    let value = ::get_option(::USEROPT_PILOT).value
    if (value == option.idx)
      return

    ::set_option(::USEROPT_PILOT, option.idx)
    ::save_profile(false)

    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("profile-icon")
    if (obj)
      obj.setValue(::get_profile_info().icon)

    ::broadcastEvent(profileEvent.AVATAR_CHANGED)
  }

  function onEventMyStatsUpdated(_params)
  {
    if (getCurSheet() == "Statistics")
      fillAirStats()
    if (getCurSheet() == "Profile")
      updateStats()
  }

  function onEventClanInfoUpdate(_params)
  {
    this.fillClanInfo(::get_profile_info())
  }

  function initAirStats()
  {
    let myStats = ::my_stats.getStats()
    if (!myStats || !checkObj(this.scene))
      return

    this.initAirStatsScene(myStats.userstat)
  }

  function fillAirStats()
  {
    let myStats = ::my_stats.getStats()
    if (!airStatsInited || !myStats || !myStats.userstat)
      return initAirStats()

    this.fillAirStatsScene(myStats.userstat)
  }

  function getPlayerStats()
  {
    return ::my_stats.getStats()
  }

  function getCurUnlockList()
  {
    let list = this.scene.findObject("unlocks_group_list")
    let index = list.getValue()
    local unlocksList = []
    if ((index < 0) || (index >= list.childrenCount()))
      return unlocksList

    let curObj = list.getChild(index)
    let id = curObj.id
    if(id in unlocksTree)
      unlocksList = unlocksTree[id].rootItems
    else
      foreach(chapterName, chapterItem in unlocksTree)
      {
        let subsectionName = ::g_string.cutPrefix(id, chapterName+"/", null)
        if(!subsectionName)
          continue

        unlocksList = chapterItem?.groups?[subsectionName] ?? []
        if (unlocksList.len()>0)
          return unlocksList
      }
    return unlocksList
  }

  function onGroupCancel(_obj)
  {
    if (::show_console_buttons && getCurSheet() == "UnlockSkin")
      ::move_mouse_on_child_by_value(this.scene.findObject("pages_list"))
    else
      this.goBack()
  }

  function onBindEmail()
  {
    launchEmailRegistration()
    this.doWhenActiveOnce("updateButtons")
  }

  function onEventUnlocksCacheInvalidate(_p)
  {
    let curSheet = getCurSheet()
    if (curSheet == "UnlockAchievement")
      fillUnlocksList()
    else if (curSheet == "UnlockDecal")
      fillDecalsList()
  }

  function onEventUnlockMarkersCacheInvalidate(_) {
    if (getCurSheet() == "UnlockAchievement")
      fillUnlocksList()
  }

  function onEventInventoryUpdate(_p)
  {
    let curSheet = getCurSheet()
    if (curSheet == "UnlockAchievement")
      fillUnlocksList()
    else if (curSheet == "UnlockDecal")
      fillDecalsList()
  }

  function onOpenAchievementsUrl()
  {
    openUrl(loc("url/achievements",
        { appId = APP_ID, name = ::get_profile_info().name}),
      false, false, "profile_page")
  }
}

let openProfileSheetParamsFromPromo = {
  UnlockAchievement = @(p1, p2, ...) {
    uncollapsedChapterName = p2 != ""? p1 : null
    curAchievementGroupName = p1 + (p2 != "" ? ("/" + p2) : "")
  }
  Medal = @(p1, _p2, ...) { filterCountryName = p1 }
  UnlockSkin = @(p1, p2, p3) {
    filterCountryName = p1
    filterUnitTag = p2
    initSkinId = p3
  }
  UnlockDecal = @(p1, _p2, ...) { filterGroupName = p1 }
}

local function openProfileFromPromo(params, sheet = null) {
  sheet = sheet ?? params?[0]
  let launchParams = openProfileSheetParamsFromPromo?[sheet](
    params?[1], params?[2] ?? "", params?[3] ?? "") ?? {}
  launchParams.__update({ initialSheet = sheet })
  ::gui_start_profile(launchParams)
}

addPromoAction("profile", @(_handler, params, _obj) openProfileFromPromo(params))
