local { isXBoxPlayerName,
        canInteractCrossConsole,
        isPlatformSony,
        isPlatformXboxOne,
        isPlayerFromPS4 } = require("scripts/clientState/platform.nut")
local { hasAllFeatures } = require("scripts/user/features.nut")
local externalIDsService = require("scripts/user/externalIdsService.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local psnSocial = require("sony.social")
local popupFilter = require("scripts/popups/popupFilter.nut")
local { UNIT } = require("scripts/utils/genericTooltipTypes.nut")
local { getMedalRibbonImg, hasMedalRibbonImg } = require("scripts/unlocks/unlockInfo.nut")
local { fillProfileSummary, getCountryMedals, getPlayerStatsFromBlk } = require("scripts/user/userInfoStats.nut")
local { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")

::gui_modal_userCard <- function gui_modal_userCard(playerInfo)  // uid, id (in session), name
{
  if (!::has_feature("UserCards"))
    return
  ::gui_start_modal_wnd(::gui_handlers.UserCardHandler, {info = playerInfo})
}

class ::gui_handlers.UserCardHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/profile/userCard.blk"

  isOwnStats = false

  info = null
  sheetsList = ["Profile", "Statistics"]

  tabImageNameTemplate = "#ui/gameuiskin#sh_%s.svg"
  tabLocalePrefix = "#mainmenu/btn"

  statsPerPage = 0
  showLbPlaces = 0

  airStatsInited = false
  profileInited = false

  airStatsList = null
  statsType = ::ETTI_VALUE_INHISORY
  statsMode = ""
  countryStats = null
  unitStats = []
  availableUTypes = null
  availableCountries = null
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0

  player = null
  searchPlayerByNick = false
  infoReady = false

  curMode = ::DIFFICULTY_ARCADE
  lbMode  = ""
  lbModesList = null

  curPlayerExternalIds = null
  isFilterVisible = false

  ribbonsRowLength = 3

  function initScreen()
  {
    if (!scene || !info || !(("uid" in info) || ("id" in info) || ("name" in info)))
      return goBack()

    player = {}
    foreach(pName in ["name", "uid", "id"])
      if (pName in info && info[pName] != "")
        player[pName] <- info[pName]
    if (!("name" in player))
      player.name <- ""

    scene.findObject("profile-name").setValue(player.name)
    scene.findObject("profile-container").show(false)

    initStatsParams()
    initTabs()

    taskId = -1

    local isMyPage = false
    if ("uid" in player)
    {
      taskId = ::req_player_public_statinfo(player.uid)
      if (::my_user_id_str == player.uid)
        isMyPage = true
      else
        externalIDsService.reqPlayerExternalIDsByUserId(player.uid)
    }
    else if ("id" in player)
    {
      taskId = ::req_player_public_statinfo_by_player_id(player.id)
      local selfPlayerId = ::getTblValue("uid", ::get_local_mplayer())
      if (selfPlayerId != null && selfPlayerId == player.id)
        isMyPage = true
      else
        externalIDsService.reqPlayerExternalIDsByPlayerId(player.id)
    }
    else
    {
      searchPlayerByNick = true
      taskId = ::find_nicks_by_prefix(player.name, 1, false)
    }

    if (isMyPage)
      updateExternalIdsData(externalIDsService.getSelfExternalIds(), isMyPage)

    if (taskId < 0)
      return notFoundPlayerMsg()

    ::set_char_cb(this, slotOpCb)
    afterSlotOp = tryFillUserStats
    afterSlotOpError = function(result) { /* notFoundPlayerMsg() */ goBack() }

    fillGamercard()
    initLeaderboardModes()
    updateButtons()
  }

  function initTabs()
  {
    local view = { tabs = [] }
    foreach(idx, sheet in sheetsList)
    {
      view.tabs.append({
        id = sheet
        tabImage = ::format(tabImageNameTemplate, sheet.tolower())
        tabName = tabLocalePrefix + sheet
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
      })
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local sheetsListObj = scene.findObject("profile_sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(0)
    sheetsListObj.show(false)
  }

  function initStatsParams()
  {
    curMode = ::get_current_wnd_difficulty()
    statsType = ::loadLocalByAccount("leaderboards_type", ::ETTI_VALUE_INHISORY)
  }

  function goBack()
  {
    base.goBack()
  }

  function notFoundPlayerMsg()
  {
    msgBox("incorrect_user", ::loc("chat/error/item-not-found", { nick = ("name" in player)? player.name : "" }),
        [
          ["ok", function() { goBack() } ]
        ], "ok")
  }

  function onSearchResult()
  {
    searchPlayerByNick = false

    local searchRes = ::DataBlock()
    searchRes = ::get_nicks_find_result_blk()
    foreach(uid, nick in searchRes)
      if (nick == player.name)
      {
        player.uid <- uid
        taskId = ::req_player_public_statinfo(player.uid)
        if (taskId < 0)
          return notFoundPlayerMsg()
        ::set_char_cb(this, slotOpCb)
        return
      }
    return notFoundPlayerMsg()
  }

  function tryFillUserStats()
  {
    if (searchPlayerByNick)
      return onSearchResult()

    if (!::checkObj(scene))
      return;

    local blk = ::DataBlock()
    ::get_player_public_stats(blk)

    if (!blk?.nick || blk.nick == "") //!!FIX ME: Check incorrect user by no uid in answer.
    {
      msgBox("user_not_played", ::loc("msg/player_not_played_our_game"),
        [
          ["ok", function() { goBack() } ]
        ], "ok")
      return
    }

    player = getPlayerStatsFromBlk(blk)
    if ("uid" in player)
      externalIDsService.reqPlayerExternalIDsByUserId(player.uid)

    infoReady = true
    scene.findObject("profile-container").show(true)
    scene.findObject("profile_sheet_list").show(true)
    onSheetChange(null)
    fillLeaderboard()
  }

  function showSheetDiv(name)
  {
    foreach(div in ["profile", "stats"])
    {
      local show = div == name
      local divObj = scene.findObject(div + "-container")
      if (::checkObj(divObj))
      {
        divObj.show(show)
        if (show)
          updateDifficultySwitch(divObj)
      }
    }
  }

  function onSheetChange(obj)
  {
    if (!infoReady)
      return

    if (getCurSheet() == "Statistics")
    {
      showSheetDiv("stats")
      fillStatistics()
    }
    else
    {
      showSheetDiv("profile")
      fillProfile()
    }
    updateButtons()
  }

  function fillProfile()
  {
    if (!::checkObj(scene))
      return

    fillTitleName(player.title, false)

    fillClanInfo(player)
    fillModeListBox(scene.findObject("profile-container"), curMode)
    ::fill_gamer_card(player, "profile-", scene)
    fillAwardsBlock(player)
    fillShortCountryStats(player)
    scene.findObject("profile_loading").show(false)
  }

  function fillTitleName(name, setEmpty = true)
  {
    if(name == "")
    {
      if (!setEmpty)
        return

      name = "empty_title"
    }
    fillAdditionalName(::get_unlock_name_text(::UNLOCKABLE_TITLE, name), "title")
    scene.findObject("profile-currentUser-title")["inactive"] = isOwnStats ? "no" : "yes"
  }

  function onProfileStatsModeChange(obj)
  {
    if (!::checkObj(scene))
      return
    local value = obj.getValue()

    curMode = value
    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(curMode)
    fillProfileSummary(scene.findObject("stats_table"), player.summary, curMode)
  }

  function onEventContactsGroupUpdate(p)
  {
    updateButtons()
  }

  function onEventUpdateExternalsIDs(params)
  {
    if (!(params?.externalIds))
      return

    if (player?.uid != params?.request?.uid && player?.id != params?.request?.playerId)
      return

    local isMe = ::my_user_id_str == player?.uid
    updateExternalIdsData(params.externalIds, isMe)
  }

  function updateExternalIdsData(externalIdsData, isMe)
  {
    curPlayerExternalIds = externalIdsData

    fillAdditionalName(curPlayerExternalIds?.steamName ?? "", "steamName")
    fillAdditionalName(curPlayerExternalIds?.facebookName ?? "", "facebookName")

    showSceneBtn("btn_xbox_profile", isPlatformXboxOne && !isMe && (curPlayerExternalIds?.xboxId ?? "") != "")
    showSceneBtn("btn_psn_profile", isPlatformSony && !isMe && psnSocial?.open_player_profile != null && (curPlayerExternalIds?.psnId ?? "") != "")
  }

  function fillAdditionalName(name, link)
  {
    if (!::checkObj(scene))
      return

    local nameObj = scene.findObject("profile-currentUser-" + link)
    if (!::check_obj(nameObj))
      return

    nameObj.setValue(name == "" ? "" : $"{link == "title" ? "" : ::loc("profile/" + link)}{name}")
  }

  function fillClanInfo(playerData)
  {
    if (!::has_feature("Clans"))
      return

    local clanTagObj = scene.findObject("profile-clanTag");
    if (clanTagObj)
    {
      local clanType = ::g_clan_type.getTypeByCode(playerData.clanType)
      local text = ::checkClanTagForDirtyWords(playerData.clanTag);
      clanTagObj.setValue(::colorize(clanType.color, text));
      clanTagObj.tooltip = ::ps4CheckAndReplaceContentDisabledText(playerData.clanName);
    }
  }

  function fillShortCountryStats(profile)
  {
    local countryStatsNest = scene.findObject("country_stats_nest")
    if (!::checkObj(countryStatsNest))
      return

    local columns = shopCountriesList.map(@(c) {
      icon            = ::get_country_icon(c)
      unitsCount      = profile.countryStats[c].unitsCount
      eliteUnitsCount = profile.countryStats[c].eliteUnitsCount
    })

    local blk = ::handyman.renderCached(("gui/profile/country_stats_table"), {
      columns = columns,
      tableName = ::loc("lobby/vehicles")
    })
    guiScene.replaceContentFromText(countryStatsNest, blk, blk.len(), this)
  }

  function updateCurrentStatsMode(value)
  {
    statsMode = ::g_difficulty.getDifficultyByDiffCode(value).egdLowercaseName
  }

  function updateDifficultySwitch(parentObj)
  {
    if (!::checkObj(parentObj))
      return

    local switchObj = parentObj.findObject("modes_list")
    if (!::checkObj(switchObj))
      return

    local childrenCount = switchObj.childrenCount()
    if (childrenCount <= 0)
      return

    switchObj.setValue(::clamp(curMode, 0, childrenCount - 1))
  }

  function onStatsModeChange(obj)
  {
    if (!::checkObj(obj))
      return

    local value = obj.getValue()
    if (curMode == value)
      return

    curMode = value
    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(value)
    fillAirStats()
  }

  function fillAwardsBlock(pl)
  {
    if (::has_feature("ProfileMedals"))
      fillMedalsBlock(pl)
    else // Tencent
      fillTitlesBlock(pl)
  }

  function fillMedalsBlock(pl)
  {
    local curCountryId = ::get_profile_country_sq()
    local maxMedals = 0
    if (!isOwnStats)
    {
      maxMedals = pl.countryStats[curCountryId].medalsCount
      foreach(idx, countryId in shopCountriesList)
      {
        local medalsCount = pl.countryStats[countryId].medalsCount
        if (maxMedals < medalsCount)
        {
          curCountryId = countryId
          maxMedals = medalsCount
        }
      }
    }

    // Filling country tabs
    local curValue = 0
    local view = { items = [] }
    local countFmt = "text { pos:t='pw/2-w/2, ph+@blockInterval'; position:t='absolute'; text:t='%d' }"
    foreach(idx, countryId in shopCountriesList)
    {
      view.items.append({
        id = countryId
        image = ::get_country_icon(countryId)
        tooltip = "#" + countryId
        objects = ::format(countFmt, pl.countryStats[countryId].medalsCount)
      })

      if (countryId == curCountryId)
        curValue = idx
    }

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    local countriesObj = scene.findObject("medals_country_tabs")
    guiScene.replaceContentFromText(countriesObj, data, data.len(), this)
    countriesObj.setValue(curValue)
  }

  function onMedalsCountrySelect(obj)
  {
    local nestObj = scene.findObject("medals_nest")
    if (!::check_obj(obj) || !::check_obj(nestObj))
      return

    local countryId = shopCountriesList?[obj.getValue()]
    if (!countryId)
      return

    local medalsList = getCountryMedals(countryId, player)
    showSceneBtn("medals_empty", !medalsList.len())

    local view = {
      ribbons = getRibbonsView(medalsList.filter(@(id) hasMedalRibbonImg(id)))
      medals = getMedalsView(medalsList.filter(@(id) !hasMedalRibbonImg(id)))
    }

    local markup = ::handyman.renderCached("gui/profile/profileRibbons", view)
    guiScene.replaceContentFromText(nestObj, markup, markup.len(), this)
  }

  function getRibbonsView(medalsList)
  {
    return medalsList.len() > 0 ? {
      flowAlign = medalsList.len() > ribbonsRowLength ? "center" : "left"
      items = medalsList.map((@(id) {
        tag = "imgUsercardRibbon"
        image = getMedalRibbonImg(id)
      }.__merge(getBaseConfigMedal(id))).bindenv(this))
    } : null
  }

  function getMedalsView(medalsList)
  {
    return medalsList.len() > 0 ? {
      items = medalsList.map((@(id) {
        tag = "imgUsercardMedal"
        image = ::get_image_for_unlockable_medal(id)
      }.__merge(getBaseConfigMedal(id))).bindenv(this))
    } : null
  }

  function getBaseConfigMedal(id)
  {
    return {
      id = id
      unlocked = true
      tooltipId = ::g_tooltip.getIdUnlock(id, { showLocalState = isOwnStats, needTitle = false })
    }
  }

  function fillTitlesBlock(pl)
  {
    showSceneBtn("medals_block", false)
    showSceneBtn("titles_block", true)

    local titles = []
    foreach (id in pl.titles)
    {
      local titleUnlock = ::g_unlocks.getUnlockById(id)
      if (!titleUnlock || titleUnlock?.hidden)
        continue

      local locText = ::loc("title/" + id)
      titles.append({
        name = id
        text = locText
        lowerText = ::g_string.utf8ToLower(locText)
        tooltipId = ::g_tooltip.getIdUnlock(id, { showLocalState = isOwnStats, needTitle = false })
      })
    }
    titles.sort(@(a, b) a.lowerText <=> b.lowerText)

    local titlesTotal = titles.len()
    showSceneBtn("titles_empty", !titlesTotal)
    if (!titlesTotal)
      return

    local markup = ""
    local cols = 2
    local rows = ::ceil(titlesTotal * 1.0 / cols)
    for (local r = 0; r < rows; r++)
    {
      local rowData = []
      for (local c = 0; c < cols; c++)
        rowData.append(titles?[rows * c + r] ?? {})
      markup += ::buildTableRow("", rowData)
    }

    guiScene.replaceContentFromText(scene.findObject("titles_table"), markup, markup.len(), this)
  }

  function getPlayerStats()
  {
    return player
  }

  function onStatsTypeChange(obj)
  {
    if (!obj) return
    statsType = obj.getValue()? ::ETTI_VALUE_INHISORY : ::ETTI_VALUE_TOTAL
    ::saveLocalByAccount("leaderboards_type", statsType)
    fillLeaderboard()
  }

  function onLbModeSelect(obj)
  {
    if (!::checkObj(obj) || lbModesList == null)
      return

    local newLbMode = lbModesList?[obj.getValue()]
    if (newLbMode == null || lbMode == newLbMode)
      return

    lbMode = newLbMode
    guiScene.performDelayed(this, function()
    {
      if (isValid())
        fillLeaderboard()
    })
  }

  function fillStatistics()
  {
    if (!::checkObj(scene))
      return

    showSheetDiv("stats")
    fillAirStats()
  }

  function fillAirStats()
  {
    if (!::checkObj(scene))
      return

    if (!airStatsInited)
      return initAirStats()

    fillAirStatsScene(player.userstat)
  }

  function initAirStats()
  {
    countryStats = []
    foreach(country in shopCountriesList)
      countryStats.append(country)
    initAirStatsScene(player.userstat)
  }

  function initAirStatsScene(airStats)
  {
    local sObj = scene.findObject("stats-container")

    sObj.findObject("stats_loading").show(false)

    local modesObj = sObj.findObject("modes_list")
    local selDiff = null
    local selIdx = -1
    local view = { items = [] }
    foreach(diff in ::g_difficulty.types)
    {
      if (!diff.isAvailable())
        continue
      view.items.append({ text = diff.getLocName() })
      if (!selDiff || statsMode == diff.egdLowercaseName)
      {
        selDiff = diff
        selIdx = view.items.len() - 1
      }
    }
    statsMode = selDiff.egdLowercaseName

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(selIdx)

    fillUnitListCheckBoxes(sObj)
    fillCountriesCheckBoxes(sObj)

    local nestObj = scene.findObject("filter_nest")
    popupFilter.open(nestObj, onFilterCbChange.bindenv(this), getFiltersView())

    airStatsInited = true
    fillAirStats()
  }

  function fillUnitListCheckBoxes(sObj)
  {
    availableUTypes = {}
    local fillStatsUnits = unitStats.len() == 0

    foreach(unitType in unitTypes.types)
    {
      if (!unitType.isAvailable())
        continue

      local armyId = unitType.armyId
      local typeIdx = unitType.esUnitType
      availableUTypes[unitType.armyId] <- {
        id    = $"unit_{typeIdx}"
        idx   = typeIdx
        image = unitType.testFlightIcon
        text  = unitType.getArmyLocName()
      }
      if (fillStatsUnits)
        unitStats.append(armyId)
    }
  }

  function fillCountriesCheckBoxes(sObj)
  {
    availableCountries = {}
    foreach (idx, inst in shopCountriesList)
      availableCountries[inst] <- {
        id    = inst
        idx   = idx
        image = ::get_country_icon(inst)
        text  = ::loc(inst)
      }

    if (!countryStats)
      countryStats = [::get_profile_country_sq()]
  }

  function getFiltersView()
  {
    local res = []
    foreach (tName in ["country", "unit"])
    {
      local isUnitType = tName == "unit"
      local selectedArr = this[$"{tName}Stats"]
      local referenceArr = isUnitType ? availableUTypes : availableCountries
      local isAllSelected = true
      foreach (idx, inst in referenceArr)
        if (!::isInArray(idx, selectedArr))
        {
          isAllSelected = false
          break
        }

      local cbView = {
        id = "all_items"
        idx = -1
        image = $"#ui/gameuiskin#{isUnitType ? "all_unit_types" : "flag_all_nations"}.svg"
        text = ::loc($"all_{isUnitType ? "units" : "countries"}")
        value = isAllSelected
      }
      local view = { checkbox = [cbView]}
      foreach(idx, inst in referenceArr)
        view.checkbox.append(cbView.__merge({
          id = inst.id
          idx = inst.idx
          image = inst.image
          text = inst.text
          value = ::isInArray(idx, selectedArr)
        }))

      view.checkbox.sort(@(a,b) a.idx <=> b.idx)
      res.append(view)
    }

    return res
  }

  function onFilterCbChange(objId, tName, value)
  {
    local selectedArr = this[$"{tName}Stats"]
    local isUnitType = tName == "unit"
    local referenceArr = isUnitType ? availableUTypes : availableCountries
    local isAllObj = objId == "all_items"

    foreach (idx, inst in referenceArr)
    {
      if (!isAllObj && inst.id != objId)
        continue

      if (value)
        ::u.appendOnce(idx, selectedArr)
      else
        removeItemFromList(idx, selectedArr)
    }

    fillAirStats()
  }

  function fillAirStatsScene(airStats)
  {
    if (!::checkObj(scene))
      return

    airStatsList = []
    local checkList = []
    local typeName = "total"
    local modeName = statsMode
    if ((modeName in airStats) && (typeName in airStats[modeName]))
      checkList = airStats[modeName][typeName]
    foreach(item in checkList)
    {
      local air = ::getAircraftByName(item.name)
      local unitTypeShopId = ::get_army_id_by_es_unit_type(::get_es_unit_type(air))
      if (!::isInArray(unitTypeShopId, unitStats))
          continue
      if (!("country" in item))
      {
        item.country <- air? air.shopCountry : ""
        item.rank <- air? air.rank : 0
      }
      if ( ! ("locName" in item))
        item.locName <- air ? ::getUnitName(air, true) : ""
      if (::isInArray(item.country, countryStats))
        airStatsList.append(item)
    }

    if (statsSortBy=="")
      statsSortBy = "victories"

    local sortBy = statsSortBy
    local sortReverse = statsSortReverse == (sortBy != "locName")
    airStatsList.sort(function(a,b) {
      local res = b[sortBy] <=> a[sortBy]
      if (res != 0)
        return sortReverse ? -res : res
      return a.locName <=> b.locName || a.name <=> b.name
    })

    curStatsPage = 0
    updateStatPage()
  }

  function initStatsPerPage()
  {
    if (statsPerPage > 0)
      return

    local listObj = scene.findObject("airs_stats_table")
    local size = listObj.getSize()
    local rowsHeigt = size[1] -guiScene.calcString("@leaderboardHeaderHeight", null)
    statsPerPage =   ::max(1, (rowsHeigt / guiScene.calcString("@leaderboardTrHeight",  null)).tointeger())
  }

  function updateStatPage()
  {
    if (!airStatsList)
      return

    initStatsPerPage()

    local data = ""
    local posWidth = "0.05@scrn_tgt"
    local rcWidth = "0.04@scrn_tgt"
    local nameWidth = "0.2@scrn_tgt"
    local headerRow = [
      { width=posWidth }
      { id="rank", width=rcWidth, text="#sm_rank", tdalign="split", cellType="splitRight", callback = "onStatsCategory", active = statsSortBy=="rank" }
      { id="rank", width=rcWidth, cellType="splitLeft", callback = "onStatsCategory" }
      { id="locName", width=rcWidth, cellType="splitRight", callback = "onStatsCategory" }
      { id="locName", width=nameWidth, text="#options/unit", tdalign="left", cellType="splitLeft", callback = "onStatsCategory", active = statsSortBy=="locName" }
    ]
    foreach(item in ::air_stats_list)
    {
      if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
        continue

      if (isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        headerRow.append({
          id = item.id
          image = "#ui/gameuiskin#" + (("icon" in item)? item.icon : "lb_"+item.id) + ".svg"
          tooltip = ("text" in item)? "#" + item.text : "#multiplayer/"+item.id
          callback = "onStatsCategory"
          active = statsSortBy==item.id
          needText = false
        })
    }
    data += buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'")

    local tooltips = {}
    local fromIdx = curStatsPage*statsPerPage
    local toIdx = (curStatsPage+1)*statsPerPage-1
    if (toIdx >= airStatsList.len()) toIdx = airStatsList.len()-1

    for(local idx = fromIdx; idx <= toIdx; idx++)
    {
      local airData = airStatsList[idx]
      local unitTooltipId = UNIT.getTooltipId(airData.name)

      local rowName = "row_"+idx
      local rowData = [
        { text = (idx+1).tostring(), width=posWidth }
        { id="rank", width=rcWidth, text = airData.rank.tostring(), tdalign="right", cellType="splitRight", active = statsSortBy=="rank" }
        { id="country", width=rcWidth, image=::get_country_icon(airData.country), cellType="splitLeft", needText = false }
        {
          id="unit",
          width=rcWidth,
          image=getUnitClassIco(airData.name),
          tooltipId = unitTooltipId,
          cellType="splitRight",
          needText = false
        }
        { id="name", text = ::getUnitName(airData.name, true), tdalign="left", active = statsSortBy=="name", cellType="splitLeft", tooltipId = unitTooltipId }
      ]
      foreach(item in ::air_stats_list)
      {
        if ("reqFeature" in item && !hasAllFeatures(item.reqFeature))
          continue

        if (isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        {
          local cell = ::getLbItemCell(item.id, airData[item.id], item.type)
          cell.active <- statsSortBy == item.id
          if ("tooltip" in cell)
          {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][item.id] <- cell.rawdelete("tooltip")
          }
          rowData.append(cell)
        }
      }
      data += buildTableRow(rowName, rowData, idx%2==0)
    }

    local tblObj = scene.findObject("airs_stats_table")
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    foreach(rowName, row in tooltips)
    {
      local rowObj = tblObj.findObject(rowName)
      if (rowObj)
        foreach(name, value in row)
          rowObj.findObject(name).tooltip = value
    }
    local nestObj = scene.findObject("paginator_place")
    ::generatePaginator(nestObj, this, curStatsPage, ::floor((airStatsList.len() - 1)/statsPerPage))
    updateButtons()
  }

  function goToPage(obj)
  {
    curStatsPage = obj.to_page.tointeger()
    updateStatPage()
  }

  function checkLbRowVisibility(row)
  {
    return ::leaderboardModel.checkLbRowVisibility(row, this)
  }

  function fillLeaderboard()
  {
    local stats = getPlayerStats()
    if (!stats || !("leaderboard" in stats) || !stats.leaderboard.len())
      return

    local typeProfileObj = scene.findObject("stats_type_profile")
    if (::checkObj(typeProfileObj))
    {
      typeProfileObj.show(true)
      typeProfileObj.setValue(statsType == ::ETTI_VALUE_INHISORY)
    }

    local tblObj = scene.findObject("profile_leaderboard")
    local rowIdx = 0
    local data = ""
    local tooltips = {}

    //add header row
    local headerRow = [""]
    foreach(lbCategory in ::leaderboards_list)
      if (checkLbRowVisibility(lbCategory))
        headerRow.append({
          id = lbCategory.id
          image = lbCategory.headerImage
          tooltip = lbCategory.headerTooltip
          active = true
          needText = false
        })

    data = buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'")

    local rows = [
      {
        text = "#mainmenu/btnLeaderboards"
        showLbPlaces = false
      }
      {
        text = "#multiplayer/place"
        showLbPlaces = true
      }
    ]

    local valueFieldName = (statsType == ::ETTI_VALUE_TOTAL)
                           ? LEADERBOARD_VALUE_TOTAL
                           : LEADERBOARD_VALUE_INHISTORY
    local lb = ::getTblValue(valueFieldName, ::getTblValue(lbMode, stats.leaderboard), {})
    local standartRow = {}

    foreach (idx, fieldTbl in lb)
    {
      standartRow[idx] <- ::getTblValue(valueFieldName, fieldTbl, -1)
    }

    foreach (row in rows)
    {
      local rowName = "row_" + rowIdx
      local rowData = [{ text = row.text, tdalign="left" }]
      local res = {}

      foreach(lbCategory in ::leaderboards_list)
        if (checkLbRowVisibility(lbCategory))
        {
          if (lbCategory.field in lb)
          {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(standartRow[lbCategory.field], standartRow)
            else
            {
              local value = (lb[lbCategory.field].idx < 0) ? -1 : lb[lbCategory.field].idx + 1
              res = lbCategory.getItemCell(value, null, false, ::g_lb_data_type.PLACE)
            }
          }
          else
          {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(lbCategory.lbDataType == ::g_lb_data_type.PERCENT ? -1 : 0)
            else
              res = lbCategory.getItemCell(-1, null, false, ::g_lb_data_type.PLACE)
          }

          if ("tooltip" in res)
          {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][lbCategory.id] <- res.rawdelete("tooltip")
          }

          rowData.append(res)
        }

      rowIdx++
      data += buildTableRow(rowName, rowData, rowIdx % 2 == 0, "")
    }
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)

    foreach(rowName, row in tooltips)
      foreach(name, value in row)
        tblObj.findObject(rowName).findObject(name).tooltip = value
  }

  function onChangePilotIcon(obj) {}
  function openChooseTitleWnd() {}

  function getCurSheet()
  {
    local obj = scene.findObject("profile_sheet_list")
    local sheetIdx = obj.getValue()
    if ((sheetIdx < 0) || (sheetIdx >= obj.childrenCount()))
      return ""

    return obj.getChild(sheetIdx).id
  }

  function initLeaderboardModes()
  {
    lbMode      = ""
    lbModesList = []

    local data  = ""

    foreach(idx, mode in ::leaderboard_modes)
    {
      local diffCode = ::getTblValue("diffCode", mode)
      if (!::g_difficulty.isDiffCodeAvailable(diffCode, ::GM_DOMINATION))
        continue
      local reqFeature = ::getTblValue("reqFeature", mode)
      if (!hasAllFeatures(reqFeature))
        continue

      lbModesList.append(mode.mode)
      data += format("option {text:t='%s'}", mode.text)
    }

    local modesObj = showSceneBtn("leaderboard_modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(0)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    local hasFeatureFriends = ::has_feature("Friends")

    local contact = ::getContact(player?.uid, player.name)
    local isMe = contact?.isMe() ?? false
    local canBan = isMe? false : (::myself_can_devoice() || ::myself_can_ban())
    local isFriend = contact?.isInFriendGroup() ?? false
    local isBlock = contact?.isInBlockGroup() ?? false

    local isPS4Player = isPlayerFromPS4(player.name)
    local isXBoxOnePlayer = isXBoxPlayerName(player.name)
    local canBlock = !isPlatformXboxOne || !isXBoxOnePlayer
    local canInteractCC = canInteractCrossConsole(player.name)

    local sheet = getCurSheet()
    local showStatBar = infoReady && sheet=="Statistics"
    local showProfBar = infoReady && !showStatBar

    ::showBtnTable(scene, {
      paginator_place = showStatBar && (airStatsList != null) && (airStatsList.len() > statsPerPage)
      btn_friendAdd = showProfBar && hasFeatureFriends && canInteractCC && !isMe && !isFriend && !isBlock
      btn_friendRemove = showProfBar && hasFeatureFriends && isFriend && (contact?.isInFriendlist() ?? false)
      btn_blacklistAdd = showProfBar && hasFeatureFriends && !isMe && !isFriend && !isBlock && canBlock && !isPS4Player
      btn_blacklistRemove = showProfBar && hasFeatureFriends && isBlock && canBlock && !isPS4Player
      btn_moderatorBan = showProfBar && ::is_myself_anyof_moderators() && canBan
      btn_complain = showProfBar && !isMe
      btn_achievements_url = showProfBar && ::has_feature("AchievementsUrl")
        && ::has_feature("AllowExternalLink") && !::is_vendor_tencent()
    })
  }

  function onBlacklistBan()
  {
    local clanTag = ::getTblValue("clanTag", player, "")
    local playerName = ::getTblValue("name", player, "")
    local userId = ::getTblValue("uid", player, "")

    ::gui_modal_ban({ name = playerName, uid = userId, clanTag = clanTag })
  }

  function onFriendAdd()
  {
    ::editContactMsgBox(player, ::EPL_FRIENDLIST, true)
  }

  function onFriendRemove()
  {
    ::editContactMsgBox(player, ::EPL_FRIENDLIST, false)
  }

  function onBlacklistAdd()
  {
    ::editContactMsgBox(player, ::EPL_BLOCKLIST, true)
  }

  function onBlacklistRemove()
  {
    ::editContactMsgBox(player, ::EPL_BLOCKLIST, false)
  }

  function onComplain()
  {
    if (infoReady && ("uid" in player))
      ::gui_modal_complain(player)
  }

  function onOpenXboxProfile()
  {
    ::xbox_show_profile_card(curPlayerExternalIds?.xboxId ?? "")
  }

  function onOpenPSNProfile() {
    local psnId = curPlayerExternalIds?.psnId ?? ""
    if (psnId == "")
      return

    psnSocial?.open_player_profile(
      psnId.tointeger(),
      psnSocial.PlayerAction.DISPLAY,
      "",
      {}
    )
  }

  function removeItemFromList(value, list)
  {
    local idx = list.findindex(@(v) v == value)
    if (idx != null)
      list.remove(idx)
  }

  function onStatsCategory(obj)
  {
    if (!obj) return
    local value = obj.id
    if (statsSortBy==value)
      statsSortReverse = !statsSortReverse
    else
    {
      statsSortBy = value
      statsSortReverse = false
    }
    guiScene.performDelayed(this, function() { fillAirStats() })
  }

  function onOpenAchievementsUrl()
  {
    openUrl(::loc("url/achievements",
        { appId = ::WT_APPID, name = player.name}),
      false, false, "profile_page")
  }
}
