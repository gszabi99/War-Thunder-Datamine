from "%scripts/dagui_natives.nut" import clan_get_current_season_info, clan_get_my_clan_tag, ps4_is_ugc_enabled, ps4_show_ugc_restriction, clan_get_requested_clan_id, clan_get_my_clan_name, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRow, buildTableRowNoPad
from "%scripts/clans/clanState.nut" import is_in_clan, myClanInfo

let { g_clan_type } = require("%scripts/clans/clanType.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let { isDataBlock, isFunction } = require("%sqstd/underscore.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { countSizeInItems } = require("%sqDagui/daguiUtil.nut")
let DataBlock  = require("DataBlock")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getBlkValueByPath, convertBlk } = require("%sqstd/datablock.nut")
let { clearBorderSymbols, cutPrefix, trim } = require("%sqstd/string.nut")
let { getClanTableSortFields, getClanTableFieldsByPage, getClanTableHelpLinksByPage
} = require("%scripts/clans/clanTablesConfig.nut")
let time = require("%scripts/time.nut")
let clanContextMenu = require("%scripts/clans/clanContextMenu.nut")
let { floor } = require("%sqstd/math.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { get_game_settings_blk } = require("blkGetters")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { openCreateClanWnd } = require("%scripts/clans/modify/createClanModalHandler.nut")
let { openClanSeasonInfoWnd } = require("%scripts/clans/clanSeasonInfoModal.nut")
let { lbCategoryTypes, getLbCategoryTypeById } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { getLbItemCell } = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let { cancelMembership } = require("%scripts/clans/clanRequests.nut")
let { ranked_column_prefix } = require("%scripts/clans/clanInfoTable.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")
let { filterMessageText } = require("%scripts/chat/chatUtils.nut")

let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

let showClanPageModal = require("%scripts/clans/showClanPageModal.nut")

let { isClanSeasonsEnabled, getShowInSquadronStatistics, getClanCurrentSeasonName,
  getClanCurrentSeasonEndDate, getClanSeasonFirstPrizePlacesRewards
} = require("%scripts/clans/clanSeasons.nut")


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

gui_handlers.ClansModalHandler <- class (gui_handlers.clanPageModal) {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/clans/ClansModal.blk"
  pages          = ["clans_search", "clans_leaderboards", "my_clan"]
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

  clanInfoByRow      = null
  curClanInfo = null
  lastHoveredDataIdx = -1

  rowsTexts      = null
  tooltips       = null

  filterMask = null

  function initScreen() {
    this.clanInfoByRow = []
    this.rowsTexts = {}
    this.tooltips  = {}

    if (this.startPage == "")
      this.startPage = (clan_get_my_clan_id() == "-1") ? "clans_search" : "my_clan"

    this.curWwCategory = lbCategoryTypes.EVENTS_PERSONAL_ELO
    this.initSearchBox()
    this.initLbTable()
    this.initLeaderboardFilter()
    this.initTabs()

    this.curMode = this.getCurDMode()
  }

  function initSearchBox() {
    let searchObj = this.scene.findObject("filter_edit_box")
    searchObj["max-len"] = "32"
    searchObj["char-mask"] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _-"
  }

  function initTabs() {
    let view = { tabs = [] }
    local pageIdx = 0
    foreach (idx, sheet in this.pages) {
      view.tabs.append({
        id = sheet
        tabName = $"#clan/{sheet}"
        navImagesText = getNavigationImagesText(idx, this.pages.len())
      })
      if (this.startPage == sheet)
        pageIdx = idx
    }

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.tabsObj = this.scene.findObject("clans_sheet_list")
    this.guiScene.replaceContentFromText(this.tabsObj, data, data.len(), this)
    this.curPage = this.pages[pageIdx]
    this.tabsObj.setValue(pageIdx)
  }

  function showCurPage() {
    if (this.curPage == "my_clan")
      this.showMyClanPage()
    else
      this.enableAdminMode(false)

    if (this.curPage == "clans_leaderboards" || this.curPage == "clans_search")
      this.showLb()

    this.updateAdminModeSwitch()
  }

  function onSheetChange() {
    this.clearPage()
    this.curPage = this.pages[this.tabsObj.getValue()]
    this.isClanInfo = this.curPage == "my_clan"
    this.showCurPage()
  }

  function clearPage() {
    if (this.curPageObj == null || !this.curPageObj.isValid())
      return

    this.curPageObj.show(false)
    this.curPageObj.enable(false)
  }

  function initClanLeaderboards() {
    this.clanLbInited = true
    this.curClanLbPage = 0
    this.clanInfoByRow = []
    this.curClanInfo = null
    this.isLastPage = false
    this.clansLbSortByPage = getClanTableSortFields()
  }

  function calculateRowNumber() {
    this.guiScene.applyPendingChanges(false)
    let reserveY = "".concat("0.05sh",
      (myClanInfo.get() != null && this.curPage == "clans_leaderboards") ? " + 1.7@leaderboardTrHeight" : "")
    let clanLboard = this.scene.findObject("clan_lboard_table")
    this.clansPerPage = countSizeInItems(clanLboard, 1, "@leaderboardTrHeight", 0, 0, 0, reserveY).itemsCountY
    this.requestingClansCount = this.clansPerPage + 1
  }

  function initMyClanPage() {
    this.myClanInited = true
    this.setDefaultSort()
    let myClanPages = {
      clan_info_not_in_clan = false
      clan_container = false
    }
    foreach (pageId, status in myClanPages)
      showObjById(pageId, status, this.scene)


    let myClanInfoV = myClanInfo.get()
    if (myClanInfoV != null) {
      this.clanIdStrReq = myClanInfoV.id
      this.reinitClanWindow()
    }
  }

  function afterClanLeave() {} 

  function showLb() {
    this.curPageObj = this.scene.findObject("clans_list_content")
    if (!this.curPageObj)
      return this.goBack()
    this.curPageObj.show(true)
    this.curPageObj.enable(true)

    let isLeaderboardPage = this.curPage == "clans_leaderboards"
    showObjectsByTable(this.scene, {
      clans_battle_season         = isLeaderboardPage
      modes_list                  = isLeaderboardPage
      leaderboard_filter_place    = !isLeaderboardPage
    })

    let myClanInfoV = myClanInfo.get()
    if (!this.clanLbInited ||
       (myClanInfoV == null && this.myClanLbData != null) ||
       (myClanInfoV != null && this.myClanLbData == null))
      this.initClanLeaderboards()

    if (isLeaderboardPage)
      this.fillModeListBox(this.curPageObj, this.getCurDMode(), getShowInSquadronStatistics)
    else {
      this.curClanLbPage = 0
      this.calculateRowNumber()
      this.requestClansLbData()
    }
  }

  function onStatsModeChange(obj) {
    if (!checkObj(obj))
      return

    let diffCode = obj.getChild(obj.getValue()).holderDiffCode.tointeger()
    let diff = g_difficulty.getDifficultyByDiffCode(diffCode)
    if (!getShowInSquadronStatistics(diff))
      return

    this.curMode = diffCode
    this.setCurDMode(this.curMode)
    this.fillClanReward()
    this.calculateRowNumber()
    this.requestClansLbData(true)
  }

  function showMyClanPage(forceReinit = false) {
    if (!this.myClanInited || forceReinit)
      this.initMyClanPage()

    let myClanInfoV = myClanInfo.get()
    this.curPageObj = this.scene.findObject(myClanInfoV ? "clan_container" : "clan_info_not_in_clan")
    if (!this.curPageObj)
      return

    this.curPageObj.show(true)
    this.curPageObj.enable(true)

    if (!myClanInfoV) {
      local requestSent = false
      if (::clan_get_requested_clan_id() != "-1" && clan_get_my_clan_name() != "") {
        requestSent = true
        this.curPageObj.findObject("req_clan_name").setValue(" ".concat(clan_get_my_clan_tag(), clan_get_my_clan_name()))
      }
      this.curPageObj.findObject("reques_to_clan_sent").show(requestSent)
      this.curPageObj.findObject("how_to_get_membership").show(!requestSent)
    }
    else {
      this.clanData = myClanInfoV
      this.onceFillModeList(this.curPageObj, this.getCurDMode(),
        getShowInSquadronStatistics, this.getAdditionalTabsArray())
    }
  }

  function getClansLbFieldName(lbCategory = null, mode = null) {
    let actualCategory = lbCategory || this.clansLbSortByPage[this.curPage]
    let field = actualCategory?.field ?? actualCategory.id
    local fieldName = isFunction(field) ? field() : field
    if (actualCategory.byDifficulty)
      fieldName = "".concat(fieldName, g_difficulty.getDifficultyByDiffCode(mode ?? this.curMode).clanDataEnding)
    return fieldName
  }

  function getClanLBPage(seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null) {
    let requestBlk = DataBlock()
    requestBlk["start"] <- this.curClanLbPage * this.clansPerPage
    requestBlk["count"] <- this.requestingClansCount
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- this.getClansLbFieldName()
    requestBlk["shortMode"] <- "on"
    if (this.curPage == "clans_search")
      foreach (idx, filter in leaderboardFilterArray)
        if ((1 << idx) & this.filterMask)
          requestBlk[filter.id] <- "on"

    return charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function requestClanLBPosition(fieldName, seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null) {
    let requestBlk = DataBlock()
    requestBlk["clanId"] <- clan_get_my_clan_id()
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- fieldName
    requestBlk["shortMode"] <- "on"
    return charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function findClanByPrefix(prefix, onSuccessCb = null, onErrorCb = null) {
    let requestBlk = DataBlock()
    requestBlk["namePrefix"] <- prefix
    requestBlk["tagPrefix"] <- prefix
    requestBlk["start"] <- this.curClanLbPage * this.clansPerPage
    requestBlk["count"] <- this.requestingClansCount
    requestBlk["shortMode"] <- "on"
    if (this.curPage == "clans_search")
      foreach (idx, filter in leaderboardFilterArray)
        if ((1 << idx) & this.filterMask)
          requestBlk[filter.id] <- "on"

    return charRequestBlk("cln_clan_find_by_prefix", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function requestClansLbData(updateMyClanRow = false, seasonOrdinalNumber = -1) {
    this.showEmptySearchResult(false)
    if ((clan_get_my_clan_id() == "-1" || this.curPage == "clans_search")
      && this.myClanLbData != null)
      this.myClanLbData = null
    if (updateMyClanRow && clan_get_my_clan_id() != "-1") {
      let requestPage = this.curPage
      let cbSuccess = Callback( function(myClanRowBlk) {
                                      if (requestPage != this.curPage)
                                        return

                                      let myClanId = clan_get_my_clan_id()
                                      local found = false
                                      foreach (row in myClanRowBlk % "clan")
                                        if (row?._id == myClanId) {
                                          this.myClanLbData = convertBlk(row)
                                          this.myClanLbData.astat <- isDataBlock(row?.astat) ? convertBlk(row.astat) : {}
                                          found = true
                                          break
                                        }
                                      if (!found)
                                        this.myClanLbData = null
                                      this.requestLbData(seasonOrdinalNumber)
                                    }, this)

      this.requestClanLBPosition(this.getClansLbFieldName(), seasonOrdinalNumber, cbSuccess)
    }
    else
      this.requestLbData(seasonOrdinalNumber)
  }

  function requestLbData(seasonOrdinalNumber) {
    let requestPage = this.curPage
    let cbSuccess = Callback(function(data) {
                                   if (requestPage == this.curPage)
                                     this.lbDataCb(data)
                                 }, this)

    if (this.isSearchMode && this.searchRequest.len() > 0)
      this.findClanByPrefix(this.searchRequest, cbSuccess)
    else
      this.getClanLBPage(seasonOrdinalNumber, cbSuccess)
  }

  function onFilterEditBoxActivate() {
    this.curClanLbPage = 0
    this.searchRequest = this.scene.findObject("filter_edit_box").getValue()
    this.searchRequest = this.searchRequest.len() > 0 ? clearBorderSymbols(this.searchRequest, [" "]) : ""
    this.isSearchMode = this.searchRequest.len() > 0
    this.showEmptySearchResult(false)
    if (this.isSearchMode)
      this.requestLbData(-1)
    else
      return this.requestClansLbData()
  }

  function onBackToClanlist() {
    this.curClanLbPage = 0
    this.searchRequest = ""
    this.isSearchMode = false
    this.requestClansLbData()
  }

  function lbDataCb(lbBlk) {
    if (!checkObj(this.scene))
      return

    let lbPageObj = this.scene.findObject("clans_list_content")
    if (!checkObj(lbPageObj))
      return

    showObjById("btn_back_to_clanlist", this.isSearchMode, lbPageObj)

    if (this.isSearchMode && !("clan" in lbBlk)) {
      this.showEmptySearchResult(true)
      this.clanInfoByRow.clear()
      this.curClanInfo = null
      this.updateButtons()
      return
    }

    this.printLeaderboards(lbBlk)

    let paginatorObj = lbPageObj.findObject("mid_nav_bar")
    let myPage = (this.myClanLbData != null && "pos" in this.myClanLbData) ? floor(this.myClanLbData.pos / this.clansPerPage) : null
    generatePaginator(paginatorObj, this, this.curClanLbPage, this.curClanLbPage + (this.isLastPage ? 0 : 1), myPage)
  }

  function showEmptySearchResult(show) {
    this.scene.findObject("search_status").display = show ? "show" : "hide"
    let lbTableObj = this.scene.findObject("clan_lboard_table")
    this.guiScene.replaceContentFromText(lbTableObj, "", 0, this)
  }

  function printLeaderboards(clanLbBlk) {
    let lbPageObj = this.scene.findObject("clans_list_content")
    if (!checkObj(lbPageObj))
      return

    local data = []
    this.rowsTexts = {}
    this.tooltips = {}
    this.clanInfoByRow.clear()
    this.curClanInfo = null
    this.isLastPage = true
    foreach (_name, rowBlk in clanLbBlk % "clan") {
      if (type(rowBlk) != "instance")
        continue

      if (this.clanInfoByRow.len() >= this.clansPerPage) {
        this.isLastPage = false
        break
      }

      
      let rowBlkFiltered = ::getFilteredClanData(rowBlk)
      data.append(this.generateRowTableData(rowBlkFiltered, this.clanInfoByRow.len()))
      this.clanInfoByRow.append({
        id = rowBlkFiltered._id.tostring()
        isClosed = rowBlkFiltered?.status == "closed"
      })
    }

    for (local i = this.clanInfoByRow.len(); i < this.clansPerPage; i++) {
      data.append(buildTableRow($"row_{i}", [], i % 2 == 1, "inactive:t='yes';"))
      this.clanInfoByRow.append(null)
    }

    if (this.myClanLbData != null) {
      data.append(buildTableRow($"row_{this.clanInfoByRow.len()}", ["..."], null,
        "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;';"))
      this.clanInfoByRow.append(null)
      this.myClanLbData = ::getFilteredClanData(this.myClanLbData)
      data.append(this.generateRowTableData(this.myClanLbData, this.clanInfoByRow.len()))
      this.clanInfoByRow.append({
        id = this.myClanLbData._id.tostring()
        isClosed = this.myClanLbData?.status == "closed"
      })
    }
    let headerRow = [{ text = "#multiplayer/place", width = "0.1@sf" }, { text = "" }, { text = "#clan/clan_name", tdalign = "left",  width = "@clanNameTableWidth" }]

    let fieldList = getClanTableFieldsByPage(this.curPage)
    foreach (item in fieldList) {
      if (!this.isColForDisplay(item))
        continue

      let block = {
        id = item.id
        image = item.getIcon(this.getCurDMode())
        tooltip = item.tooltip
        active = this.clansLbSortByPage[this.curPage].id == item.id
        text = loc(item?.text ?? "")
        needText = (item?.text ?? "") != ""
      }
      if (!("field" in item) || !item.sort)
        block.rawParam <- "no-hover:t='yes';"
      if (item.sort)
        block.callback <- "onCategory"
      if (item?.width != null)
        block.width <- item.width
      headerRow.append(block)
    }
    data.insert(0, buildTableRow("row_header", headerRow, null, "isShortLeaderBoardHeader:t='yes'"))
    data = "".join(data)

    this.guiScene.setUpdatesEnabled(false, false)
    let lbTableObj = lbPageObj.findObject("clan_lboard_table")
    this.guiScene.replaceContentFromText(lbTableObj, data, data.len(), this)
    foreach (rowName, row in this.rowsTexts)
      foreach (name, value in row)
        lbTableObj.findObject(rowName).findObject(name).setValue(value)
    foreach (rowName, row in this.tooltips)
      foreach (name, value in row)
        lbTableObj.findObject(rowName).findObject(name).tooltip = value
    this.guiScene.setUpdatesEnabled(true, true)

    if (this.curPage == "clans_leaderboards" || this.curPage == "clans_search") {
      lbTableObj.setValue(this.clanInfoByRow.len() ? 1 : -1)
      this.onSelectClan(lbTableObj)
    }
  }

  function generateRowTableData(rowBlk, rowIdx) {
    local { slogan = "", desc = "" } = rowBlk
    slogan = trim(slogan).len() == 0 ? "" : slogan
    desc = trim(desc).len() == 0 ? "" : desc
    let rowName = $"row_{rowIdx}"

    let clanType = g_clan_type.getTypeByName(rowBlk?.type ?? "")
    let highlightRow = this.myClanLbData != null && this.myClanLbData._id == rowBlk._id
    this.rowsTexts[rowName] <- {
      txt_name = this.colorizeClanText(clanType, rowBlk.name, highlightRow)
      txt_tag = this.colorizeClanText(clanType, rowBlk.tag, highlightRow)
    }
    if (slogan != "" || desc != "")
      this.tooltips[rowName] <- { name = "\n".concat(slogan, desc) }
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
    let fieldList = getClanTableFieldsByPage(this.curPage)
    foreach (item in fieldList)
      if (this.isColForDisplay(item))
        rowData.append(this.getItemCell(item, rowBlk, rowName))

    assert(type(rowBlk._id) == "string", $"leaderboards receive _id type {type(rowBlk._id)}, instead of string on clan_request_page_of_leaderboard")
    return buildTableRow(rowName, rowData, rowIdx % 2 != 0, highlightRow ? "mainPlayer:t='yes';" : "")
  }

  function colorizeClanText(clanType, clanText, isMainPlayer) {
    return isMainPlayer ? clanText : colorize(clanType.color, clanText)
  }

  function getItemCell(item, rowBlk, rowName) {
    let itemId = this.getClansLbFieldName(item)

    if (!rowBlk?.astat)
      rowBlk.astat = DataBlock()
    let value = itemId == "members_cnt" ? rowBlk?[itemId] ?? 0
      : itemId == "slogan" ? filterMessageText(rowBlk?[itemId] ?? "", false)
      : itemId == "fits_requirements" ? ""
      : rowBlk.astat?[itemId] ?? 0

    let res = getLbItemCell(item.id, value, item.type)
    res.active <- this.clansLbSortByPage[this.curPage].id == item.id
    if (item?.width != null) {
      res.width <- item.width
      res.autoScrollText <- item?.autoScrollText ?? false
      res.tooltip <- item?.autoScrollText ? res.text : ""
    }
    if ("getCellImage" in item) {
      res.image <- item.getCellImage(rowBlk)
      res.imageRawParams <- "left:t='0.5pw-0.5w'"
      res.needText <- false
    }
    if ("getCellTooltipText" in item)
      res.tooltip <- item.getCellTooltipText(rowBlk)
    if ("tooltip" in res) {
      if (!(rowName in this.tooltips))
        this.tooltips[rowName] <- {}
      this.tooltips[rowName][item.id] <- res.$rawdelete("tooltip")
    }
    return res
  }

  function isColForDisplay(column) {
    let colName = column.id
    if (this.curPage != "clans_leaderboards" || colName.len() < ranked_column_prefix.len()
      || colName.slice(0, ranked_column_prefix.len()) != ranked_column_prefix) {
      let showByFeature = getTblValue("showByFeature", column, null)
      if (showByFeature != null && !hasFeature(showByFeature))
        return false

      return true
    }

    return colName == ranked_column_prefix
  }

  function onCategory(obj) {
    if (!checkObj(obj))
      return

    if (this.isClanInfo && this.isWorldWarMode) {
      if (this.curWwCategory.id != obj.id) {
        this.curWwCategory = getLbCategoryTypeById(obj.id)
        this.fillClanWwMemberList()
      }
      return
    }

    let fieldList = getClanTableFieldsByPage(this.curPage)
    foreach (_idx, category in fieldList)
      if (obj.id == category.id) {
        this.clansLbSortByPage[this.curPage] = category
        break
      }
    this.curClanLbPage = 0
    this.requestClansLbData(this.curPage != "clans_search")
  }

  function onFilterEditBoxCancel(obj) {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      this.goBack();
  }

  function onFilterEditBoxChangeValue() {}

  function onSelectClan(obj) {
    if (showConsoleButtons.value)
      return
    if (!checkObj(obj))
      return

    let dataIdx = obj.getValue() - 1 
    this.onSelectedClanIdx(dataIdx)
  }

  function onRowHoverClan(obj) {
    if (!showConsoleButtons.value)
      return
    if (!checkObj(obj))
      return

    let isHover = obj.isHovered()
    let dataIdx = to_integer_safe(cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == this.lastHoveredDataIdx))
     return

    this.lastHoveredDataIdx = isHover ? dataIdx : -1
    this.onSelectedClanIdx(this.lastHoveredDataIdx)
  }

  function onSelectedClanIdx(dataIdx) {
    this.curClanInfo = this.clanInfoByRow?[dataIdx]
    this.updateButtons()
  }

  function updateButtons() {
    showObjectsByTable(this.curPageObj, {
      mid_nav_bar        = this.clanInfoByRow.len() > 0
      btn_clan_info      = this.curClanInfo != null
      btn_clan_actions   = this.curClanInfo != null && showConsoleButtons.value
      btn_membership_req = this.curClanInfo != null && !is_in_clan()
        && (clan_get_requested_clan_id() != this.curClanInfo.id)
    })

    let reqButton = this.curPageObj.findObject("btn_membership_req")
    if (!checkObj(reqButton))
      return

    let isClosed = this.curClanInfo?.isClosed ?? false
    reqButton.inactiveColor = isClosed ? "yes" : "no"
    reqButton.tooltip = isClosed ? loc("clan/was_closed") : ""
  }

  function onEventClanMembershipRequested(_p) {
    this.updateButtons()
  }

  function onEventClanMembershipCanceled(_p) {
    this.showMyClanPage()
  }

  function onClanInfo() {
    if (this.curClanInfo != null)
      showClanPageModal(this.curClanInfo.id, "", "")
  }

  function onSelectClansList(_obj) {
    this.guiScene.performDelayed(this, function() {
      if (checkObj(this.scene))
        this.onSelectClan(this.scene.findObject("clan_lboard_table"))
    })
  }

  function goToPage(obj) {
    this.curClanLbPage = obj.to_page.tointeger()
    this.requestClansLbData()
  }

  function onCreateClanWnd() {
    if (hasFeature("Clans")) {
      if (!ps4_is_ugc_enabled())
        ps4_show_ugc_restriction()
      else
        openCreateClanWnd()
    }
    else
      this.msgBox("not_available", loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
  }

  function onEventClanInfoUpdate(_params = {}) {
    this.initMyClanPage()
    this.onSheetChange()
  }

  function onClanRclick(position = null) {
    if (!this.curClanInfo)
      return

    let menu = clanContextMenu.getClanActions(this.curClanInfo.id)
    openRightClickMenu(menu, this, position)
  }

  function onCancelRequest() {
    this.msgBox("cancel_request_question",
           loc("clan/cancel_request_question"),
           [
             ["ok", @() cancelMembership()],
             ["cancel", @() null]
           ],
           "ok",
           { cancel_fn = @() null }
          )
  }

  function fillClanReward() {
    let objFrameBlock = this.scene.findObject("clan_battle_season_frame_block")
    if (!checkObj(objFrameBlock))
      return

    
    let seasonsEnabled = isClanSeasonsEnabled()
    objFrameBlock.show(seasonsEnabled)
    this.scene.findObject("clan_battle_season_coming_soon").show(!seasonsEnabled)
    if (!seasonsEnabled) {
      
      this.fillClanReward_old()
      return
    }

    let showAttributes = hasFeature("ClanSeasonAttributes")

    let seasonName = getClanCurrentSeasonName()
    let diff = g_difficulty.getDifficultyByDiffCode(this.getCurDMode())

    
    let objSeasonName = this.scene.findObject("clan_battle_season_name")
    if (checkObj(objSeasonName) && showAttributes)
      objSeasonName.setValue(loc("ui/colon").concat(loc("clan/battle_season/title"), colorize("userlogColoredText", seasonName)))

    
    let objTopMedal = this.scene.findObject("clan_battle_season_logo_medal")
    if (checkObj(objTopMedal) && showAttributes) {
      objTopMedal.show(true)
      let iconStyle =$"clan_season_logo_{diff.egdLowercaseName}"
      let iconParams = { season_title = { text = seasonName } }
      LayersIcon.replaceIcon(objTopMedal, iconStyle, null, null, null, iconParams)
    }

    
    let objEndsDuel = this.scene.findObject("clan_battle_season_ends")
    if (checkObj(objEndsDuel)) {
      let endDateText = "".concat(loc("clan/battle_season/ends"), loc("ui/colon"), " ",
        getClanCurrentSeasonEndDate())
      objEndsDuel.setValue(endDateText)
    }

    
    let clanTableObj = this.scene.findObject("clan_battle_season_reward_table")
    if (checkObj(clanTableObj)) {
      let rewards = getClanSeasonFirstPrizePlacesRewards(CLAN_SEASONS_TOP_PLACES_REWARD_PREVIEW, diff)
      local rowBlock = ""
      let rowData = []
      foreach (reward in rewards) {
        let placeText = (reward.place >= 1 && reward.place <= 3) ?
          loc($"clan/season_award/place/place{reward.place}") :
          loc("clan/season_award/place/placeN", { placeNum = reward.place })

        rowData.append({
          text = placeText,
          active = false,
          tdalign = "right"
        })

        let rewardText = Cost(0, reward.gold).tostring()
        rowData.append({
          needText = false,
          rawParam = "".concat(@"text {
            text-align:t='right';
            text:t='", rewardText, @"';
            size:t='pw, ph';
            margin-left:t='1@blockInterval'
            style:t='re-type:textarea;behaviour:textarea;';
          }"),
          active = false
        })
      }
      rowBlock = "".concat(rowBlock, buildTableRowNoPad("row_0", rowData, null, ""))
      this.guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
    }

    let objInfoBtn = this.scene.findObject("clan_battle_season_info_btn")
    if (checkObj(objInfoBtn) && showAttributes)
      objInfoBtn.show(true)
  }

  function fillClanReward_old() {
    if (!checkObj(this.scene))
      return
    let objFrameBlock = this.scene.findObject("clan_battle_season_frame_block_old")
    if (!checkObj(objFrameBlock))
      return

    let battleSeasonAvailable = hasFeature("ClanBattleSeasonAvailable")
    objFrameBlock.show(battleSeasonAvailable)
    this.scene.findObject("clan_battle_season_coming_soon").show(!battleSeasonAvailable)
    if (!battleSeasonAvailable)
      return

    let dateDuel = clan_get_current_season_info().rewardDay
    if (dateDuel <= 0) {
      objFrameBlock.show(false)
      return
    }
    let endsDate = time.buildDateTimeStr(dateDuel, false, false)
    let objEndsDuel = this.scene.findObject("clan_battle_season_ends")
    if (checkObj(objEndsDuel))
      objEndsDuel.setValue(loc("ui/colon").concat(loc("clan/battle_season/ends"), endsDate))

    let blk = get_game_settings_blk()
    if (!blk)
      return
    let curMode = this.getCurDMode()
    let topPlayersRewarded = getBlkValueByPath(blk, "clanDuel/reward/topPlayersRewarded", 10)
    let diff = g_difficulty.getDifficultyByDiffCode(curMode)
    let rewardPath = $"clanDuel/reward/{diff.egdLowercaseName}/era5"
    let rewards = getBlkValueByPath(blk, rewardPath)
    if (!rewards)
      return

    objFrameBlock.show(true)
    let rewObj = this.scene.findObject("clan_battle_season_reward_description")
    if (checkObj(rewObj))
      rewObj.setValue(format(loc("clan/battle_season/reward_description"), topPlayersRewarded))

    let clanTableObj = this.scene.findObject("clan_battle_season_reward_table");
    if (!checkObj(clanTableObj))
      return

    local rowBlock = ""
    let rowData = []
    for (local i = 1; i <= 3; i++) {
      rowData.append({ text = loc($"clan/battle_season/place_{i}"), active = false, tdalign = "right" })
      rowData.append({
        needText = false,
        rawParam = "".concat("text { text-align:t='right'; text:t='",
          Cost(0, getTblValue($"place{i}Gold", rewards, 0)).tostring(),
          "'; size:t='pw,ph'; style:t='re-type:textarea; behaviour:textarea;'; }"),
        active = false
      })
    }
    rowBlock = "".concat(rowBlock, buildTableRowNoPad("row_0", rowData, null, ""))
    this.guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function onClanSeasonInfo() {
    if (!isClanSeasonsEnabled() || !hasFeature("ClanSeasonAttributes"))
      return
    let diff = g_difficulty.getDifficultyByDiffCode(this.getCurDMode())
    openClanSeasonInfoWnd(diff)
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {}
    if (this.curPage == "clans_leaderboards" || this.curPage == "clans_search") {
      res.textsBlk <- "%gui/clans/clansModalHandlerListHelp.blk"
      res.objContainer <- this.scene.findObject("clans_list_content")
      res.links <- getClanTableHelpLinksByPage(this.curPage)
      return res
    }
    else if (this.curPage == "my_clan")
      return base.getWndHelpConfig()
    return res
  }

  function initLeaderboardFilter() {
    this.loadLeaderboardFilter()
    let view =   {
      multiSelectId = "leaderboard_filter"
      flow = "horizontal"
      isSimpleNavigationShortcuts = true
      onSelect = "onChangeLeaderboardFilter"
      value = this.filterMask
      list = leaderboardFilterArray.map(@(filter) {
        text = loc(filter.locId)
        enable = true
      })
    }

    let data = handyman.renderCached("%gui/commonParts/multiSelect.tpl", view)
    let placeObj = this.scene.findObject("leaderboard_filter_place")
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function loadLeaderboardFilter() {
    this.filterMask = loadLocalAccountSettings(CLAN_LEADERBOARD_FILTER_ID,
      (1 << leaderboardFilterArray.len()) - 1)
  }

  function onChangeLeaderboardFilter(obj) {
    let newFilterMask = obj.getValue()
    this.filterMask = newFilterMask
    saveLocalAccountSettings(CLAN_LEADERBOARD_FILTER_ID, this.filterMask)

    this.curClanLbPage = 0
    this.requestClansLbData()
  }

  getCurClan = @() this.curClanInfo?.id
}