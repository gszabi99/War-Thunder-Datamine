let time = require("scripts/time.nut")
let externalIDsService = require("scripts/user/externalIdsService.nut")
let avatars = require("scripts/user/avatars.nut")
let { isMeXBOXPlayer,
        isMePS4Player,
        isPlatformPC,
        isPlatformSony,
        isPlatformXboxOne } = require("scripts/clientState/platform.nut")
let unitTypes = require("scripts/unit/unitTypesList.nut")
let { openUrl } = require("scripts/onlineShop/url.nut")
let { startLogout } = require("scripts/login/logout.nut")
let { canAcquireDecorator, askAcquireDecorator } = require("scripts/customization/decoratorAcquire.nut")
let { getViralAcquisitionDesc, showViralAcquisitionWnd } = require("scripts/user/viralAcquisition.nut")
let { addPromoAction } = require("scripts/promo/promoActions.nut")
let { fillProfileSummary } = require("scripts/user/userInfoStats.nut")
let { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = ::require_native("guiOptions")
let { canStartPreviewScene } = require("scripts/customization/contentPreview.nut")
let { getPlayerCurUnit } = require("scripts/slotbar/playerCurUnit.nut")
let { getSelectedChild } = require("sqDagui/daguiUtil.nut")
let bhvUnseen = require("scripts/seen/bhvUnseen.nut")
let { getUnlockIds, getUnitListByUnlockId } = require("scripts/unlocks/unlockMarkers.nut")
let { getShopDiffCode } = require("scripts/shop/shopDifficulty.nut")
let shopSearchWnd  = require("scripts/shop/shopSearchWnd.nut")
let seenList = require("scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)

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
  if (!::has_feature("Profile"))
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
  statsType = ::ETTI_VALUE_INHISORY
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
    ::UNLOCKABLE_ACHIEVEMENT,
    ::UNLOCKABLE_CHALLENGE,
    ::UNLOCKABLE_TITLE,
    ::UNLOCKABLE_MEDAL,
    ::UNLOCKABLE_DECAL,
    ::UNLOCKABLE_TROPHY,
    ::UNLOCKABLE_TROPHY_PSN,
    ::UNLOCKABLE_TROPHY_XBOXONE,
    ::UNLOCKABLE_TROPHY_STEAM
  ]

  unlocksPages = {
    achievement = ::UNLOCKABLE_ACHIEVEMENT
    skin = ::UNLOCKABLE_SKIN
    decal = ::UNLOCKABLE_DECAL
    challenge = ::UNLOCKABLE_CHALLENGE
    medal = ::UNLOCKABLE_MEDAL
    title = ::UNLOCKABLE_TITLE
  }

  unlocksTree = {}
  skinsCache = null
  uncollapsedChapterName = null
  curAchievementGroupName = ""
  curUnlockId = ""
  filterCountryName = null
  filterUnitTag = ""
  initSkinId = ""
  filterGroupName = null

  unlockFilters = {
    Medal = []
    UnlockAchievement = null
    UnlockChallenge = null
    UnlockSkin = []
    UnlockDecal = []
    /*
    Unlock = [
      {page = "Achievement"}
      {page = "Skin"}
      {page = "Decal"}
    ]
    */
  }

  filterTable = {
    Medal = "country"
    UnlockDecal = "category"
    UnlockSkin = "airCountry"
  }

  function initScreen()
  {
    if (!scene)
      return goBack()

    isOwnStats = true
    scene.findObject("profile_update").setUserData(this)

    //prepare options
    mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

    initStatsParams()
    initSheetsList()
    initTabs()

    unlocksTree = {}

    //fill decals categories
    if ("UnlockDecal" in unlockFilters)
      unlockFilters.UnlockDecal = ::g_decorator.getCachedOrderByType(::g_decorator_type.DECALS)

    //fill skins filters
    if ("UnlockSkin" in unlockFilters)
    {
      let skinCountries = getUnlockFiltersList("skin", function(unlock)
        {
          let country = getSkinCountry(unlock.getStr("id", ""))
          return (country != "")? country : null
        })

      unlockFilters.UnlockSkin = ::u.filter(shopCountriesList, @(c) ::isInArray(c, skinCountries))
    }

    //fill medal filters
    if ("Medal" in unlockFilters)
    {
      let medalCountries = getUnlockFiltersList("medal", @(unlock) unlock?.country)
      unlockFilters.Medal = ::u.filter(shopCountriesList, @(c) ::isInArray(c, medalCountries))
    }

    let bntGetLinkObj = scene.findObject("btn_getLink")
    if (::check_obj(bntGetLinkObj))
      bntGetLinkObj.tooltip = getViralAcquisitionDesc("mainmenu/getLinkDesc")

    initLeaderboardModes()

    onSheetChange(null)
    initShortcuts()
  }

  function initSheetsList()
  {
    customMenuTabs = {}
    sheetsList = clone presetSheetList
    local hasAnyUnlocks = false
    local hasAnyMedals = false //skins and decals tab also have resources without unlocks

    let customCategoryConfig = ::getTblValue("customProfileMenuTab", ::get_gui_regional_blk(), null)
    local tabImage = null
    local tabText = null

    foreach(cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      let unlockType = cb?.type ?? ""
      let unlockTypeId = ::get_unlock_type(unlockType)

      if (!::isInArray(unlockTypeId, unlockTypesToShow))
        continue
      if (!::is_unlock_visible(cb))
        continue

      hasAnyUnlocks = true
      if (unlockTypeId == ::UNLOCKABLE_MEDAL)
        hasAnyMedals = true

      if (cb?.customMenuTab == null)
        continue

      let lowerCaseTab = cb.customMenuTab.tolower()
      if (lowerCaseTab in customMenuTabs)
        continue

      sheetsList.append(lowerCaseTab)
      unlockFilters[lowerCaseTab]  <- null

      let defaultImage = ::format(tabImageNameTemplate, defaultTabImageName)

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
        tabImage = ::format(tabImageNameTemplate, sheet.tolower())
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
    let sheetsListObj = scene.findObject("profile_sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(curSheetIdx)
  }

  function isSheetVisible(sheetName)
  {
    if (sheetName == "Medal")
      return ::has_feature("ProfileMedals")
    return true
  }

  function initShortcuts()
  {
    local obj = scene.findObject("btn_profile_icon")
    if (::checkObj(obj))
      obj.btnName = "X"
    obj = scene.findObject("profile_currentUser_btn_title")
    if (::checkObj(obj))
      obj.btnName = "Y"
    scene.findObject("unseen_titles").setValue(SEEN.TITLES)
    scene.findObject("unseen_avatar").setValue(SEEN.AVATARS)
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

  function updateButtons()
  {
    let sheet = getCurSheet()
    let isProfileOpened = sheet == "Profile"
    let buttonsList = {
      btn_changeAccount = ::isInMenu() && isProfileOpened && !isPlatformSony && !::is_vendor_tencent()
      btn_changeName = ::isInMenu() && isProfileOpened && !isMeXBOXPlayer() && !isMePS4Player() && !::is_vendor_tencent()
      btn_getLink = !::is_in_loading_screen() && isProfileOpened && ::has_feature("Invites")
      btn_codeApp = isPlatformPC && ::has_feature("AllowExternalLink") &&
        !::g_user_utils.haveTag("gjpass") && ::isInMenu() && isProfileOpened &&
          !::is_vendor_tencent()
      btn_ps4Registration = isProfileOpened && isPlatformSony && ::g_user_utils.haveTag("psnlogin")
      btn_SteamRegistration = isProfileOpened && ::steam_is_running() && ::has_feature("AllowSteamAccountLinking") && ::g_user_utils.haveTag("steamlogin")
      btn_xboxRegistration = isProfileOpened && isPlatformXboxOne && ::has_feature("AllowXboxAccountLinking")
      paginator_place = (sheet == "Statistics") && airStatsList && (airStatsList.len() > statsPerPage)
      btn_achievements_url = (sheet == "UnlockAchievement") && ::has_feature("AchievementsUrl")
        && ::has_feature("AllowExternalLink") && !::is_vendor_tencent()
      btn_SkinPreview = ::isInMenu() && sheet == "UnlockSkin"
    }

    ::showBtnTable(scene, buttonsList)
  }

  function onSheetChange(obj)
  {
    let sheet = getCurSheet()
    curFilterType = ""
    foreach(btn in ["btn_top_place", "btn_pagePrev", "btn_pageNext", "checkbox_only_for_bought"])
      showSceneBtn(btn, false)

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
    else if (sheet=="Medal" || sheet=="UnlockDecal")
    {
      let isMedal = sheet=="Medal"
      showSheetDiv(isMedal ? "medals" : "decals", true)

      let selCategory = isMedal
        ? filterCountryName || ::get_profile_country_sq()
        : filterGroupName || ::loadLocalByAccount("wnd/decalsCategory", "")

      local selIdx = 0
      let view = { items = [] }
      foreach (idx, filter in unlockFilters[sheet])
      {
        if (filter == selCategory)
          selIdx = idx
        if (isMedal)
          view.items.append({ text = $"#{filter}"})
        else
          view.items.append({ itemText = $"#decals/category/{filter}" })
      }

      let tplPath = isMedal ? "%gui/commonParts/shopFilter" : "%gui/missions/missionBoxItemsList"
      let data = ::handyman.renderCached(tplPath, view)
      let pageList = scene.findObject($"{isMedal ? "medals" : "decals_group"}_list")
      guiScene.replaceContentFromText(pageList, data, data.len(), this)

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
        let pageList = scene.findObject("pages_list")
        let curCountry = filterCountryName || ::get_profile_country_sq()
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
        guiScene.replaceContentFromText(pageList, data, data.len(), this)  // fill countries listbox
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
      let divObj = scene.findObject(div + "-container")
      if (::checkObj(divObj))
      {
        divObj.show(show)
        divObj.enable(show)
        if (show)
          updateDifficultySwitch(divObj)
      }
    }
    showSceneBtn("pages_list", pages)
    showSceneBtn("unit_type_list", subPages)
  }

  function onPageChange(obj)
  {
    local pageIdx = 0
    let sheet = getCurSheet()
    if (!(sheet in unlockFilters) || !unlockFilters[sheet])
      return

    if(sheet=="Medal")
      pageIdx = scene.findObject("medals_list").getValue()
    else if (sheet=="UnlockDecal")
      pageIdx = scene.findObject("decals_group_list").getValue()
    else
      pageIdx = scene.findObject("pages_list").getValue()

    if (pageIdx < 0 || pageIdx >= unlockFilters[sheet].len())
      return

    let filter = unlockFilters[sheet][pageIdx]
    curPage = ("page" in filter)? filter.page : getPageIdByName(sheet)

    if (sheet == "UnlockDecal")
      ::saveLocalByAccount("wnd/decalsCategory", filter)

    curFilterType = ::getTblValue(sheet, filterTable, "")

    if (curFilterType != "")
      curFilter = filter

    if (getCurSheet() == "UnlockSkin")
      refreshUnitTypeControl()
    else
      fillUnlocksList()
  }

  function onSubPageChange(obj = null)
  {
    let subSwitch = getObj("unit_type_list")
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

  function onOnlyForBoughtCheck(obj)
  {
    onSubPageChange()
  }

  function refreshUnitTypeControl()
  {
    let unitypeListObj = scene.findObject("unit_type_list")
    if ( ! ::check_obj(unitypeListObj))
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
      guiScene.replaceContentFromText(unitypeListObj, data, data.len(), this)
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
    let ownSwitch = scene.findObject("checkbox_only_for_bought")
    let ownType = ( ! ::checkObj(ownSwitch) || ! ownSwitch.getValue()) ? OwnUnitsType.ALL : OwnUnitsType.BOUGHT
    return ownType
  }

  function refreshOwnUnitControl(unitType)
  {
    let ownSwitch = scene.findObject("checkbox_only_for_bought")
    local tooltip = ::loc("profile/only_for_bought/hint")
    local enabled = true
    if(getSkinsCache(curFilter, unitType, OwnUnitsType.BOUGHT).len() < 1)
    {
      if(ownSwitch.getValue() == true)
        ownSwitch.setValue(false)
      tooltip = ::loc("profile/only_for_bought_disabled/hint")
      enabled = false
    }
    ownSwitch.tooltip = tooltip
    ownSwitch.enable(enabled)
    ownSwitch.show(true)
  }

  function fillUnlocksList()
  {
    isPageFilling = true

    guiScene.setUpdatesEnabled(false, false)
    local data = ""
    local curIndex = 0
    let lowerCurPage = curPage.tolower()
    let pageTypeId = ::get_unlock_type(lowerCurPage)
    let itemSelectFunc  = pageTypeId == ::UNLOCKABLE_MEDAL ? onMedalSelect : null
    let containerObjId = pageTypeId == ::UNLOCKABLE_MEDAL ? "medals_zone"
      : pageTypeId == ::UNLOCKABLE_DECAL ? "decals_zone"
      : "unlocks_group_list"
    unlocksTree = {}

    let decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(pageTypeId)
    if (pageTypeId == ::UNLOCKABLE_DECAL)
      data = getDecoratorsMarkup(decoratorType)
    else if (pageTypeId == ::UNLOCKABLE_SKIN)
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

    let unlocksObj = scene.findObject(containerObjId)

    let isAchievementPage = pageTypeId == ::UNLOCKABLE_ACHIEVEMENT
    if (isAchievementPage && curAchievementGroupName == "" && curUnlockId != "")
      curAchievementGroupName = findGroupNameByUnlockId(curUnlockId)

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
    guiScene.replaceContentFromText(unlocksObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    if (pageTypeId == ::UNLOCKABLE_MEDAL)
      curIndex = selMedalIdx?[curFilter] ?? 0

    let total = unlocksObj.childrenCount()
    curIndex = total ? ::clamp(curIndex, 0, total - 1) : -1
    unlocksObj.setValue(curIndex)

    collapse()
    itemSelectFunc?(unlocksObj)

    isPageFilling = false
    updateFavoritesCheckboxesInList()
  }

  function getSkinsView()
  {
    let itemsView = []
    let comma = ::loc("ui/comma")
    foreach (decorator in getSkinsCache(curFilter, curSubFilter, getCurrentOwnType()))
    {
      let unitId = ::g_unlocks.getPlaneBySkinId(decorator.id)

      itemsView.append({
        id = decorator.id
        itemText = comma.concat(::getUnitName(unitId), decorator.getName())
        itemIcon = decorator.isUnlocked() ? "#ui/gameuiskin#unlocked" : "#ui/gameuiskin#locked"
      })
    }
    return itemsView.sort(@(a, b) a.itemText <=> b.itemText)
  }

  function findGroupNameByUnlockId(unlockId) {
    foreach (chapterName, chapter in unlocksTree) {
      if (chapter.rootItems.contains(unlockId))
        return chapterName

      let groupId = chapter.groups.findindex(@(g) g.contains(unlockId))
      if (groupId != null)
        return groupId
    }
    return ""
  }

  function generateItems(pageTypeId)
  {
    let items = []
    let lowerCurPage = curPage.tolower()
    let isCustomMenuTab = lowerCurPage in customMenuTabs
    let isUnlockTree = isCustomMenuTab || pageTypeId == -1 || pageTypeId == ::UNLOCKABLE_ACHIEVEMENT
    local chapter = ""
    local group = ""

    foreach(idx, cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      let name = cb.getStr("id", "")
      let unlockType = cb?.type ?? ""
      let unlockTypeId = ::get_unlock_type(unlockType)
      let isForceVisibleInTree = cb?.isForceVisibleInTree ?? false
      if (unlockTypeId != pageTypeId
          && (!isUnlockTree || !::isInArray(unlockTypeId, unlockTypesToShow))
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

      if (curFilterType == "category")
      {
        let dInfo = ::g_decorator.getCachedDecoratorByUnlockId(name, ::g_decorator_type.DECALS)
        if (!dInfo || dInfo.category != curFilter)
          continue
      }

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

      if (pageTypeId == ::UNLOCKABLE_MEDAL)
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
        return ::ES_UNIT_TYPE_INVALID
    return ::get_es_unit_type(unit)
  }

  function getUnitBySkin(skinName)
  {
    return ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
  }

  function getDecoratorsMarkup(decoratorType)
  {
    let decoratorsList = ::g_decorator.getCachedDecoratorsDataByType(decoratorType)
    let decorators = decoratorsList?[curFilter] ?? []
    let view = {
      items = decorators.map(function(decorator) {
        local text = null
        local status = null
        if (decorator.isUnlocked())
          text = null
        else if (decorator.canBuyUnlock(null))
          text = decorator.getCost()
        else if (decorator.getCouponItemdefId() != null)
          text = ::colorize("currencyGoldColor", ::loc("currency/gc/sign"))
        else if (decorator.lockedByDLC != null)
          status = "noDLC"
        else
          status = "achievement"

        return {
          id = decorator.id
          tooltipId = ::g_tooltip.getIdDecorator(decorator.id, decorator.decoratorType.unlockedItemType)
          unlocked = decorator.isUnlocked()
          image = decorator.decoratorType.getImage(decorator)
          imgRatio = decorator.decoratorType.getRatio(decorator)
          backlight = true
          bottomCenterText = text
          statusLock = status
          onClick = "onDecalClick"
        }
      })
    }
    return ::handyman.renderCached("%gui/commonParts/imgFrame", view)
  }

  function checkSkinVehicle(unitName)
  {
    let unit = ::getAircraftByName(unitName)
    if (unit == null)
      return false
    if (!::has_feature("Tanks") && unit?.isTank())
      return false
    return unit.isVisibleInShop()
  }

  function collapse(itemName = null)
  {
    let listObj = scene.findObject("unlocks_group_list")
    if (!listObj || !unlocksTree || unlocksTree.len() == 0)
      return

    let chapterRegexp = regexp2("/[^\\s]+")
    let chapterName = itemName && chapterRegexp.replace("", itemName)
    uncollapsedChapterName = chapterName?
      (chapterName == uncollapsedChapterName)? null : chapterName
      : uncollapsedChapterName
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
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
    guiScene.setUpdatesEnabled(true, true)

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
      let listBoxObj = scene.findObject("unlocks_group_list")
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

  function onCodeAppClick(obj)
  {
    openUrl(::loc("url/2step/codeApp"))
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
    let listBoxObj = scene.findObject("unlocks_group_list")
    if (!::checkObj(listBoxObj))
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

  function fillSkinDescr(name)
  {
    let objDesc = showSceneBtn("item_desc", true)
    let unlockBlk = ::g_unlocks.getUnlockById(name)
    let decoratorType = ::g_decorator_type.SKINS
    let decorator = ::g_decorator.getDecoratorById(name)
    let isAllowed = decorator.isUnlocked()
    local config = {}

    if (unlockBlk)
      config = ::build_conditions_config(unlockBlk)
    else
    {
      config = ::get_empty_conditions_config()
      config.image = decoratorType.getImage(decorator)
      config.imgRatio = decoratorType.getRatio(decorator)
    }

    let desc = []
    desc.append(decorator.getDesc())
    desc.append(decorator.getTypeDesc())
    desc.append(decorator.getLocParamsDesc())
    desc.append(decorator.getRestrictionsDesc())
    desc.append(decorator.getLocationDesc())
    desc.append(decorator.getTagsDesc())

    let unlockDesc = decorator.getUnlockDesc()
    if (unlockDesc.len())
      desc.append(" ") // for visually distinguish unlock requirements from other info

    desc.append(unlockDesc)
    config.text = ::g_string.implode(desc, "\n")

    let condView = []
    append_condition_item(config, 0, condView, true, isAllowed)

    if ("shortText" in config)
      for(local i=0; i<config.stages.len(); i++)  //stages of challenge
      {
        let stage = config.stages[i]
        if (stage.val != config.maxVal)
        {
          let curValStage = (config.curVal > stage.val)? stage.val : config.curVal
          let isUnlockedStage = curValStage >= stage.val
          append_condition_item({
              text = config.progressText //do not show description for stages
              curVal = curValStage
              maxVal = stage.val
            },
            i+1, condView, false, isUnlockedStage)
        }
      }

    //missions, countries
    let namesLoc = ::UnlockConditions.getLocForBitValues(config.type, config.names)
    let typeOR = ("compareOR" in config) && config.compareOR
    for(local i=0; i < namesLoc.len(); i++)
    {
      let isPartUnlocked = config.curVal & 1 << i
      append_condition_item({
            text = namesLoc[i]
            curVal = 0
            maxVal = 0
          },
          i+1, condView, false, isPartUnlocked, i > 0 && typeOR)
    }

    let unitName = ::g_unlocks.getPlaneBySkinId(name)
    let unitNameLoc = (unitName != "") ? ::getUnitName(unitName) : ""

    let skinView = { skinDescription = [{
      name0 = unitNameLoc
      name = decorator.getName()
      image = config.image
      ratio = config.imgRatio
      status = isAllowed ? "unlocked" : "locked"
      condition = condView
      isUnlock = !!unlockBlk
      price = decorator.getCostText()
    }]}

    guiScene.setUpdatesEnabled(false, false)
    let markUpData = ::handyman.renderCached("%gui/profile/profileSkins", skinView)
    guiScene.replaceContentFromText(objDesc, markUpData, markUpData.len(), this)

    if (unlockBlk)
      ::g_unlock_view.fillUnlockFav(name, objDesc)

    showSceneBtn("unlocks_list", false)
    guiScene.setUpdatesEnabled(true, true)
  }

  function append_condition_item(item, idx, view, header, is_unlocked, typeOR = false)
  {
    let curVal = item.curVal
    let maxVal = item.maxVal
    let showStages = ("stages" in item) && (item.stages.len() > 1)

    local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
    unlockDesc += item.text.indexof("%d") != null ? format(item.text, curVal, maxVal) : item.text
    if (showStages && item.curStage >= 0)
       unlockDesc += ::g_unlock_view.getRewardText(item, item.curStage)

    let progressData = item?.getProgressBarData?()
    let hasProgress = progressData?.show
    let progress = progressData?.value

    view.append({
      isHeader = header
      id = "unlock_txt_" + idx
      unlocked = is_unlocked ? "yes" : "no"
      text = unlockDesc
      hasProgress = hasProgress
      progress = progress
    })
  }

  unlockToFavorites = @(obj) ::g_unlocks.unlockToFavorites(obj,
    ::Callback(updateFavoritesCheckboxesInList, this))

  function updateFavoritesCheckboxesInList()
  {
    if (isPageFilling)
      return

    let canAddFav = ::g_unlocks.canAddFavorite()
    foreach (unlockId in getCurUnlockList())
    {
      let unlockObj = scene.findObject(getUnlockBlockId(unlockId))
      if (!::check_obj(unlockObj))
        continue

      let cbObj = unlockObj.findObject("checkbox_favorites")
      if (::check_obj(cbObj))
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
    if (!::check_obj(checkBoxObj))
      return

    checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  function onBuyUnlock(obj)
  {
    let unlockId = ::getTblValue("unlockId", obj)
    if (::u.isEmpty(unlockId))
      return

    let cost = ::get_unlock_cost(unlockId)
    msgBox("question_buy_unlock",
      ::warningIfGold(
        ::loc("onlineShop/needMoneyQuestion",
          { purchase = ::colorize("unlockHeaderColor", ::get_unlock_name_text(-1, unlockId)),
            cost = cost.getTextAccordingToBalance()
          }),
        cost),
      [
        ["ok", @() ::g_unlocks.buyUnlock(unlockId,
            ::Callback(@() updateUnlockBlock(unlockId), this),
            ::Callback(@() onUnlockGroupSelect(null), this))
        ],
        ["cancel", @() null]
      ], "cancel")
  }

  function updateUnlockBlock(unlockData)
  {
    local unlock = unlockData
    if (::u.isString(unlockData))
      unlock = ::g_unlocks.getUnlockById(unlockData)

    let unlockObj = scene.findObject(getUnlockBlockId(unlock.id))
    if (::check_obj(unlockObj))
      fillUnlockInfo(unlock, unlockObj)
  }

  function showUnlockUnits(obj) {
    let unlockBlk = ::g_unlocks.getUnlockById(obj.unlockId)
    let allUnits = getUnitListByUnlockId(obj.unlockId).filter(@(u) u.isVisibleInShop())

    let unlockCfg = ::build_conditions_config(unlockBlk)
    shopSearchWnd.open(null, ::Callback(@(u) showUnitInShop(u), this), getShopDiffCode, {
      units = allUnits
      wndTitle = ::loc("mainmenu/showVehiclesTitle", {
        taskName = ::g_unlock_view.getUnlockTitle(unlockCfg)
      })
    })
  }

  function showUnitInShop(unitName) {
    if (!unitName)
      return

    ::broadcastEvent("ShowUnitInShop", { unitName })
    goBack()
  }

  function fillUnlockInfo(unlockBlk, unlockObj)
  {
    let itemData = build_conditions_config(unlockBlk)
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
  }

  function printUnlocksList(unlocksList)
  {
    let achievaAmount = unlocksList.len()
    let unlocksListObj = showSceneBtn("unlocks_list", true)
    showSceneBtn("item_desc", false)
    local blockAmount = unlocksListObj.childrenCount()

    guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievaAmount)
    {
      let unlockItemBlk = "%gui/profile/unlockItem.blk"
      for(; blockAmount < achievaAmount; blockAmount++)
        guiScene.createElementByObject(unlocksListObj, unlockItemBlk, "expandable", this)
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
        let unlockConfigString = ::toString(unlock, 2) // warning disable: -declared-never-used
        ::script_net_assert_once("missing id in unlock after cashed", "ProfileHandler: Missing id in unlock after cashed")
        continue
      }

      if (!::isInArray(unlock.id, unlocksList))
        continue

      let unlockObj = unlocksListObj.getChild(currentItemNum)
      unlockObj.id = getUnlockBlockId(unlock.id)
      unlockObj.holderId = unlock.id
      fillUnlockInfo(unlock, unlockObj)

      if (curUnlockId == unlock.id)
        selIdx = currentItemNum

      currentItemNum++
    }

    if (unlocksListObj.childrenCount() > 0)
      unlocksListObj.setValue(selIdx)

    guiScene.setUpdatesEnabled(true, true)

    seenList.markSeen(getUnlockIds(::get_current_ediff()).filter(@(u) unlocksList.contains(u)))
  }

  function getUnlockBlockId(unlockId)
  {
    return unlockId + "_block"
  }

  function onMedalSelect(obj)
  {
    if (!::check_obj(obj))
      return

    let idx = obj.getValue()
    let itemObj = idx >= 0 && idx < obj.childrenCount() ? obj.getChild(idx) : null
    let name = ::check_obj(itemObj) && itemObj?.id
    let unlock = name && ::g_unlocks.getUnlockById(name)
    if (!unlock)
      return

    let containerObj = scene.findObject("medals_info")
    let descObj = check_obj(containerObj) && containerObj.findObject("medals_desc")
    if (!::check_obj(descObj))
      return

    if (!isPageFilling)
      selMedalIdx[curFilter] <- idx

    guiScene.setUpdatesEnabled(false, false)

    let isUnlocked = ::is_unlocked_scripted(::get_unlock_type_by_id(name), name)
    let config = ::build_conditions_config(unlock)
    ::build_unlock_desc(config)
    let rewardText = ::get_unlock_reward(name)

    let condView = []
    append_condition_item(config, 0, condView, true, isUnlocked)

    ::showBtn("checkbox_favorites", true, containerObj)
    ::g_unlock_view.fillUnlockFav(name, containerObj)

    let view = {
      title = ::loc(name + "/name")
      image = ::get_image_for_unlockable_medal(name, true)
      condition = condView
      rewardText = rewardText != "" ? rewardText : null
    }

    let markup = ::handyman.renderCached("%gui/profile/profileMedal", view)
    guiScene.replaceContentFromText(descObj, markup, markup.len(), this)

    guiScene.setUpdatesEnabled(true, true)
  }

  function onDecalClick(obj)
  {
    let decoratorId = ::check_obj(obj) ? (obj?.id ?? "") : ""
    let decorator = ::g_decorator.getDecoratorById(decoratorId)
    if (canAcquireDecorator(decorator))
      askAcquireDecorator(decorator, null)
  }

  function onUnlockSelect(obj)
  {
    if (obj?.isValid())
      curUnlockId = getSelectedChild(obj)?.holderId ?? ""
  }

  function onUnlockGroupSelect(obj) {
    let list = scene.findObject("unlocks_group_list")
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

  function onSkinPreview(obj)
  {
    let list = scene.findObject("unlocks_group_list")
    let index = list.getValue()
    if ((index < 0) || (index >= list.childrenCount()))
      return

    let skinId = list.getChild(index).id
    let decorator = ::g_decorator.getDecoratorById(skinId)
    initSkinId = skinId
    if (decorator && canStartPreviewScene(true, true))
      guiScene.performDelayed(this, @() decorator.doPreview())
  }

  function getHandlerRestoreData() {
    let data = {
     openData = {
        initialSheet = "UnlockSkin"
        initSkinId = initSkinId
        filterCountryName = curFilter
        filterUnitTag = filterUnitTag
      }
    }
    return data
  }

  function onEventBeforeStartShowroom(p) {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getCurSheet()
  {
    let obj = scene.findObject("profile_sheet_list")
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
    return buildTableRowNoPad("", row)
  }

  function updateStats()
  {
    let myStats = ::my_stats.getStats()
    if (!myStats || !::checkObj(scene))
      return

    fillProfileStats(myStats)
  }

  function openChooseTitleWnd(obj)
  {
    ::gui_handlers.ChooseTitle.open({
      alignObj = obj
      openTitlesListFunc = ::Callback(@() openProfileTab("UnlockAchievement", "title"), this)
    })
  }

  function openProfileTab(tab, selectedBlock)
  {
    let obj = scene.findObject("profile_sheet_list")
    if(::checkObj(obj))
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
    fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles")
    if ("uid" in stats && stats.uid != ::my_user_id_str)
      externalIDsService.reqPlayerExternalIDsByUserId(stats.uid)
    fillClanInfo(::get_profile_info())
    fillModeListBox(scene.findObject("profile-container"), curMode)
    ::fill_gamer_card(::get_profile_info(), "profile-", scene)
    fillAwardsBlock(stats)
    fillShortCountryStats(stats)
    scene.findObject("profile_loading").show(false)
  }

  function onProfileStatsModeChange(obj)
  {
    if (!::checkObj(scene))
      return
    let myStats = ::my_stats.getStats()
    if (!myStats)
      return

    curMode = obj.getValue()

    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(curMode)
    fillProfileSummary(scene.findObject("stats_table"), myStats.summary, curMode)
    fillLeaderboard()
  }

  /*
  function onDifficultyChange(obj)
  {
    if (obj != null)
    {
      local opdata = ::get_option(::USEROPT_SEARCH_DIFFICULTY)
      local idx = obj.getValue()

      if (idx in opdata.values)
        curDifficulty = opdata.values[idx]
      updateStats()
    }
  }

  function onPlayerModeChange(obj)
  {
    if (obj != null)
    {
      curPlayerMode = obj.getValue()

      updateStats()
    }
  }
  */

  function onUpdate(obj, dt)
  {
    if (pending_logout && ::is_app_active() && !::steam_is_overlay_active() && !::is_builtin_browser_active())
    {
      pending_logout = false
      guiScene.performDelayed(this, function() {
        startLogout()
      })
    }
  }

  function onChangeName()
  {
    local textLocId = "mainmenu/questionChangeName"
    local afterOkFunc = @() guiScene.performDelayed(this, function() { pending_logout = true})

    if (::steam_is_running() && !::has_feature("AllowSteamAccountLinking"))
    {
      textLocId = "mainmenu/questionChangeNameSteam"
      afterOkFunc = @() null
    }

    msgBox("question_change_name", ::loc(textLocId),
      [
        ["ok", function() {
          openUrl(::loc("url/changeName"), false, false, "profile_page")
          afterOkFunc()
        }],
        ["cancel", function() { }]
      ], "cancel")
  }

  function onChangeAccount()
  {
    msgBox("question_change_name", ::loc("mainmenu/questionChangePlayer"),
      [
        ["yes", function() {
          ::save_local_shared_settings(USE_STEAM_LOGIN_AUTO_SETTING_ID, null)
          startLogout()
        }],
        ["no", @() null ]
      ], "no", { cancel_fn = @() null })
  }

  function afterModalDestroy() {
    restoreMainOptions()
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

    if (!::checkObj(scene))
      return

    let obj = scene.findObject("profile-icon")
    if (obj)
      obj.setValue(::get_profile_info().icon)

    ::broadcastEvent(profileEvent.AVATAR_CHANGED)
  }

  function onEventMyStatsUpdated(params)
  {
    if (getCurSheet() == "Statistics")
      fillAirStats()
    if (getCurSheet() == "Profile")
      updateStats()
  }

  function onEventClanInfoUpdate(params)
  {
    fillClanInfo(::get_profile_info())
  }

  function initAirStats()
  {
    let myStats = ::my_stats.getStats()
    if (!myStats || !::checkObj(scene))
      return

    initAirStatsScene(myStats.userstat)
  }

  function fillAirStats()
  {
    let myStats = ::my_stats.getStats()
    if (!airStatsInited || !myStats || !myStats.userstat)
      return initAirStats()

    fillAirStatsScene(myStats.userstat)
  }

  function getPlayerStats()
  {
    return ::my_stats.getStats()
  }

  function getCurUnlockList()
  {
    let list = scene.findObject("unlocks_group_list")
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

  function onGroupCancel(obj)
  {
    if (::show_console_buttons && getCurSheet() == "UnlockSkin")
      ::move_mouse_on_child_by_value(scene.findObject("pages_list"))
    else
      goBack()
  }

  function onBindPS4Email()
  {
    ::g_user_utils.launchPS4EmailRegistration()
    doWhenActiveOnce("updateButtons")
  }

  function onBindSteamEmail()
  {
    ::g_user_utils.launchSteamEmailRegistration()
    doWhenActiveOnce("updateButtons")
  }

  function onBindXboxEmail()
  {
    ::g_user_utils.launchXboxEmailRegistration()
    doWhenActiveOnce("updateButtons")
  }

  function onEventUnlocksCacheInvalidate(p)
  {
    if (::isInArray(getCurSheet(), [ "UnlockAchievement", "UnlockDecal" ]))
      fillUnlocksList()
  }

  function onEventUnlockMarkersCacheInvalidate(_) {
    if (getCurSheet() == "UnlockAchievement")
      fillUnlocksList()
  }

  function onEventInventoryUpdate(p)
  {
    if (::isInArray(getCurSheet(), [ "UnlockAchievement", "UnlockDecal" ]))
      fillUnlocksList()
  }

  function onOpenAchievementsUrl()
  {
    openUrl(::loc("url/achievements",
        { appId = ::WT_APPID, name = ::get_profile_info().name}),
      false, false, "profile_page")
  }
}

let openProfileSheetParamsFromPromo = {
  UnlockAchievement = @(p1, p2, ...) {
    uncollapsedChapterName = p2 != ""? p1 : null
    curAchievementGroupName = p1 + (p2 != "" ? ("/" + p2) : "")
  }
  Medal = @(p1, p2, ...) { filterCountryName = p1 }
  UnlockSkin = @(p1, p2, p3) {
    filterCountryName = p1
    filterUnitTag = p2
    initSkinId = p3
  }
  UnlockDecal = @(p1, p2, ...) { filterGroupName = p1 }
}

local function openProfileFromPromo(params, sheet = null) {
  sheet = sheet ?? params?[0]
  let launchParams = openProfileSheetParamsFromPromo?[sheet](
    params?[1], params?[2] ?? "", params?[3] ?? "") ?? {}
  launchParams.__update({ initialSheet = sheet })
  ::gui_start_profile(launchParams)
}

addPromoAction("profile", @(handler, params, obj) openProfileFromPromo(params))
