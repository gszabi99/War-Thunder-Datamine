//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { ceil, floor } = require("math")
let { format } = require("string")
let time = require("%scripts/time.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let clanContextMenu = require("%scripts/clans/clanContextMenu.nut")
let { hasAllFeatures } = require("%scripts/user/features.nut")
let { getSeparateLeaderboardPlatformName } = require("%scripts/social/crossplay.nut")
let { refreshUserstatCustomLeaderboardStats, userstatCustomLeaderboardStats
} = require("%scripts/userstat/userstat.nut")

::leaderboards_list <- [
  ::g_lb_category.PVP_RATIO
  ::g_lb_category.VICTORIES_BATTLES
  ::g_lb_category.AVERAGE_RELATIVE_POSITION
  ::g_lb_category.AIR_KILLS
  ::g_lb_category.GROUND_KILLS
  ::g_lb_category.NAVAL_KILLS
  ::g_lb_category.AVERAGE_ACTIVE_KILLS_BY_SPAWN
  ::g_lb_category.AVERAGE_SCRIPT_KILLS_BY_SPAWN
  ::g_lb_category.AVERAGE_SCORE
]

::leaderboard_modes <- [
  {
    // Arcade Battles
    text = "#mainmenu/arcadeInstantAction"
    mode = "arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    // Realistic Battles
    text = "#mainmenu/instantAction"
    mode = "historical"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    // Simulator Battles
    text = "#mainmenu/fullRealInstantAction"
    mode = "simulation"
    diffCode = DIFFICULTY_HARDCORE
  }

  {
    // Air Arcade Battles
    text = "#missions/air_event_arcade"
    mode = "air_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    // Air Realistic Battles
    text = "#missions/air_event_historical"
    mode = "air_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    // Air Simulator Battles
    text = "#missions/air_event_simulator"
    mode = "air_simulation"
    diffCode = DIFFICULTY_HARDCORE
  }
  {
    // Tank Arcade Battles
    text = "#missions/tank_event_arcade"
    mode = "tank_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    // Tank Realistic Battles
    text = "#missions/tank_event_historical"
    mode = "tank_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    // Tank Simulator Battles
    text = "#missions/tank_event_simulator"
    mode = "tank_simulation"
    diffCode = DIFFICULTY_HARDCORE
  }
  {
    // Ship Arcade Battles
    text = "#missions/ship_event_arcade"
    mode = "test_ship_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    // Ship Realistic Battles
    text = "#missions/ship_event_historical"
    mode = "test_ship_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    // Helicopter Arcade Battles
    text = "#missions/helicopter_event"
    mode = "helicopter_arcade"
    diffCode = DIFFICULTY_ARCADE
    reqFeature = [ "HiddenLeaderboardRows" ]
  }
]

::gui_modal_leaderboards <- function gui_modal_leaderboards(lb_presets = null) {
  ::gui_start_modal_wnd(::gui_handlers.LeaderboardWindow, { lb_presets = lb_presets })
}

::gui_modal_event_leaderboards <- function gui_modal_event_leaderboards(params) {
  ::gui_start_modal_wnd(::gui_handlers.EventsLeaderboardWindow, params)
}

::leaderboardModel <-
{
  selfRowData       = null
  leaderboardData   = null
  lastRequestData   = null
  lastRequestSRData = null //last self row request
  canRequestLb      = true

  defaultRequest =
  {
    lbType = ETTI_VALUE_INHISORY
    lbField = "each_player_victories"
    rowsInPage = 1
    pos = 0
    lbMode = ""
    platformFilter = ""
  }

  function reset() {
    this.selfRowData       = null
    this.leaderboardData   = null
    this.lastRequestData   = null
    this.lastRequestSRData = null
    this.canRequestLb      = true
  }

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function requestLeaderboard(requestData, callback, context = null) {
    requestData = this.validateRequestData(requestData)

    //trigging callback if data is lready here
    if (this.leaderboardData && this.compareRequests(this.lastRequestData, requestData)) {
      if (context)
        callback.call(context, this.leaderboardData)
      else
        callback(this.leaderboardData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    this.loadLeaderboard(requestData)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function requestSelfRow(requestData, callback, context = null) {
    requestData = this.validateRequestData(requestData)
    if (this.lastRequestSRData)
      this.lastRequestSRData.pos <- requestData.pos

    //trigging callback if data is lready here
    if (this.selfRowData && this.compareRequests(this.lastRequestSRData, requestData)) {
      if (context)
        callback.call(context, this.selfRowData)
      else
        callback(this.selfRowData)
      return
    }

    requestData.callBack <- Callback(callback, context)
    this.loadSeflRow(requestData)
  }

  function loadLeaderboard(requestData) {
    this.lastRequestData = requestData
    if (!this.canRequestLb)
      return

    this.canRequestLb = false

    let db = DataBlock()
    db.setStr("category", requestData.lbField)
    db.setStr("valueType", requestData.lbType == ETTI_VALUE_INHISORY ? LEADERBOARD_VALUE_INHISTORY : LEADERBOARD_VALUE_TOTAL)
    db.setInt("count", requestData.rowsInPage)
    db.setStr("gameMode", requestData.lbMode)
    db.setStr("platformFilter", requestData.platformFilter)
    db.setStr("platform",       requestData.platformFilter)  // deprecated, delete after lb-server release
    db.setInt("start", requestData.pos)

    let taskId = ::request_leaderboard_blk(db)
    ::add_bg_task_cb(taskId, @() ::leaderboardModel.handleLbRequest(requestData))
  }

  function loadSeflRow(requestData) {
    this.lastRequestSRData = requestData
    if (!this.canRequestLb)
      return
    this.canRequestLb = false

    let db = DataBlock()
    db.setStr("category", requestData.lbField)
    db.setStr("valueType", requestData.lbType == ETTI_VALUE_INHISORY ? LEADERBOARD_VALUE_INHISTORY : LEADERBOARD_VALUE_TOTAL)
    db.setInt("count", 0)
    db.setStr("gameMode", requestData.lbMode)
    db.setStr("platformFilter", requestData.platformFilter)
    db.setStr("platform",       requestData.platformFilter)  // deprecated, delete after lb-server release

    let taskId = ::request_leaderboard_blk(db)
    ::add_bg_task_cb(taskId, @() ::leaderboardModel.handleSelfRowLbRequest(requestData))
  }

  function handleLbRequest(requestData) {
    let LbBlk = ::get_leaderboard_blk()
    this.leaderboardData = {}
    this.leaderboardData["rows"] <- this.lbBlkToArray(LbBlk, requestData)
    this.canRequestLb = true
    if (!this.compareRequests(this.lastRequestData, requestData))
      this.requestLeaderboard(this.lastRequestData,
                     getTblValue("callBack", requestData),
                     getTblValue("handler", requestData))
    else if ("callBack" in requestData) {
        if ("handler" in requestData)
          requestData.callBack.call(requestData.handler, this.leaderboardData)
        else
          requestData.callBack(this.leaderboardData)
    }
  }

  function handleSelfRowLbRequest(requestData) {
    let sefRowblk = ::get_leaderboard_blk()
    this.selfRowData = this.lbBlkToArray(sefRowblk, requestData)
    this.canRequestLb = true
    if (!this.compareRequests(this.lastRequestSRData, requestData))
      this.loadSeflRow(this.lastRequestSRData)
    else if ("callBack" in requestData) {
        if ("handler" in requestData)
          requestData.callBack.call(requestData.handler, this.selfRowData)
        else
          requestData.callBack(this.selfRowData)
    }
  }

  function lbBlkToArray(blk, requestData) {
    let res = []
    let valueKey = (requestData.lbType == ETTI_VALUE_INHISORY) ? LEADERBOARD_VALUE_INHISTORY : LEADERBOARD_VALUE_TOTAL
    for (local i = 0; i < blk.blockCount(); i++) {
      let table = {}
      let row = blk.getBlock(i)
      table.name <- row.getBlockName()
      table.pos <- row.idx != null ? row.idx : -1
      for (local j = 0; j < row.blockCount(); j++) {
        let param = row.getBlock(j)
        if (param.paramCount() <= 0 || param?[valueKey] == null)
          continue
        table[param.getBlockName()] <- param[valueKey]
      }
      res.append(table)
    }
    return res
  }

  function validateRequestData(requestData) {
    foreach (name, field in this.defaultRequest)
      if (!(name in requestData))
        requestData[name] <- field
    return requestData
  }

  function compareRequests(req1, req2) {
    foreach (name, _field in this.defaultRequest) {
      if ((name in req1) != (name in req2))
        return false
      if (!(name in req1)) //no name in both req
        continue
      if (req1[name] != req2[name])
        return false
    }
    return true
  }

  function checkLbRowVisibility(row, params = {}) {
    // check ownProfileOnly
    if (getTblValue("ownProfileOnly", row, false) && !getTblValue("isOwnStats", params, false))
      return false

    // check reqFeature
    if (!row.isVisibleByFeature())
      return false

    // check modesMask
    let lbMode = getTblValue("lbMode", params)
    if (!row.isVisibleByLbModeName(lbMode))
      return false

    return true
  }
}

::leaderboarsdHelpers <-
{
  /**
   * Comapares two lb row with the same fields and returns
   * a table of diff for each field.
   * Result table containes only fields with different values
   * The first argument is base of comarsion. In other words a is now and b is
   * was.
   * If a.f1 > b.f1 and a.f1 - b.f1 == 3
   * the result will looks like
   * res.f1 = 3
   * String fields are ignored
   */
  function getLbDiff(a, b) {
    let res = {}
    foreach (fieldId, fieldValue in a) {
      if (fieldId == "_id")
        continue
      if (type(fieldValue) == "string")
        continue
      let compareToValue = getTblValue(fieldId, b, 0)
      if (fieldValue != compareToValue)
        res[fieldId] <- fieldValue - compareToValue
    }
    return res
  }
}

/**
 * Generates view for leaderbord item
 *
 * @param field_config  - item of ::leaderboards_list
 *                        or ::events.eventsTableConfig
 * @param lb_value      - value of specified field as it comes from char
 * @param lb_value_diff - optional, diff data, generated
 *                        with ::leaderboarsdHelpers.getLbDiff(...)
 *
 * @return view for getLeaderboardItemWidgets(...)
 */
::getLeaderboardItemView <- function getLeaderboardItemView(lbCategory, lb_value, lb_value_diff = null, params = null) {
  let view = lbCategory.getItemCell(lb_value)
  view.name <- lbCategory.headerTooltip
  view.icon <- lbCategory.headerImage

  view.width  <- getTblValue("width",  params)
  view.pos    <- getTblValue("pos",    params)
  view.margin <- getTblValue("margin", params)

  if (lb_value_diff) {
    view.progress <- {
      positive = lb_value_diff > 0
      diff = lbCategory.getItemCell(lb_value_diff, null, true)
    }
  }

  return view
}

/**
 * Generates view for leaderbord items array
 * @param view  - { items = array of ::getLeaderboardItemView(...) }
 * @return markup ready for insertion into scene
 */
::getLeaderboardItemWidgets <- function getLeaderboardItemWidgets(view) {
  return ::handyman.renderCached("%gui/leaderboard/leaderboardItemWidget.tpl", view)
}

::gui_handlers.LeaderboardWindow <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/leaderboard/leaderboard.blk"

  lbType        = ETTI_VALUE_INHISORY
  curLbCategory = null
  lbField       = ""
  lbModel       = null
  lbMode        = ""
  lbModesList   = null
  lb_presets    = null
  lbData        = null
  forClans      = false

  pos         = 0
  rowsInPage  = 0
  maxRows     = 1000

  platformFilter = ""
  request = {
    lbType     = null
    lbField    = null
    rowsInPage = null
    pos        = null
    lbMode     = ""
    platformFilter = ""
  }
  pageData    = null
  selfRowData = null

  curDataRowIdx = -1

  afterLoadSelfRow = null
  tableWeak = null

  function initScreen() {
    ::req_unlock_by_client("view_leaderboards", false)
    if (!this.lbModel) {
      this.lbModel = ::leaderboardModel
      this.lbModel.reset()
    }
    if (!this.lb_presets)
      this.lb_presets = ::leaderboards_list

    this.curLbCategory = this.lb_presets[0]
    this.lbType = ::loadLocalByAccount("leaderboards_type", ETTI_VALUE_INHISORY)
    this.platformFilter = getSeparateLeaderboardPlatformName()
    this.setRowsInPage()

    ::add_big_query_record("global_leaderboard.open", this.platformFilter)

    this.initTable()
    this.initModes()
    this.initTopItems()
    this.fetchLbData()
    this.updateButtons()
  }

  //----CONTROLLER----//
  function setRowsInPage() {
    this.rowsInPage = this.rowsInPage > 0
      ? this.rowsInPage
      : max(ceil((this.scene.findObject("lb_table_nest").getSize()[1]
        - to_pixels("1@leaderboardHeaderHeight"))
          / (to_pixels("1@rows16height") || 1)).tointeger() - 2, 19)
  }

  function getSelfPos() {
    if (!this.selfRowData || this.selfRowData.len() <= 0)
      return -1

    return this.selfRowData[0].pos
  }

  function requestSelfPage(selfPos) {
    if (!selfPos) {
      this.pos = 0
      return
    }
    if (this.rowsInPage == 0)
      return  // do not divide by zero

    let selfPagePos = this.rowsInPage * floor(selfPos / this.rowsInPage)
    this.pos = selfPagePos / this.rowsInPage < this.maxRows ? selfPagePos : 0
  }

  function goToPage(obj) {
    this.pos = obj.to_page.tointeger() * this.rowsInPage
    this.fetchLbData(true)
  }

  function noLbDataError() {
    this.guiScene.replaceContentFromText(this.scene.findObject("lb_players_table"), "", 0, this)
    log("Error: Empty leaderboard block without endOfList")
    this.msgBox("not_available", loc("multiplayer/lbError"), [["ok", function() { this.goBack() } ]], "ok")
  }

  function getSelectedRowData() {
    if (!checkObj(this.scene) || !this.pageData)
      return null

    let row = this.getLbRows()?[this.curDataRowIdx]
    if (row)
      return row

    if (this.curDataRowIdx == this.rowsInPage + 1 && this.selfRowData && this.selfRowData.len())
      return this.selfRowData[0]

    return null
  }

  function onSelect(dataIdx) {
    this.curDataRowIdx = dataIdx
    this.updateButtons()
  }

  function updateButtons() {
    let rowData = this.getSelectedRowData()
    let isCountriesLb = this.isCountriesLeaderboard()
    let showPlayer = rowData != null && !this.forClans && !isCountriesLb
    let showClan = rowData != null && this.forClans

    ::showBtnTable(this.scene, {
      btn_usercard = showPlayer && hasFeature("UserCards")
      btn_clan_info = showClan
      btn_membership_req = showClan && !::is_in_clan() && ::clan_get_requested_clan_id() != this.getLbClanUid(rowData)
    })
  }

  function getLbPlayerUid(rowData) {
    return rowData?._id ? rowData._id.tostring() : null
  }

  function getLbPlayerName(rowData) {
    return getTblValue("name", rowData, "")
  }

  function getLbClanUid(rowData) {
    return rowData?._id ? rowData._id.tostring() : null
  }

  function onUserCard() {
    let rowData = this.getSelectedRowData()
    if (!rowData)
      return

    //not event leaderboards dont have player uids, so if no uid, we will search player by name
    let params = { name = this.getLbPlayerName(rowData) }
    let uid = this.getLbPlayerUid(rowData)
    if (uid)
      params.uid <- uid
    ::gui_modal_userCard(params)
  }

  function onUserDblClick() {
    if (this.forClans)
      this.onClanInfo()
    else
      this.onUserCard()
  }

  function onUserRClick() {
    if (this.isCountriesLeaderboard())
      return

    let rowData = this.getSelectedRowData()
    if (!rowData)
      return

    if (this.forClans) {
      let clanUid = this.getLbClanUid(rowData)
      if (clanUid)
        ::gui_right_click_menu(clanContextMenu.getClanActions(clanUid), this)
      return
    }

    playerContextMenu.showMenu(null, this, {
      playerName = this.getLbPlayerName(rowData)
      uid = this.getLbPlayerUid(rowData)
      canInviteToChatRoom = false
    })
  }

  function onRewards() {
  }
  function onTabChange() {}
  function onClanInfo() {
    let rowData = this.getSelectedRowData()
    if (rowData)
      ::showClanPage(this.getLbClanUid(rowData), "", "")
  }

  function onMembershipReq() {
    let rowData = this.getSelectedRowData()
    if (rowData)
      ::g_clans.requestMembership(this.getLbClanUid(rowData))
  }

  function onEventClanMembershipRequested(_p) {
    this.updateButtons()
  }

  function onModeSelect(obj) {
    if (!checkObj(obj) || this.lbModesList == null)
      return

    let val = obj.getValue()

    if (val >= 0 && val < this.lbModesList.len() && this.lbMode != this.lbModesList[val]) {
      this.lbMode = this.lbModesList[val]

      // check modesMask
      if (!this.curLbCategory.isVisibleByLbModeName(this.lbMode))
        this.curLbCategory = this.lb_presets[0]

      this.afterLoadSelfRow = this.requestSelfPage
      this.fetchLbData()

      ::add_big_query_record("global_leaderboard.select_mode", this.lbMode);
    }
  }

  onMapSelect = @(_obj) null
  onCountrySelect = @(_obj) null

  function prepareRequest() {
    let newRequest = {}
    foreach (fieldName, field in this.request)
      newRequest[fieldName] <- (fieldName in this) ? this[fieldName] : field
    foreach (tableConfigRow in this.lb_presets)
      if (tableConfigRow.field == newRequest.lbField)
        newRequest.inverse <- tableConfigRow.inverse
    return newRequest
  }

  function onChangeType(obj) {
    this.lbType = obj.getValue() ? ETTI_VALUE_INHISORY : ETTI_VALUE_TOTAL
    ::saveLocalByAccount("leaderboards_type", this.lbType)
    this.fetchLbData()
  }

  function onCategory(obj) {
    if (!checkObj(obj))
      return

    if (this.curLbCategory.id == obj.id) {
      if (this.rowsInPage != 0) {  // do not divide by zero
        let selfPos = this.getSelfPos()
        let selfPagePos = this.rowsInPage * floor(selfPos / this.rowsInPage)
        if (this.pos != selfPagePos)
          this.requestSelfPage(selfPos)
        else
          this.pos = 0
      }
    }
    else {
      this.curLbCategory = ::g_lb_category.getTypeById(obj.id)
      this.pos = 0
    }
    this.fetchLbData(true)
  }

  function isCountriesLeaderboard() {
    return false
  }

  function onDaySelect(_obj) {
  }
  //----END_CONTROLLER----//

  //----VIEW----//
  function initTable() {
    this.tableWeak = ::gui_handlers.LeaderboardTable.create({
      scene = this.scene.findObject("lb_table_nest")
      rowsInPage = this.rowsInPage
      onCategoryCb = Callback(this.onCategory, this)
      onRowSelectCb = Callback(this.onSelect, this)
      onRowHoverCb = ::show_console_buttons ? Callback(this.onSelect, this) : null
      onRowDblClickCb = Callback(this.onUserDblClick, this)
      onRowRClickCb = Callback(this.onUserRClick, this)
    }).weakref()
    this.registerSubHandler(this.tableWeak)
  }

  function initModes() {
    this.lbMode      = ""
    this.lbModesList = []

    local data  = ""

    foreach (_idx, mode in ::leaderboard_modes) {
      let diffCode = getTblValue("diffCode", mode)
      if (!::g_difficulty.isDiffCodeAvailable(diffCode, GM_DOMINATION))
        continue
      let reqFeature = getTblValue("reqFeature", mode)
      if (!hasAllFeatures(reqFeature))
        continue

      this.lbModesList.append(mode.mode)
      data += format("option {text:t='%s'}", mode.text)
    }

    let modesObj = this.showSceneBtn("modes_list", true)
    this.guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(0)
  }

  function getTopItemsTplView() {
    return {
      filter = [{
        id = "month_filter"
        text = "#mainmenu/btnMonthLb"
        cb = "onChangeType"
        filterCbValue = this.lbType == ETTI_VALUE_INHISORY ? "yes" : "no"
      }]
    }
  }

  function initTopItems() {
    let holder = this.scene.findObject("top_holder")
    if (!checkObj(holder))
      return

    let tplView = this.getTopItemsTplView()
    let data = ::handyman.renderCached("%gui/leaderboard/leaderboardTopItem.tpl", tplView)

    this.guiScene.replaceContentFromText(holder, data, data.len(), this)
  }

  function fetchLbData(_isForce = false) {
    if (this.tableWeak)
      this.tableWeak.showLoadingAnimation()

    this.lbField = this.curLbCategory.field
    this.lbModel.requestSelfRow(
      this.prepareRequest(),
      function (self_row_data) {
        this.selfRowData = self_row_data
        if (!this.selfRowData)
          return

        if (this.afterLoadSelfRow)
          this.afterLoadSelfRow(this.getSelfPos())

        this.afterLoadSelfRow = null
        this.lbModel.requestLeaderboard(this.prepareRequest(),
          function (leaderboard_data) {
            this.pageData = leaderboard_data
            this.fillLeaderboard(this.pageData)
          },
          this)
      },
      this)
  }

  function getLbRows() {
    return getTblValue("rows", this.pageData, [])
  }

  function fillLeaderboard(pgData) {
    if (!checkObj(this.scene))
      return

    let lbRows = this.getLbRows()
    let showHeader = pgData != null
    let showTable = (this.pos > 0 || lbRows.len() > 0) && this.selfRowData != null

    if (this.tableWeak) {
      this.tableWeak.updateParams(this.lbModel, this.lb_presets, this.curLbCategory, this, this.forClans)
      this.tableWeak.fillTable(lbRows, this.selfRowData, this.getSelfPos(), showHeader, showTable)
    }

    if (showTable)
      this.fillPagintator()
    else {
      ::hidePaginator(this.scene.findObject("paginator_place"))
      this.updateButtons()
    }

    this.fillAdditionalLeaderboardInfo(pgData)
  }

  function fillAdditionalLeaderboardInfo(_pgData) {
  }

  function fillPagintator() {
    if (this.rowsInPage == 0)
      return  // do not divide by zero

    let nestObj = this.scene.findObject("paginator_place")
    let curPage = (this.pos / this.rowsInPage).tointeger()
    if (this.tableWeak.isLastPage && (curPage == 0))
      ::hidePaginator(nestObj)
    else {
      let lastPageNumber = curPage + (this.tableWeak.isLastPage ? 0 : 1)
      let myPlace = this.getSelfPos()
      local myPage = myPlace >= 0 ? floor(myPlace / this.rowsInPage) : null
      ::generatePaginator(nestObj, this, curPage, lastPageNumber, myPage)
    }
  }
  //----END_VIEW----//
}

::gui_handlers.EventsLeaderboardWindow <- class extends ::gui_handlers.LeaderboardWindow {
  eventId = null
  sharedEconomicName = null

  inverse  = false
  request = null
  customSelfStats = null

  function initScreen() {
    let eventData = ::events.getEvent(this.eventId)
    if (!eventData)
      return this.goBack()

    let event = ::events.getEvent(this.eventId)
    if (event?.leaderboardEventTable != null) {
      this.customSelfStats = userstatCustomLeaderboardStats.value?.stats[event.leaderboardEventTable]
      refreshUserstatCustomLeaderboardStats()
    }

    this.request = ::events.getMainLbRequest(eventData)
    if (!this.lbModel)
      this.lbModel = ::events

    this.forClans = this.request?.forClans ?? this.forClans
    if (this.lb_presets == null)
      this.lb_presets = ::events.eventsTableConfig

    let sortLeaderboard = eventData?.sort_leaderboard
    this.curLbCategory = (sortLeaderboard != null)
      ? ::g_lb_category.getTypeByField(sortLeaderboard)
      : ::events.getTableConfigShortRowByEvent(eventData)

    this.updateLeaderboard()
    let nestObj = this.scene.findObject("tabs_list")
    if (!nestObj?.isValid())
      return

    let tabsArr = [
      {
        id = eventData.economicName
        name = ::events.getEventNameText(eventData)
      },
      {
        id = this.sharedEconomicName
        name = loc($"tournament/{this.sharedEconomicName}")
      }
    ].filter(@(v) v.id != null)
    let view = { tabs = [] }
    foreach (idx, tab in tabsArr)
      view.tabs.append({
        id = tab.id
        tabName = tab.name
        navImagesText = tabsArr.len() > 1 ? ::get_navigation_images_text(idx, tabsArr.len()) : ""
        selected = idx == 0
      })

    let data = ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(nestObj, data, data.len(), this)
  }

  function updateLeaderboard() {
    this.setRowsInPage()
    this.initTable()
    this.initTopItems()
    this.fetchLbData()
    this.updateButtons()
  }

  function getTopItemsTplView() {
    let res = {
      updateTime = [{}]
    }
    return res
  }


  function fillAdditionalLeaderboardInfo(pageData) {
    let updateTime = getTblValue("updateTime", pageData, 0)
    let timeStr = updateTime > 0
                    ? format("%s %s %s",
                               loc("mainmenu/lbUpdateTime"),
                               time.buildDateStr(updateTime),
                               time.buildTimeStr(updateTime, false, false))
                    : ""
    let lbUpdateTime = this.scene.findObject("lb_update_time")
    if (!checkObj(lbUpdateTime))
      return
    lbUpdateTime.setValue(timeStr)
  }

  function onTabChange(obj) {
    let curTabObj = obj.getChild(obj.getValue())
    if (!curTabObj?.isValid())
      return

    this.request.economicName = curTabObj.id
    this.updateLeaderboard()
  }

  function onEventUserstatCustomLeaderboardStats(_) {
    let event = ::events.getEvent(this.eventId)
    if (event?.leaderboardEventTable == null)
      return

    this.customSelfStats = userstatCustomLeaderboardStats.value?.stats[event.leaderboardEventTable]
    this.fillLeaderboard(this.pageData)
  }
}

::getLbItemCell <- function getLbItemCell(id, value, dataType, allowNegative = false) {
  let res = {
    id   = id
    text = dataType.getShortTextByValue(value, allowNegative)
  }

  let tooltipText =  dataType.getPrimaryTooltipText(value, allowNegative)
  if (tooltipText != "")
    res.tooltip <- tooltipText

  return res
}
