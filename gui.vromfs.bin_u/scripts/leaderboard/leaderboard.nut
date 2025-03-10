from "%scripts/dagui_natives.nut" import clan_get_requested_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
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
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { lbCategoryTypes, getLbCategoryTypeByField, getLbCategoryTypeById, eventsTableConfig
} = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { leaderboardModel } = require("%scripts/leaderboard/leaderboardHelpers.nut")
let { generatePaginator, hidePaginator } = require("%scripts/viewUtils/paginator.nut")
let { gui_modal_userCard } = require("%scripts/user/userCard/userCardView.nut")
let { requestMembership } = require("%scripts/clans/clanRequests.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")

let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

let showClanPageModal = require("%scripts/clans/showClanPageModal.nut")

::leaderboards_list <- [
  lbCategoryTypes.PVP_RATIO
  lbCategoryTypes.VICTORIES_BATTLES
  lbCategoryTypes.AVERAGE_RELATIVE_POSITION
  lbCategoryTypes.AIR_KILLS
  lbCategoryTypes.GROUND_KILLS
  lbCategoryTypes.NAVAL_KILLS
  lbCategoryTypes.AVERAGE_ACTIVE_KILLS_BY_SPAWN
  lbCategoryTypes.AVERAGE_SCRIPT_KILLS_BY_SPAWN
  lbCategoryTypes.AVERAGE_SCORE
]

::leaderboard_modes <- [
  {
    
    text = "#mainmenu/arcadeInstantAction"
    mode = "arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    
    text = "#mainmenu/instantAction"
    mode = "historical"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    
    text = "#mainmenu/fullRealInstantAction"
    mode = "simulation"
    diffCode = DIFFICULTY_HARDCORE
  }

  {
    
    text = "#missions/air_event_arcade"
    mode = "air_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    
    text = "#missions/air_event_historical"
    mode = "air_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    
    text = "#missions/air_event_simulator"
    mode = "air_simulation"
    diffCode = DIFFICULTY_HARDCORE
  }
  {
    
    text = "#missions/tank_event_arcade"
    mode = "tank_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    
    text = "#missions/tank_event_historical"
    mode = "tank_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    
    text = "#missions/tank_event_simulator"
    mode = "tank_simulation"
    diffCode = DIFFICULTY_HARDCORE
  }
  {
    
    text = "#missions/ship_event_arcade"
    mode = "test_ship_arcade"
    diffCode = DIFFICULTY_ARCADE
  }
  {
    
    text = "#missions/ship_event_historical"
    mode = "test_ship_realistic"
    diffCode = DIFFICULTY_REALISTIC
  }
  {
    
    text = "#missions/helicopter_event"
    mode = "helicopter_arcade"
    diffCode = DIFFICULTY_ARCADE
    reqFeature = [ "HiddenLeaderboardRows" ]
  }
]

function gui_modal_event_leaderboards(params) {
  loadHandler(gui_handlers.EventsLeaderboardWindow, params)
}

