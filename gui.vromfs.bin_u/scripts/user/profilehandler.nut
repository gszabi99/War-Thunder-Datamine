local time = require("scripts/time.nut")
local externalIDsService = require("scripts/user/externalIdsService.nut")
local avatars = require("scripts/user/avatars.nut")
local { isMeXBOXPlayer,
        isMePS4Player,
        isPlatformPC,
        isPlatformSony,
        isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local { startLogout } = require("scripts/login/logout.nut")
local { canAcquireDecorator, askAcquireDecorator } = require("scripts/customization/decoratorAcquire.nut")
local { getViralAcquisitionDesc, showViralAcquisitionWnd } = require("scripts/user/viralAcquisition.nut")

enum profileEvent {
  AVATAR_CHANGED = "AvatarChanged"
}

enum OwnUnitsType
{
  ALL = "all",
  BOUGHT = "only_bought",
}

local selMedalIdx = {}

::gui_start_profile <- function gui_start_profile(params = {})
{
  if (!::has_feature("Profile"))
    return

  ::gui_start_modal_wnd(::gui_handlers.Profile, params)
}

class ::gui_handlers.Profile extends ::gui_handlers.UserCardHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/profile/profile.blk"
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
  filterCountryName = null
  filterUnitTag = ""
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
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

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
      local skinCountries = getUnlockFiltersList("skin", function(unlock)
        {
          local country = getSkinCountry(unlock.getStr("id", ""))
          return (country != "")? country : null
        })

      unlockFilters.UnlockSkin = ::u.filter(::shopCountriesList, @(c) ::isInArray(c, skinCountries))
    }

    //fill medal filters
    if ("Medal" in unlockFilters)
    {
      local medalCountries = getUnlockFiltersList("medal", @(unlock) unlock?.country)
      unlockFilters.Medal = ::u.filter(::shopCountriesList, @(c) ::isInArray(c, medalCountries))
    }

    local bntGetLinkObj = scene.findObject("btn_getLink")
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

    local customCategoryConfig = ::getTblValue("customProfileMenuTab", ::get_gui_regional_blk(), null)
    local tabImage = null
    local tabText = null

    foreach(cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      local unlockType = cb?.type ?? ""
      local unlockTypeId = ::get_unlock_type(unlockType)

      if (!::isInArray(unlockTypeId, unlockTypesToShow))
        continue
      if (!::is_unlock_visible(cb))
        continue

      hasAnyUnlocks = true
      if (unlockTypeId == ::UNLOCKABLE_MEDAL)
        hasAnyMedals = true

      if (cb?.customMenuTab == null)
        continue

      local lowerCaseTab = cb.customMenuTab.tolower()
      if (lowerCaseTab in customMenuTabs)
        continue

      sheetsList.append(lowerCaseTab)
      unlockFilters[lowerCaseTab]  <- null

      local defaultImage = ::format(tabImageNameTemplate, defaultTabImageName)

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

    local sheetsToHide = []
    if (!hasAnyMedals)
      sheetsToHide.append("Medal")
    if (!hasAnyUnlocks)
      sheetsToHide.append("UnlockAchievement")
    foreach(sheetName in sheetsToHide)
    {
      local idx = sheetsList.indexof(sheetName)
      if (idx != null)
        sheetsList.remove(idx)
    }
  }

  function initTabs()
  {
    local view = { tabs = [] }
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
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
        hidden = !isSheetVisible(sheet)
      })

      if (initialSheet == sheet)
        curSheetIdx = idx
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local sheetsListObj = scene.findObject("profile_sheet_list")
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
    local categories = []
    local unlocks = ::g_unlocks.getUnlocksByType(uType)
    foreach(unlock in unlocks)
      if (::is_unlock_visible(unlock))
        ::u.appendOnce(getCategoryFunc(unlock), categories, true)

    return categories
  }

  function updateButtons()
  {
    local sheet = getCurSheet()
    local isProfileOpened = sheet == "Profile"
    local buttonsList = {
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
    }

    ::showBtnTable(scene, buttonsList)
  }

  function onSheetChange(obj)
  {
    local sheet = getCurSheet()
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
      local isMedal = sheet=="Medal"
      showSheetDiv(isMedal ? "medals" : "decals", true)

      local selCategory = isMedal
        ? filterCountryName || ::get_profile_country_sq()
        : filterGroupName || ::loadLocalByAccount("wnd/decalsCategory", "")

      local selIdx = 0
      local view = { items = [] }
      foreach (idx, filter in unlockFilters[sheet])
      {
        if (filter == selCategory)
          selIdx = idx
        if (isMedal)
          view.items.append({ text = $"#{filter}"})
        else
          view.items.append({ itemText = $"#decals/category/{filter}" })
      }

      local tplPath = isMedal ? "gui/commonParts/shopFilter" : "gui/missions/missionBoxItemsList"
      local data = ::handyman.renderCached(tplPath, view)
      local pageList = scene.findObject($"{isMedal ? "medals" : "decals_group"}_list")
      guiScene.replaceContentFromText(pageList, data, data.len(), this)

      local isEqualIdx = selIdx == pageList.getValue()
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
        local pageList = scene.findObject("pages_list")
        local curCountry = filterCountryName || ::get_profile_country_sq()
        local selIdx = 0

        local view = { items = [] }
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

        local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
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
    local start = name.indexof("Unlock")
    if (start!=null)
      return name.slice(start+6)
    return name
  }

  function showSheetDiv(name, pages = false, subPages = false)
  {
    foreach(div in ["profile", "unlocks", "stats", "medals", "decals"])
    {
      local show = div == name
      local divObj = scene.findObject(div + "-container")
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
    local sheet = getCurSheet()
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

    local filter = unlockFilters[sheet][pageIdx]
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
    local subSwitch = getObj("unit_type_list")
    if (::check_obj(subSwitch))
    {
      local value = subSwitch.getValue()
      local unitType = unitTypes.getByEsUnitType(value)
      curSubFilter = unitType.esUnitType
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
    local unitypeListObj = scene.findObject("unit_type_list")
    if ( ! ::check_obj(unitypeListObj))
      return

    if ( ! unitypeListObj.childrenCount())
    {
      local filterUnitType = unitTypes.getByTag(filterUnitTag)
      if (!filterUnitType.isAvailable())
        filterUnitType = unitTypes.getByEsUnitType(::get_es_unit_type(::get_cur_slotbar_unit()))

      local view = { items = [] }
      foreach(unitType in unitTypes.types)
        if (unitType.isAvailable())
          view.items.append(
            {
              image = unitType.testFlightIcon
              tooltip = unitType.getArmyLocName()
              selected = filterUnitType == unitType
            }
          )

      local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
      guiScene.replaceContentFromText(unitypeListObj, data, data.len(), this)
    }

    local indexForSelection = -1
    local previousSelectedIndex = unitypeListObj.getValue()
    local total = unitypeListObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      local obj = unitypeListObj.getChild(i)
      local unitType = unitTypes.getByEsUnitType(i)
      local isVisible = getSkinsCache(curFilter, unitType.esUnitType, OwnUnitsType.ALL).len() > 0
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
      local unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
      if (!unit)
        continue

      if ( ! unit.isVisibleInShop())
        continue

      if (!decorator || !decorator.isVisible())
        continue

      local unitType = ::get_es_unit_type(unit)
      local unitCountry = ::getUnitCountry(unit)

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
    local ownSwitch = scene.findObject("checkbox_only_for_bought")
    local ownType = ( ! ::checkObj(ownSwitch) || ! ownSwitch.getValue()) ? OwnUnitsType.ALL : OwnUnitsType.BOUGHT
    return ownType
  }

  function refreshOwnUnitControl(unitType)
  {
    local ownSwitch = scene.findObject("checkbox_only_for_bought")
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
    local lowerCurPage = curPage.tolower()
    local pageTypeId = ::get_unlock_type(lowerCurPage)
    local isNeedDecalDesc = pageTypeId == ::UNLOCKABLE_MEDAL
    local itemSelectFunc  = pageTypeId == ::UNLOCKABLE_MEDAL ? onMedalSelect : null
    local containerObjId = pageTypeId == ::UNLOCKABLE_MEDAL ? "medals_zone"
      : pageTypeId == ::UNLOCKABLE_DECAL ? "decals_zone"
      : "unlocks_group_list"
    unlocksTree = {}

    local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(pageTypeId)
    if (pageTypeId == ::UNLOCKABLE_DECAL)
      data = getDecoratorsMarkup(decoratorType)
    else if (pageTypeId == ::UNLOCKABLE_SKIN)
      data = getSkinsMarkup()
    else
    {
      local view = { items = [] }
      view.items = generateItems(pageTypeId)
      data = ::handyman.renderCached("gui/commonParts/imgFrame", view)
    }

    showSceneBtn("medals_info", isNeedDecalDesc)
    foreach (id in [ "medals_zone", "decals_zone" ])
      showSceneBtn(id, id == containerObjId)
    local unlocksObj = scene.findObject(containerObjId)

    local curIndex = 0
    local isAchievementPage = lowerCurPage == "achievement"
    local view = { items = [] }
    foreach (chapterName, chapterItem in unlocksTree)
    {
      if (isAchievementPage && chapterName == curAchievementGroupName)
        curIndex = view.items.len()

      view.items.append({
        itemTag = "campaign_item"
        id = chapterName
        itemText = "#unlocks/chapter/" + chapterName
        isCollapsable = chapterItem.groups.len() > 0
      })

      if (chapterItem.groups.len() > 0)
        foreach (groupName, groupItem in chapterItem.groups)
        {
          local id = chapterName + "/" + groupName
          if (isAchievementPage && id == curAchievementGroupName)
            curIndex = view.items.len()

          view.items.append({
            id = id
            itemText = "#unlocks/group/" + groupName
          })
        }
    }
    data += ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(unlocksObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    if (pageTypeId == ::UNLOCKABLE_MEDAL)
      curIndex = selMedalIdx?[curFilter] ?? 0

    local total = unlocksObj.childrenCount()
    curIndex = total ? ::clamp(curIndex, 0, total - 1) : -1
    unlocksObj.setValue(curIndex)

    collapse()
    itemSelectFunc?(unlocksObj)

    isPageFilling = false
    updateFavoritesCheckboxesInList()
  }

  function getSkinsMarkup()
  {
    local itemsView = []
    local comma = ::loc("ui/comma")
    foreach (decorator in getSkinsCache(curFilter, curSubFilter, getCurrentOwnType()))
    {
      local unitId = ::g_unlocks.getPlaneBySkinId(decorator.id)

      itemsView.append({
        id = decorator.id
        itemText = comma.concat(::getUnitName(unitId), decorator.getName())
        itemIcon = decorator.isUnlocked() ? "#ui/gameuiskin#unlocked" : "#ui/gameuiskin#locked"
      })
    }
    itemsView.sort(@(a, b) a.itemText <=> b.itemText)
    return ::handyman.renderCached("gui/missions/missionBoxItemsList", { items = itemsView })
  }

  function generateItems(pageTypeId)
  {
    local items = []
    local lowerCurPage = curPage.tolower()
    local isCustomMenuTab = lowerCurPage in customMenuTabs
    local isUnlockTree = isCustomMenuTab || pageTypeId == -1 || pageTypeId == ::UNLOCKABLE_ACHIEVEMENT
    local chapter = ""
    local group = ""

    foreach(idx, cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      local name = cb.getStr("id", "")
      local unlockType = cb?.type ?? ""
      local unlockTypeId = ::get_unlock_type(unlockType)
      local isForceVisibleInTree = cb?.isForceVisibleInTree ?? false
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
        local dInfo = ::g_decorator.getCachedDecoratorByUnlockId(name, ::g_decorator_type.DECALS)
        if (!dInfo || dInfo.category != curFilter)
          continue
      }

      if (isUnlockTree)
      {
        local newChapter = cb.getStr("chapter","")
        local newGroup = cb.getStr("group","")
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
    local unit = getUnitBySkin(skinName)
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
    local decoratorsList = ::g_decorator.getCachedDecoratorsDataByType(decoratorType)
    local decorators = decoratorsList?[curFilter] ?? []
    local view = {
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
    return ::handyman.renderCached("gui/commonParts/imgFrame", view)
  }

  function checkSkinVehicle(unitName)
  {
    local unit = ::getAircraftByName(unitName)
    if (unit == null)
      return false
    if (!::has_feature("Tanks") && unit?.isTank())
      return false
    return unit.isVisibleInShop()
  }

  function collapse(itemName = null)
  {
    local listObj = scene.findObject("unlocks_group_list")
    if (!listObj || !unlocksTree || unlocksTree.len() == 0)
      return

    local chapterRegexp = regexp2("/[^\\s]+")
    local chapterName = itemName && chapterRegexp.replace("", itemName)
    uncollapsedChapterName = chapterName?
      (chapterName == uncollapsedChapterName)? null : chapterName
      : uncollapsedChapterName
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
    local total = listObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      local obj = listObj.getChild(i)
      local iName = obj?.id
      local isUncollapsedChapter = iName == uncollapsedChapterName
      if (iName == (isUncollapsedChapter ? curAchievementGroupName : chapterName))
        newValue = i

      if (iName in unlocksTree) //chapter
      {
        obj.collapsed = isUncollapsedChapter? "no" : "yes"
        continue
      }

      local iChapter = iName && chapterRegexp.replace("", iName)
      local visible = iChapter == uncollapsedChapterName
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
    local id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
    {
      collapse(id.slice(4))
      local listBoxObj = scene.findObject("unlocks_group_list")
      local listItemCount = listBoxObj.childrenCount()
      for(local i = 0; i < listItemCount; i++)
      {
        local listItemId = listBoxObj.getChild(i)?.id
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
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    collapse(obj.getChild(value).id)
  }

  function openCollapsedGroup(group, name)
  {
    collapse(group)
    local reqBlockName = group + (name? ("/" + name) : "")
    local listBoxObj = scene.findObject("unlocks_group_list")
    if (!::checkObj(listBoxObj))
      return

    local listItemCount = listBoxObj.childrenCount()
    for(local i = 0; i < listItemCount; i++)
    {
      local listItemId = listBoxObj.getChild(i).id
      if(reqBlockName == listItemId)
        return listBoxObj.setValue(i)
    }
  }

  function getSkinCountry(skinName)
  {
    local len0 = skinName.indexof("/")
    if (len0)
      return ::getShopCountry(skinName.slice(0, len0))
    return ""
  }

  function fillSkinDescr(name)
  {
    local objDesc = showSceneBtn("item_desc", true)
    local unlockBlk = ::g_unlocks.getUnlockById(name)
    local decoratorType = ::g_decorator_type.SKINS
    local decorator = ::g_decorator.getDecoratorById(name)
    local isAllowed = decorator.isUnlocked()
    local config = {}

    if (unlockBlk)
      config = ::build_conditions_config(unlockBlk)
    else
    {
      config = ::get_empty_conditions_config()
      config.image = decoratorType.getImage(decorator)
      config.imgRatio = decoratorType.getRatio(decorator)
    }

    local desc = []
    desc.append(decorator.getDesc())
    desc.append(decorator.getTypeDesc())
    desc.append(decorator.getLocParamsDesc())
    desc.append(decorator.getRestrictionsDesc())
    desc.append(decorator.getLocationDesc())
    desc.append(decorator.getTagsDesc())

    local unlockDesc = decorator.getUnlockDesc()
    if (unlockDesc.len())
      desc.append(" ") // for visually distinguish unlock requirements from other info

    desc.append(unlockDesc)
    config.text = ::g_string.implode(desc, "\n")

    local condView = []
    append_condition_item(config, 0, condView, true, isAllowed)

    if ("shortText" in config)
      for(local i=0; i<config.stages.len(); i++)  //stages of challenge
      {
        local stage = config.stages[i]
        if (stage.val != config.maxVal)
        {
          local curValStage = (config.curVal > stage.val)? stage.val : config.curVal
          local isUnlockedStage = curValStage >= stage.val
          append_condition_item({
              text = config.progressText //do not show description for stages
              curVal = curValStage
              maxVal = stage.val
            },
            i+1, condView, false, isUnlockedStage)
        }
      }

    //missions, countries
    local namesLoc = ::UnlockConditions.getLocForBitValues(config.type, config.names)
    local typeOR = ("compareOR" in config) && config.compareOR
    for(local i=0; i < namesLoc.len(); i++)
    {
      local isPartUnlocked = config.curVal & 1 << i
      append_condition_item({
            text = namesLoc[i]
            curVal = 0
            maxVal = 0
          },
          i+1, condView, false, isPartUnlocked, i > 0 && typeOR)
    }

    local unitName = ::g_unlocks.getPlaneBySkinId(name)
    local unitNameLoc = (unitName != "") ? ::getUnitName(unitName) : ""

    local skinView = { skinDescription = [{
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
    local markUpData = ::handyman.renderCached("gui/profile/profileSkins", skinView)
    guiScene.replaceContentFromText(objDesc, markUpData, markUpData.len(), this)

    if (unlockBlk)
      ::g_unlock_view.fillUnlockFav(name, objDesc)

    showSceneBtn("unlocks_list", false)
    guiScene.setUpdatesEnabled(true, true)
  }

  function append_condition_item(item, idx, view, header, is_unlocked, typeOR = false)
  {
    local curVal = item.curVal
    local maxVal = item.maxVal
    local showStages = ("stages" in item) && (item.stages.len() > 1)

    local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
    unlockDesc += item.text.indexof("%d") != null ? format(item.text, curVal, maxVal) : item.text
    if (showStages && item.curStage >= 0)
       unlockDesc += ::g_unlock_view.getRewardText(item, item.curStage)

    local progressData = item?.getProgressBarData?()
    local hasProgress = progressData?.show
    local progress = progressData?.value

    view.append({
      isHeader = header
      id = "unlock_txt_" + idx
      unlocked = is_unlocked ? "yes" : "no"
      text = unlockDesc
      hasProgress = hasProgress
      progress = progress
    })
  }

  function unlockToFavorites(obj)
  {
    local unlockId = obj?.unlockId

    if (::u.isEmpty(unlockId))
      return

    if (!::g_unlocks.canAddFavorite()
      && obj.getValue() // Don't notify if value set to false
      && !(unlockId in ::g_unlocks.getFavoriteUnlocks())) //Don't notify if unlock wasn't in list already
    {
      ::g_popups.add("", ::colorize("warningTextColor", ::loc("mainmenu/unlockAchievements/limitReached", {num = ::g_unlocks.favoriteUnlocksLimit})))
      obj.setValue(false)
      return
    }

    obj.tooltip = obj.getValue() ?
      ::g_unlocks.addUnlockToFavorites(unlockId) : ::g_unlocks.removeUnlockFromFavorites(unlockId)
    ::g_unlock_view.fillUnlockFavCheckbox(obj)
    updateFavoritesCheckboxesInList()
  }

  function updateFavoritesCheckboxesInList()
  {
    if (isPageFilling)
      return

    local canAddFav = ::g_unlocks.canAddFavorite()
    foreach (unlockId in getCurUnlockList())
    {
      local unlockObj = scene.findObject(getUnlockBlockId(unlockId))
      if (!::check_obj(unlockObj))
        continue

      local cbObj = unlockObj.findObject("checkbox-favorites")
      if (::check_obj(cbObj))
        cbObj.inactiveColor = (canAddFav || (unlockId in ::g_unlocks.getFavoriteUnlocks())) ? "no" : "yes"
    }
  }

  function unlockToFavoritesByActivateItem(obj)
  {
    local childrenCount = obj.childrenCount()
    local index = obj.getValue()
    if (index < 0 || index >= childrenCount)
      return

    local checkBoxObj = obj.getChild(index).findObject("checkbox-favorites")
    if (!::check_obj(checkBoxObj))
      return

    checkBoxObj.setValue(!checkBoxObj.getValue())
  }

  function onBuyUnlock(obj)
  {
    local unlockId = ::getTblValue("unlockId", obj)
    if (::u.isEmpty(unlockId))
      return

    local cost = ::get_unlock_cost(unlockId)
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
            ::Callback(@() onUnlockSelect(null), this))
        ],
        ["cancel", @() null]
      ], "cancel")
  }

  function updateUnlockBlock(unlockData)
  {
    local unlock = unlockData
    if (::u.isString(unlockData))
      unlock = ::g_unlocks.getUnlockById(unlockData)

    local unlockObj = scene.findObject(getUnlockBlockId(unlock.id))
    if (::check_obj(unlockObj))
      fillUnlockInfo(unlock, unlockObj)
  }

  function fillUnlockInfo(unlockBlk, unlockObj)
  {
    local itemData = build_conditions_config(unlockBlk)
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
    local achievaAmount = unlocksList.len()
    local unlocksListObj = showSceneBtn("unlocks_list", true)
    showSceneBtn("item_desc", false)
    local blockAmount = unlocksListObj.childrenCount()

    guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievaAmount)
    {
      local unlockItemBlk = "gui/profile/unlockItem.blk"
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
    foreach(unlock in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      if (!::isInArray(unlock.id, unlocksList))
        continue

      local unlockObj = unlocksListObj.getChild(currentItemNum)
      unlockObj.id = getUnlockBlockId(unlock.id)
      fillUnlockInfo(unlock, unlockObj)
      currentItemNum++
    }

    if (unlocksListObj.childrenCount() > 0)
      unlocksListObj.setValue(0)
    guiScene.setUpdatesEnabled(true, true)
  }

  function getUnlockBlockId(unlockId)
  {
    return unlockId + "_block"
  }

  function onMedalSelect(obj)
  {
    if (!::check_obj(obj))
      return

    local idx = obj.getValue()
    local itemObj = idx >= 0 && idx < obj.childrenCount() ? obj.getChild(idx) : null
    local name = ::check_obj(itemObj) && itemObj?.id
    local unlock = name && ::g_unlocks.getUnlockById(name)
    if (!unlock)
      return

    local containerObj = scene.findObject("medals_info")
    local descObj = check_obj(containerObj) && containerObj.findObject("medals_desc")
    if (!::check_obj(descObj))
      return

    if (!isPageFilling)
      selMedalIdx[curFilter] <- idx

    guiScene.setUpdatesEnabled(false, false)

    local isUnlocked = ::is_unlocked_scripted(::get_unlock_type_by_id(name), name)
    local config = ::build_conditions_config(unlock)
    ::build_unlock_desc(config)
    local rewardText = ::get_unlock_reward(name)

    local condView = []
    append_condition_item(config, 0, condView, true, isUnlocked)

    ::showBtn("checkbox-favorites", true, containerObj)
    ::g_unlock_view.fillUnlockFav(name, containerObj)
    showSceneBtn("unlocks_list", false)

    local view = {
      title = ::loc(name + "/name")
      image = ::get_image_for_unlockable_medal(name, true)
      status = isUnlocked ? "unlocked" : "locked"
      condition = condView
      rewardText = rewardText != "" ? rewardText : null
    }

    local markup = ::handyman.renderCached("gui/profile/profileMedal", view)
    guiScene.replaceContentFromText(descObj, markup, markup.len(), this)

    guiScene.setUpdatesEnabled(true, true)
  }

  function onDecalClick(obj)
  {
    local decoratorId = ::check_obj(obj) ? (obj?.id ?? "") : ""
    local decorator = ::g_decorator.getDecoratorById(decoratorId)
    if (canAcquireDecorator(decorator))
      askAcquireDecorator(decorator, null)
  }

  function onUnlockSelect(obj)
  {
    local list = scene.findObject("unlocks_group_list")
    local index = list.getValue()
    local unlocksList = []
    if ((index >= 0) && (index < list.childrenCount()))
    {
      local curObj = list.getChild(index)
      if (curPage.tolower() == "skin")
        fillSkinDescr(curObj.id)
      else
      {
        local id = curObj.id
        local isGroup = (id in unlocksTree)
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

  function getCurSheet()
  {
    local obj = scene.findObject("profile_sheet_list")
    local sheetIdx = obj.getValue()
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
    local row = [{ text = name, tdalign = "left"}]
    for (local diff=0; diff < 3; diff++)
    {
      local value = 0
      if (fm_idx==null || fm_idx >= 0)
        value = calcStat(func, diff, mode, fm_idx)
      else
        for (local i = 0; i < 3; i++)
          value += calcStat(func, diff, mode, i)

      local s = timeFormat ? time.secondsToString(value) : value
      local tooltip = ["#mainmenu/arcadeInstantAction", "#mainmenu/instantAction", "#mainmenu/fullRealInstantAction"][diff]
      row.append({ id = diff.tostring(), text = s.tostring(), tooltip = tooltip})
    }
    return buildTableRowNoPad("", row)
  }

  function updateStats()
  {
    local myStats = ::my_stats.getStats()
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
    local obj = scene.findObject("profile_sheet_list")
    if(::checkObj(obj))
    {
      local num = ::find_in_array(sheetsList, tab)
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
    local myStats = ::my_stats.getStats()
    if (!myStats)
      return

    curMode = obj.getValue()

    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(curMode)
    ::fill_profile_summary(scene.findObject("stats_table"), myStats.summary, curMode)
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
    local value = ::get_option(::USEROPT_PILOT).value
    if (value == option.idx)
      return

    ::set_option(::USEROPT_PILOT, option.idx)
    ::save_profile(false)

    if (!::checkObj(scene))
      return

    local obj = scene.findObject("profile-icon")
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
    local myStats = ::my_stats.getStats()
    if (!myStats || !::checkObj(scene))
      return

    initAirStatsScene(myStats.userstat)
  }

  function fillAirStats()
  {
    local myStats = ::my_stats.getStats()
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
    local list = scene.findObject("unlocks_group_list")
    local index = list.getValue()
    local unlocksList = []
    if ((index < 0) || (index >= list.childrenCount()))
      return unlocksList

    local curObj = list.getChild(index)
    local id = curObj.id
    if(id in unlocksTree)
      unlocksList = unlocksTree[id].rootItems
    else
      foreach(chapterName, chapterItem in unlocksTree)
      {
        local subsectionName = ::g_string.cutPrefix(id, chapterName+"/", null)
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
