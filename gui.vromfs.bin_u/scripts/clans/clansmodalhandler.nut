let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { clearBorderSymbols } = require("%sqstd/string.nut")
let { getClanTableSortFields, getClanTableFieldsByPage, getClanTableHelpLinksByPage } = require("%scripts/clans/clanTablesConfig.nut")
let time = require("%scripts/time.nut")
let clanContextMenu = require("%scripts/clans/clanContextMenu.nut")

// how many top places rewards are displayed in clans list window
let CLAN_SEASONS_TOP_PLACES_REWARD_PREVIEW = 3
let CLAN_LEADERBOARD_FILTER_ID = "clan/leaderboard_filter"

local leaderboardFilterArray = [
  {
    id    = "filterOpen"
    locId = "clan/leaderboard/filter/open"
  },
  {
    id    = "filterNotFull"
    locId = "clan/leaderboard/filter/notFull"
  },
  {
    id    = "filterAutoAccept"
    locId = "clan/leaderboard/filter/autoAccept"
  }
]

::gui_handlers.ClansModalHandler <- class extends ::gui_handlers.clanPageModal
{
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/clans/ClansModal.blk"
  pages          = ["clans_search","clans_leaderboards", "my_clan"]
  startPage      = ""
  curPage        = ""
  curPageObj     = null
  tabsObj        = null

  isClanInfo     = false
  isSearchMode   = false
  searchRequest  = ""

  clanLbInited   = false

  myClanInited   = false
  myClanLbData   = null

  clansPerPage   = -1
  requestingClansCount = -1
  isLastPage     = false
  clansLbSortByPage    = null
  curClanLbPage  = 0
  curPageData    = null

  clanByRow      = null
  curClanId      = -1
  lastHoveredDataIdx = -1

  rowsTexts      = null
  tooltips       = null

  filterMask = null

  function initScreen()
  {
    clanByRow = []
    rowsTexts = {}
    tooltips  = {}

    if (startPage == "")
      startPage = (::clan_get_my_clan_id() == "-1")? "clans_search" : "my_clan"

    curWwCategory = ::g_lb_category.EVENTS_PERSONAL_ELO
    initSearchBox()
    initLbTable()
    initLeaderboardFilter()
    initTabs()

    curMode = getCurDMode()
  }

  function initSearchBox() {
    let searchObj = scene.findObject("filter_edit_box")
    searchObj["max-len"] ="32"
    searchObj["char-mask"] = ::g_clans.isNonLatinCharsAllowedInClanName()
      ? null : "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _-"
  }

  function initTabs()
  {
    let view = { tabs = [] }
    local pageIdx = 0
    foreach(idx, sheet in pages)
    {
      view.tabs.append({
        id = sheet
        tabName = "#clan/" + sheet
        navImagesText = ::get_navigation_images_text(idx, pages.len())
      })
      if (startPage == sheet)
        pageIdx = idx
    }

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    tabsObj = scene.findObject("clans_sheet_list")
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    curPage = pages[pageIdx]
    tabsObj.setValue(pageIdx)
  }

  function showCurPage()
  {
    if(curPage == "my_clan")
      showMyClanPage()
    else
      enableAdminMode(false)

    if(curPage == "clans_leaderboards" || curPage == "clans_search")
      showLb()

    updateAdminModeSwitch()
  }

  function onSheetChange()
  {
    clearPage()
    curPage = pages[tabsObj.getValue()]
    isClanInfo = curPage == "my_clan"
    showCurPage()
  }

  function clearPage()
  {
    if(curPageObj == null || !curPageObj.isValid())
      return

    curPageObj.show(false)
    curPageObj.enable(false)
  }

  function initClanLeaderboards()
  {
    clanLbInited = true
    curPageData = null
    curClanLbPage = 0
    clanByRow = []
    curClanId = null
    isLastPage = false
    clansLbSortByPage = getClanTableSortFields()
  }

  function calculateRowNumber()
  {
    guiScene.applyPendingChanges(false)
    let reserveY = "0.05sh"
      + ((::my_clan_info != null && curPage == "clans_leaderboards") ? " + 1.7@leaderboardTrHeight" : "")
    let clanLboard = scene.findObject("clan_lboard_table")
    clansPerPage = ::g_dagui_utils.countSizeInItems(clanLboard, 1, "@leaderboardTrHeight", 0, 0, 0, reserveY).itemsCountY
    requestingClansCount = clansPerPage + 1
  }

  function initMyClanPage()
  {
    myClanInited = true
    setDefaultSort()
    let myClanPages = {
      clan_info_not_in_clan = false
      clan_container = false
    }
    foreach(pageId, status in myClanPages)
      ::showBtn(pageId, status, scene)


    if(::my_clan_info != null)
    {
      clanIdStrReq = ::my_clan_info.id
      reinitClanWindow()
    }
  }

  function afterClanLeave() {} //page will update after clan info update

  function showLb()
  {
    curPageObj = scene.findObject("clans_list_content")
    if(!curPageObj)
      return goBack()
    curPageObj.show(true)
    curPageObj.enable(true)

    let isLeaderboardPage = curPage == "clans_leaderboards"
    ::showBtnTable(scene, {
      clans_battle_season         = isLeaderboardPage
      modes_list                  = isLeaderboardPage
      leaderboard_filter_place    = !isLeaderboardPage
    })

    if(!clanLbInited ||
       (::my_clan_info == null && myClanLbData != null) ||
       (::my_clan_info != null && myClanLbData == null))
      initClanLeaderboards()

    if (isLeaderboardPage)
      fillModeListBox(curPageObj, getCurDMode(), ::get_show_in_squadron_statistics)
    else
    {
      curClanLbPage = 0
      calculateRowNumber()
      requestClansLbData()
    }
  }

  function onStatsModeChange(obj)
  {
    if (!::checkObj(obj))
      return

    let diffCode = obj.getChild(obj.getValue()).holderDiffCode.tointeger()
    let diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
    if(!::get_show_in_squadron_statistics(diff))
      return

    curMode = diffCode
    setCurDMode(curMode)
    fillClanReward()
    calculateRowNumber()
    requestClansLbData(true)
  }

  function showMyClanPage(forceReinit = null)
  {
    if(!myClanInited || forceReinit)
      initMyClanPage()

    curPageObj = scene.findObject(::my_clan_info ? "clan_container" : "clan_info_not_in_clan")
    if(!curPageObj)
      return

    curPageObj.show(true)
    curPageObj.enable(true)

    if(!::my_clan_info)
    {
      local requestSent = false
      if(::clan_get_requested_clan_id() != "-1" && ::clan_get_my_clan_name() != "")
      {
        requestSent = true
        curPageObj.findObject("req_clan_name").setValue(::clan_get_my_clan_tag() + " " + ::clan_get_my_clan_name())
      }
      curPageObj.findObject("reques_to_clan_sent").show(requestSent)
      curPageObj.findObject("how_to_get_membership").show(!requestSent)
    }
    else {
      clanData = ::my_clan_info
      fillModeListBox(curPageObj, getCurDMode(),
        ::get_show_in_squadron_statistics, getAdditionalTabsArray())
    }
  }

  function getClansLbFieldName(lbCategory = null, mode = null)
  {
    let actualCategory = lbCategory || clansLbSortByPage[curPage]
    let field = actualCategory?.field ?? actualCategory.id
    local fieldName = ::u.isFunction(field) ? field() : field
    if (actualCategory.byDifficulty)
      fieldName += ::g_difficulty.getDifficultyByDiffCode(mode ?? curMode).clanDataEnding
    return fieldName
  }

  function getClanLBPage(seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null)
  {
    let requestBlk = ::DataBlock()
    requestBlk["start"] <- curClanLbPage * clansPerPage
    requestBlk["count"] <- requestingClansCount
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- getClansLbFieldName()
    requestBlk["shortMode"] <- "on"
    if (curPage == "clans_search")
      foreach(idx, filter in leaderboardFilterArray)
        if ((1 << idx) & filterMask)
          requestBlk[filter.id] <- "on"

    return ::g_tasker.charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function requestClanLBPosition(fieldName, seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null)
  {
    let requestBlk= ::DataBlock()
    requestBlk["clanId"] <- ::clan_get_my_clan_id()
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- fieldName
    requestBlk["shortMode"] <- "on"
    return ::g_tasker.charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function findClanByPrefix(prefix, onSuccessCb = null, onErrorCb = null)
  {
    let requestBlk = ::DataBlock()
    requestBlk["namePrefix"] <- prefix
    requestBlk["tagPrefix"] <- prefix
    requestBlk["start"] <- curClanLbPage * clansPerPage
    requestBlk["count"] <- requestingClansCount
    requestBlk["shortMode"] <- "on"
    if (curPage == "clans_search")
      foreach(idx, filter in leaderboardFilterArray)
        if ((1 << idx) & filterMask)
          requestBlk[filter.id] <- "on"

    return ::g_tasker.charRequestBlk("cln_clan_find_by_prefix", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function requestClansLbData(updateMyClanRow = false, seasonOrdinalNumber = -1)
  {
    showEmptySearchResult(false)
    if ((::clan_get_my_clan_id() == "-1" || curPage == "clans_search")
      && myClanLbData != null)
      myClanLbData = null
    if (updateMyClanRow && ::clan_get_my_clan_id() != "-1")
    {
      let requestPage = curPage
      let cbSuccess = ::Callback((@(seasonOrdinalNumber) function(myClanRowBlk) {
                                      if (requestPage != curPage)
                                        return

                                      let myClanId = ::clan_get_my_clan_id()
                                      local found = false
                                      foreach(row in myClanRowBlk % "clan")
                                        if(row?._id == myClanId)
                                        {
                                          myClanLbData = ::buildTableFromBlk(row)
                                          myClanLbData.astat <- ::buildTableFromBlk(row?.astat)
                                          found = true
                                          break
                                        }
                                      if(!found)
                                        myClanLbData = null
                                      requestLbData(seasonOrdinalNumber)
                                    })(seasonOrdinalNumber), this)

      requestClanLBPosition(getClansLbFieldName(), seasonOrdinalNumber, cbSuccess)
    }
    else
      requestLbData(seasonOrdinalNumber)
  }

  function requestLbData(seasonOrdinalNumber)
  {
    let requestPage = curPage
    let cbSuccess = ::Callback(function(data)
                                 {
                                   if (requestPage == curPage)
                                     lbDataCb(data)
                                 }, this)

    if (isSearchMode && searchRequest.len() > 0)
      findClanByPrefix(searchRequest, cbSuccess)
    else
      getClanLBPage(seasonOrdinalNumber, cbSuccess)
  }

  function onFilterEditBoxActivate()
  {
    curClanLbPage = 0
    searchRequest = scene.findObject("filter_edit_box").getValue()
    searchRequest = searchRequest.len() > 0 ? clearBorderSymbols(searchRequest, [" "]) : ""
    isSearchMode = searchRequest.len() > 0
    showEmptySearchResult(false)
    if(isSearchMode)
      requestLbData(-1)
    else
      return requestClansLbData()
  }

  function onBackToClanlist()
  {
    curClanLbPage = 0
    searchRequest = ""
    isSearchMode = false
    requestClansLbData()
  }

  function lbDataCb(lbBlk)
  {
    if (!::checkObj(scene))
      return

    let lbPageObj = scene.findObject("clans_list_content")
    if (!::checkObj(lbPageObj))
      return

    ::showBtn("btn_back_to_clanlist", isSearchMode, lbPageObj)

    if (isSearchMode && !("clan" in lbBlk))
    {
      showEmptySearchResult(true)
      clanByRow.clear()
      curClanId = null
      updateButtons()
      return
    }

    printLeaderboards(lbBlk)

    let paginatorObj = lbPageObj.findObject("mid_nav_bar")
    let myPage = (myClanLbData != null && "pos" in myClanLbData) ? ::floor(myClanLbData.pos / clansPerPage) : null
    generatePaginator(paginatorObj, this, curClanLbPage, curClanLbPage + (isLastPage? 0 : 1), myPage)
  }

  function showEmptySearchResult(show)
  {
    scene.findObject("search_status").display = show ? "show" : "hide"
    let lbTableObj = scene.findObject("clan_lboard_table")
    guiScene.replaceContentFromText(lbTableObj, "", 0, this)
  }

  function printLeaderboards(clanLbBlk)
  {
    let lbPageObj = scene.findObject("clans_list_content")
    if (!::checkObj(lbPageObj))
      return

    local data = []
    rowsTexts = {}
    tooltips = {}
    clanByRow.clear()
    curClanId = null
    isLastPage = true
    foreach(name, rowBlk in clanLbBlk % "clan")
    {
      if (typeof(rowBlk) != "instance")
        continue

      if (clanByRow.len() >= clansPerPage)
      {
        isLastPage = false
        break
      }

      // Warning! getFilteredClanData() actualy mutates its parameter and returns it back
      let rowBlkFiltered = ::getFilteredClanData(rowBlk)
      data.append(generateRowTableData(rowBlkFiltered, clanByRow.len()))
      clanByRow.append(rowBlkFiltered._id.tostring())
    }

    for (local i = clanByRow.len(); i < clansPerPage; i++)
    {
      data.append(::buildTableRow($"row_{i}", [], i % 2 == 1, "inactive:t='yes';"))
      clanByRow.append(null)
    }

    if(myClanLbData != null)
    {
      data.append(::buildTableRow($"row_{clanByRow.len()}", ["..."], null,
        "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;';"))
      clanByRow.append(null)
      myClanLbData = ::getFilteredClanData(myClanLbData)
      data.append(generateRowTableData(myClanLbData, clanByRow.len()))
      clanByRow.append(myClanLbData._id.tostring())
    }
    let headerRow = [{text = "#multiplayer/place", width = "0.1@sf"}, {text = ""}, { text = "#clan/clan_name", tdalign = "left",  width = "@clanNameTableWidth"}]

    let fieldList = getClanTableFieldsByPage(curPage)
    foreach(item in fieldList)
    {
      if (!isColForDisplay(item))
        continue

      let block = {
        id = item.id
        image = item.getIcon(getCurDMode())
        tooltip = item.tooltip
        active = clansLbSortByPage[curPage].id == item.id
        text = ::loc(item?.text ?? "")
        needText = (item?.text ?? "") != ""
      }
      if(!("field" in item) || !item.sort)
        block.rawParam <- "no-hover:t='yes';"
      if(item.sort)
        block.callback <- "onCategory"
      if(item?.width != null)
        block.width <- item.width
      headerRow.append(block)
    }
    data.insert(0, ::buildTableRow("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'"))
    data = "".join(data)

    guiScene.setUpdatesEnabled(false, false)
    let lbTableObj = lbPageObj.findObject("clan_lboard_table")
    guiScene.replaceContentFromText(lbTableObj, data, data.len(), this)
    foreach(rowName, row in rowsTexts)
      foreach(name, value in row)
        lbTableObj.findObject(rowName).findObject(name).setValue(value)
    foreach(rowName, row in tooltips)
      foreach(name, value in row)
        lbTableObj.findObject(rowName).findObject(name).tooltip = value
    guiScene.setUpdatesEnabled(true, true)

    if (curPage == "clans_leaderboards" || curPage == "clans_search")
    {
      lbTableObj.setValue(clanByRow.len() ? 1 : -1)
      onSelectClan(lbTableObj)
    }
  }

  function generateRowTableData(rowBlk, rowIdx)
  {
    let slogan = rowBlk.slogan == "" ? "" : rowBlk.slogan == " " ? "" : rowBlk.slogan
    let desc = rowBlk.desc == "" ? "" : rowBlk.desc == " " ? "" : rowBlk.desc
    let rowName = "row_" + rowIdx

    let clanType = ::g_clan_type.getTypeByName(::getTblValue("type", rowBlk, ""))
    let highlightRow = myClanLbData != null && myClanLbData._id == rowBlk._id ? true : false
    rowsTexts[rowName] <- {
      txt_name = colorizeClanText(clanType, rowBlk.name, highlightRow)
      txt_tag = colorizeClanText(clanType, rowBlk.tag, highlightRow)
    }
    if (slogan != "" || desc != "")
      tooltips[rowName] <- { name = "\n".concat(slogan, desc) }
    let rowData = [
      rowBlk.pos + 1
      {
        id = "tag"
        tdalign = "right"
        textType = "textareaNoTab"
      }
      {
        id = "name"
        tdalign = "left"
        textType = "textareaNoTab"
      }
    ]
    let fieldList = getClanTableFieldsByPage(curPage)
    foreach(item in fieldList)
      if (isColForDisplay(item))
        rowData.append(getItemCell(item, rowBlk, rowName))

    ::dagor.assertf(typeof(rowBlk._id) == "string", "leaderboards receive _id type " + typeof(rowBlk._id) + ", instead of string on clan_request_page_of_leaderboard")
    return buildTableRow(rowName, rowData, rowIdx % 2 != 0, highlightRow ? "mainPlayer:t='yes';" : "")
  }

  function colorizeClanText(clanType, clanText, isMainPlayer)
  {
    return isMainPlayer ? clanText : ::colorize(clanType.color, clanText)
  }

  function getItemCell(item, rowBlk, rowName)
  {
    let itemId = getClansLbFieldName(item)

    if(!rowBlk?.astat)
      rowBlk.astat = ::DataBlock()
    let value = itemId == "members_cnt" ? rowBlk?[itemId] ?? 0
      : itemId == "slogan" ? ::g_chat.filterMessageText(rowBlk?[itemId] ?? "", false)
      : itemId == "fits_requirements" ? ""
      : rowBlk.astat?[itemId] ?? 0

    let res = ::getLbItemCell(item.id, value, item.type)
    res.active <- clansLbSortByPage[curPage].id == item.id
    if(item?.width != null)
    {
      res.width <- item.width
      res.autoScrollText <- item?.autoScrollText ?? false
      res.tooltip <- item?.autoScrollText ? res.text : ""
    }
    if ("getCellImage" in item)
    {
      res.image <- item.getCellImage(rowBlk)
      res.imageRawParams <- "left:t='0.5pw-0.5w'"
      res.needText <- false
    }
    if ("getCellTooltipText" in item)
      res.tooltip <- item.getCellTooltipText(rowBlk)
    if ("tooltip" in res)
    {
      if (!(rowName in tooltips))
        tooltips[rowName] <- {}
      tooltips[rowName][item.id] <- res.rawdelete("tooltip")
    }
    return res
  }

  function isColForDisplay(column)
  {
    let colName = column.id
    if (curPage != "clans_leaderboards" || colName.len() < ::ranked_column_prefix.len()
      || colName.slice(0, ::ranked_column_prefix.len()) != ::ranked_column_prefix)
    {
      let showByFeature = ::getTblValue("showByFeature", column, null)
      if (showByFeature != null && !::has_feature(showByFeature))
        return false

      return true
    }

    return colName == ::ranked_column_prefix
  }

  function onCategory(obj)
  {
    if (!::check_obj(obj))
      return

    if (isClanInfo && isWorldWarMode)
    {
      if (curWwCategory.id != obj.id)
      {
        curWwCategory = ::g_lb_category.getTypeById(obj.id)
        fillClanWwMemberList()
      }
      return
    }

    let fieldList = getClanTableFieldsByPage(curPage)
    foreach(idx, category in fieldList)
      if (obj.id == category.id)
      {
        clansLbSortByPage[curPage] = category
        break
      }
    curClanLbPage = 0
    requestClansLbData(curPage != "clans_search")
  }

  function onFilterEditBoxCancel(obj)
  {
    if(obj.getValue().len() > 0)
      obj.setValue("")
    else
      goBack();
  }

  function onFilterEditBoxChangeValue() {}

  function onSelectClan(obj)
  {
    if (::show_console_buttons)
      return
    if (!::check_obj(obj))
      return

    let dataIdx = obj.getValue() - 1 // skiping header row
    onSelectedClanIdx(dataIdx)
  }

  function onRowHoverClan(obj)
  {
    if (!::show_console_buttons)
      return
    if (!::check_obj(obj))
      return

    let isHover = obj.isHovered()
    let dataIdx = ::to_integer_safe(::g_string.cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == lastHoveredDataIdx))
     return

    lastHoveredDataIdx = isHover ? dataIdx : -1
    onSelectedClanIdx(lastHoveredDataIdx)
  }

  function onSelectedClanIdx(dataIdx)
  {
    curClanId = clanByRow?[dataIdx]
    updateButtons()
  }

  function updateButtons()
  {
    ::showBtnTable(curPageObj, {
      btn_clan_info       = curClanId != null
      btn_clan_actions    = curClanId != null && ::show_console_buttons
      btn_membership_req  = curClanId != null && !::is_in_clan() && ::clan_get_requested_clan_id() != curClanId
      mid_nav_bar         = clanByRow.len() > 0
    })

    let reqButton = curPageObj.findObject("btn_membership_req")
    if(::checkObj(reqButton))
    {
      local opened = true
      if(curPageData)
        foreach(rowBlk in curPageData % "clan")
          if(rowBlk._id == clan)
          {
            opened = rowBlk.status != "closed"
            break
          }
      reqButton.enable(opened)
      reqButton.tooltip = opened ? "" : ::loc("clan/was_closed")
    }
  }

  function onEventClanMembershipRequested(p)
  {
    updateButtons()
  }

  function onEventClanMembershipCanceled(p)
  {
    showMyClanPage()
  }

  function onClanInfo()
  {
    if (curClanId != null)
      showClanPage(curClanId, "", "")
  }

  function onSelectClansList(obj)
  {
    guiScene.performDelayed(this, function() {
      if (::check_obj(scene))
        onSelectClan(scene.findObject("clan_lboard_table"))
    })
  }

  function goToPage(obj)
  {
    curClanLbPage = obj.to_page.tointeger()
    requestClansLbData()
  }

  function onCreateClanWnd()
  {
    if (::has_feature("Clans")){
      if (!::ps4_is_ugc_enabled())
        ::ps4_show_ugc_restriction()
      else
        ::gui_modal_new_clan()
    }
    else
      msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onEventClanInfoUpdate(params = {})
  {
    initMyClanPage()
    onSheetChange()
  }

  function onClanRclick(position = null)
  {
    if (!curClanId)
      return

    let menu = clanContextMenu.getClanActions(curClanId)
    ::gui_right_click_menu(menu, this, position)
  }

  function onCancelRequest()
  {
    msgBox("cancel_request_question",
           ::loc("clan/cancel_request_question"),
           [
             ["ok", @() ::g_clans.cancelMembership()],
             ["cancel", @() null]
           ],
           "ok",
           { cancel_fn = @() null }
          )
  }

  function fillClanReward()
  {
    let objFrameBlock = scene.findObject("clan_battle_season_frame_block")
    if (!::checkObj(objFrameBlock))
      return

    //Don't show any rewards if seasons disabled
    let seasonsEnabled = ::g_clan_seasons.isEnabled()
    objFrameBlock.show(seasonsEnabled)
    scene.findObject("clan_battle_season_coming_soon").show(!seasonsEnabled)
    if (!seasonsEnabled)
    {
      //fallback to older seasons version
      fillClanReward_old()
      return
    }

    let showAttributes = ::has_feature("ClanSeasonAttributes")

    let seasonName = ::g_clan_seasons.getSeasonName()
    let diff = ::g_difficulty.getDifficultyByDiffCode(getCurDMode())

    //Fill current season name
    let objSeasonName = scene.findObject("clan_battle_season_name")
    if (::checkObj(objSeasonName) && showAttributes)
      objSeasonName.setValue(::loc("clan/battle_season/title") + ::loc("ui/colon") + ::colorize("userlogColoredText", seasonName))

    //Fill season logo medal
    let objTopMedal = scene.findObject("clan_battle_season_logo_medal")
    if (::checkObj(objTopMedal) && showAttributes)
    {
      objTopMedal.show(true)
      let iconStyle = "clan_season_logo_" + diff.egdLowercaseName
      let iconParams = { season_title = { text = seasonName } }
      ::LayersIcon.replaceIcon(objTopMedal, iconStyle, null, null, null, iconParams)
    }

    //Fill current seasons end date
    let objEndsDuel = scene.findObject("clan_battle_season_ends")
    if (::checkObj(objEndsDuel))
    {
      let endDateText = ::loc("clan/battle_season/ends") + ::loc("ui/colon") + " " + ::g_clan_seasons.getSeasonEndDate()
      objEndsDuel.setValue(endDateText)
    }

    //Fill top rewards
    let clanTableObj = scene.findObject("clan_battle_season_reward_table")
    if (::checkObj(clanTableObj))
    {
      let rewards = ::g_clan_seasons.getFirstPrizePlacesRewards(
        CLAN_SEASONS_TOP_PLACES_REWARD_PREVIEW,
        diff
      )
      local rowBlock = ""
      let rowData = []
      foreach (reward in rewards)
      {
        let placeText = (reward.place >= 1 && reward.place <= 3) ?
          ::loc("clan/season_award/place/place" + reward.place) :
          ::loc("clan/season_award/place/placeN", { placeNum = reward.place })

        rowData.append({
          text = placeText,
          active = false,
          tdalign ="right"
        })

        let rewardText = ::Cost(0, reward.gold).tostring()
        rowData.append({
          needText = false,
          rawParam = @"text {
            text-align:t='right';
            text:t='" + rewardText + @"';
            size:t='pw, ph';
            margin-left:t='1@blockInterval'
            style:t='re-type:textarea;behaviour:textarea;';
          }",
          active = false
        })
      }
      rowBlock += ::buildTableRowNoPad("row_0", rowData, null, "")
      guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
    }

    let objInfoBtn = scene.findObject("clan_battle_season_info_btn")
    if (::checkObj(objInfoBtn) && showAttributes)
      objInfoBtn.show(true)
  }

  function fillClanReward_old()
  {
    if (!::checkObj(scene))
      return
    let objFrameBlock = scene.findObject("clan_battle_season_frame_block_old")
    if (!::checkObj(objFrameBlock))
      return

    let battleSeasonAvailable = ::has_feature("ClanBattleSeasonAvailable")
    objFrameBlock.show(battleSeasonAvailable)
    scene.findObject("clan_battle_season_coming_soon").show(!battleSeasonAvailable)
    if (!battleSeasonAvailable)
      return

    let dateDuel = ::clan_get_current_season_info().rewardDay
    if (dateDuel <= 0)
    {
      objFrameBlock.show(false)
      return
    }
    let endsDate = time.buildDateTimeStr(dateDuel, false, false)
    let objEndsDuel = scene.findObject("clan_battle_season_ends")
    if (::checkObj(objEndsDuel))
      objEndsDuel.setValue(::loc("clan/battle_season/ends") + ::loc("ui/colon") + endsDate)

    let blk = ::get_game_settings_blk()
    if (!blk)
      return
    let curMode = getCurDMode()
    let topPlayersRewarded = get_blk_value_by_path(blk, "clanDuel/reward/topPlayersRewarded", 10)
    let diff = ::g_difficulty.getDifficultyByDiffCode(curMode)
    let rewardPath = "clanDuel/reward/" + diff.egdLowercaseName + "/era5"
    let rewards = get_blk_value_by_path(blk, rewardPath)
    if (!rewards)
      return

    objFrameBlock.show(true)
    let rewObj = scene.findObject("clan_battle_season_reward_description")
    if (::checkObj(rewObj))
      rewObj.setValue(::format(::loc("clan/battle_season/reward_description"), topPlayersRewarded))

    let clanTableObj = scene.findObject("clan_battle_season_reward_table");
    if (!::checkObj(clanTableObj))
      return

    local rowBlock = ""
    let rowData = []
    for (local i=1; i<=3; i++)
    {
      rowData.append({text = ::loc("clan/battle_season/place_"+i), active = false, tdalign="right"})
      rowData.append({
        needText=false,
        rawParam="text { text-align:t='right'; text:t='" +
          ::Cost(0, ::getTblValue("place"+i+"Gold", rewards, 0)).tostring() +
          "'; size:t='pw,ph'; style:t='re-type:textarea; behaviour:textarea;'; }",
        active = false
      })
    }
    rowBlock += ::buildTableRowNoPad("row_0", rowData, null, "")
    guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function onClanSeasonInfo()
  {
    if (!::g_clan_seasons.isEnabled() || !::has_feature("ClanSeasonAttributes"))
      return
    let diff = ::g_difficulty.getDifficultyByDiffCode(getCurDMode())
    ::show_clan_season_info(diff)
  }

  function getWndHelpConfig()
  {
    let res = {}
    if (curPage == "clans_leaderboards" || curPage == "clans_search")
    {
      res.textsBlk <- "%gui/clans/clansModalHandlerListHelp.blk"
      res.objContainer <- scene.findObject("clans_list_content")
      res.links <- getClanTableHelpLinksByPage(curPage)
      return res
    }
    else if (curPage == "my_clan")
      return base.getWndHelpConfig()
    return res
  }

  function initLeaderboardFilter()
  {
    loadLeaderboardFilter()
    let view =   {
      multiSelectId = "leaderboard_filter"
      flow = "horizontal"
      isSimpleNavigationShortcuts = true
      onSelect = "onChangeLeaderboardFilter"
      value = filterMask
      list = leaderboardFilterArray.map(@(filter) {
        text = ::loc(filter.locId)
        show = true
      })
    }

    let data = ::handyman.renderCached("%gui/commonParts/multiSelect", view)
    let placeObj = scene.findObject("leaderboard_filter_place")
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function loadLeaderboardFilter()
  {
    filterMask = ::load_local_account_settings(CLAN_LEADERBOARD_FILTER_ID,
      (1 << leaderboardFilterArray.len()) - 1)
  }

  function onChangeLeaderboardFilter(obj)
  {
    let newFilterMask = obj.getValue()
    filterMask = newFilterMask
    ::save_local_account_settings(CLAN_LEADERBOARD_FILTER_ID, filterMask)

    curClanLbPage = 0
    requestClansLbData()
  }

  getCurClan = @() curClanId
}