gui_handlers.LeaderboardWindow <- class (gui_handlers.BaseGuiHandlerWT) {
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
  userId        = null
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
    userId     = null
  }
  pageData    = null
  selfRowData = null

  curDataRowIdx = -1

  afterLoadSelfRow = null
  tableWeak = null

  function initScreen() {
    reqUnlockByClient("view_leaderboards")
    if (!this.lbModel) {
      this.lbModel = leaderboardModel
      this.lbModel.reset()
    }
    if (!this.lb_presets)
      this.lb_presets = ::leaderboards_list

    this.curLbCategory = this.lb_presets[0]
    this.lbType = loadLocalByAccount("leaderboards_type", ETTI_VALUE_INHISORY)
    this.platformFilter = getSeparateLeaderboardPlatformName()
    this.setRowsInPage()

    sendBqEvent("CLIENT_POPUP_1", "global_leaderboard.open", { platformFilter = this.platformFilter })

    this.initTable()
    this.initModes()
    this.initTopItems()
    this.fetchLbData()
    this.updateButtons()
  }

  
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
      return  

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

    showObjectsByTable(this.scene, {
      btn_usercard = showPlayer && hasFeature("UserCards")
      btn_clan_info = showClan
      btn_membership_req = showClan && !is_in_clan() && clan_get_requested_clan_id() != this.getLbClanUid(rowData)
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

    
    let params = { name = this.getLbPlayerName(rowData) }
    let uid = this.getLbPlayerUid(rowData)
    if (uid)
      params.uid <- uid
    gui_modal_userCard(params)
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
        openRightClickMenu(clanContextMenu.getClanActions(clanUid), this)
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
      showClanPageModal(this.getLbClanUid(rowData), "", "")
  }

  function onMembershipReq() {
    let rowData = this.getSelectedRowData()
    if (rowData)
      requestMembership(this.getLbClanUid(rowData))
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

      
      if (!this.curLbCategory.isVisibleByLbModeName(this.lbMode))
        this.curLbCategory = this.lb_presets[0]

      this.afterLoadSelfRow = this.requestSelfPage
      this.fetchLbData()

      sendBqEvent("CLIENT_POPUP_1", "global_leaderboard.select_mode", { select_mode = this.lbMode })
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
    saveLocalByAccount("leaderboards_type", this.lbType)
    this.fetchLbData()
  }

  function onCategory(obj) {
    if (!checkObj(obj))
      return

    if (this.curLbCategory.id == obj.id) {
      if (this.rowsInPage != 0) {  
        let selfPos = this.getSelfPos()
        let selfPagePos = this.rowsInPage * floor(selfPos / this.rowsInPage)
        if (this.pos != selfPagePos)
          this.requestSelfPage(selfPos)
        else
          this.pos = 0
      }
    }
    else {
      this.curLbCategory = getLbCategoryTypeById(obj.id)
      this.pos = 0
    }
    this.fetchLbData(true)
  }

  function isCountriesLeaderboard() {
    return false
  }

  function onDaySelect(_obj) {
  }
  

  
  function initTable() {
    this.tableWeak = gui_handlers.LeaderboardTable.create({
      scene = this.scene.findObject("lb_table_nest")
      rowsInPage = this.rowsInPage
      onCategoryCb = Callback(this.onCategory, this)
      onRowSelectCb = Callback(this.onSelect, this)
      onRowHoverCb = showConsoleButtons.value ? Callback(this.onSelect, this) : null
      onRowDblClickCb = Callback(this.onUserDblClick, this)
      onRowRClickCb = Callback(this.onUserRClick, this)
    }).weakref()
    this.registerSubHandler(this.tableWeak)
  }

  function initModes() {
    this.lbMode      = ""
    this.lbModesList = []

    local data = []
    foreach (_idx, mode in ::leaderboard_modes) {
      let diffCode = getTblValue("diffCode", mode)
      if (!g_difficulty.isDiffCodeAvailable(diffCode, GM_DOMINATION))
        continue
      let reqFeature = getTblValue("reqFeature", mode)
      if (!hasAllFeatures(reqFeature))
        continue

      this.lbModesList.append(mode.mode)
      data.append(format("option {text:t='%s'}", mode.text))
    }

    let modesObj = showObjById("modes_list", true, this.scene)
    let markup = "".join(data)
    this.guiScene.replaceContentFromText(modesObj, markup, markup.len(), this)
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
    let data = handyman.renderCached("%gui/leaderboard/leaderboardTopItem.tpl", tplView)

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
      hidePaginator(this.scene.findObject("paginator_place"))
      this.updateButtons()
    }

    this.fillAdditionalLeaderboardInfo(pgData)
  }

  function fillAdditionalLeaderboardInfo(_pgData) {
  }

  function fillPagintator() {
    if (this.rowsInPage == 0)
      return  

    let nestObj = this.scene.findObject("paginator_place")
    let curPage = (this.pos / this.rowsInPage).tointeger()
    if (this.tableWeak.isLastPage && (curPage == 0))
      hidePaginator(nestObj)
    else {
      let lastPageNumber = curPage + (this.tableWeak.isLastPage ? 0 : 1)
      let myPlace = this.getSelfPos()
      local myPage = myPlace >= 0 ? floor(myPlace / this.rowsInPage) : null
      generatePaginator(nestObj, this, curPage, lastPageNumber, myPage)
    }
  }
  
}

gui_handlers.EventsLeaderboardWindow <- class (gui_handlers.LeaderboardWindow) {
  eventId = null
  sharedEconomicName = null

  inverse  = false
  request = null
  customSelfStats = null

  function initScreen() {
    let eventData = events.getEvent(this.eventId)
    if (!eventData)
      return this.goBack()

    let event = events.getEvent(this.eventId)
    if (event?.leaderboardEventTable != null) {
      this.customSelfStats = userstatCustomLeaderboardStats.value?.stats[event.leaderboardEventTable]
      refreshUserstatCustomLeaderboardStats()
    }

    this.request = events.getMainLbRequest(eventData)
    if (!this.lbModel)
      this.lbModel = events

    this.forClans = this.request?.forClans ?? this.forClans
    if (this.lb_presets == null)
      this.lb_presets = eventsTableConfig

    let sortLeaderboard = eventData?.sort_leaderboard
    this.curLbCategory = (sortLeaderboard != null)
      ? getLbCategoryTypeByField(sortLeaderboard)
      : events.getTableConfigShortRowByEvent(eventData)

    this.updateLeaderboard()
    let nestObj = this.scene.findObject("tabs_list")
    if (!nestObj?.isValid())
      return

    let tabsArr = [
      {
        id = eventData.economicName
        name = events.getEventNameText(eventData)
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
        navImagesText = tabsArr.len() > 1 ? getNavigationImagesText(idx, tabsArr.len()) : ""
        selected = idx == 0
      })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
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
    let event = events.getEvent(this.eventId)
    if (event?.leaderboardEventTable == null)
      return

    this.customSelfStats = userstatCustomLeaderboardStats.value?.stats[event.leaderboardEventTable]
    this.fillLeaderboard(this.pageData)
  }
}

return {
  openLeaderboardWindow = @() loadHandler(gui_handlers.LeaderboardWindow)
  gui_modal_event_leaderboards
}