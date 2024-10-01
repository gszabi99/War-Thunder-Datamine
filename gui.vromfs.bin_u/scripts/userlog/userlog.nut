//-file:plus-string
from "%scripts/dagui_natives.nut" import get_user_logs_count, get_user_log_blk_body, copy_to_clipboard, set_char_cb, disable_user_log_entry
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { move_mouse_on_child_by_value, move_mouse_on_obj, loadHandler, isInMenu
} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { set_gui_option, get_gui_option, setGuiOptionsMode, getGuiOptionsMode
} = require("guiOptions")
let { saveOnlineJob } = require("%scripts/userLog/userlogUtils.nut")
let { get_userlog_plain_text } = require("%scripts/userLog/userlogPlainText.nut")
let { isUserlogForBattleTasksGroup } = require("%scripts/unlocks/battleTasks.nut")
let { OPTIONS_MODE_SEARCH, USEROPT_USERLOG_FILTER
} = require("%scripts/options/optionsExtNames.nut")
let { restoreCharCallback } = require("%scripts/tasker.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { guiStartBattleTasksWnd } = require("%scripts/unlocks/battleTasksHandler.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")

::hidden_userlogs <- [
  EULT_NEW_STREAK,
  EULT_SESSION_START,
  EULT_WW_START_OPERATION,
  EULT_WW_CREATE_OPERATION,
  EULT_WW_END_OPERATION,
  EULT_WW_AWARD
]

::popup_userlogs <- [
  EULT_SESSION_RESULT
  {
    type = EULT_CHARD_AWARD
    rewardType = [
      "WagerWin"
      "WagerFail"
      "WagerStageWin"
      "WagerStageFail"
    ]
  }
  EULT_EXCHANGE_WARBONDS
]

function isMissionExtrCheckFucn(userLog) {
  if (userLog?.type != EULT_INVENTORY_ADD_ITEM || userLog?.roomId == null)
    return true

  return ::getUserLogsList({ show = [EULT_SESSION_RESULT] }).findvalue(function(battleLog) {
    let isMissionExtrLog = isMissionExtrByName(battleLog?.mission ?? "")
    return isMissionExtrLog && (battleLog?.roomId == userLog.roomId)
  }) == null
}

::userlog_pages <- [
  {
    id = "all"
    hide = ::hidden_userlogs
    checkFunc = isMissionExtrCheckFucn
  }
  {
    id = "battle"
    show = [EULT_EARLY_SESSION_LEAVE, EULT_SESSION_RESULT,
            EULT_AWARD_FOR_PVE_MODE]
  }
  {
    id = "economic"
    show = [EULT_BUYING_AIRCRAFT, EULT_REPAIR_AIRCRAFT, EULT_REPAIR_AIRCRAFT_MULTI,
            EULT_BUYING_WEAPON, EULT_BUYING_WEAPONS_MULTI, EULT_BUYING_WEAPON_FAIL,
            EULT_SESSION_RESULT, EULT_BUYING_MODIFICATION, EULT_BUYING_SPARE_AIRCRAFT,
            EULT_BUYING_UNLOCK, EULT_BUYING_RESOURCE,
            EULT_CHARD_AWARD, EULT_ADMIN_ADD_GOLD,
            EULT_ADMIN_REVERT_GOLD, EULT_BUYING_SCHEME, EULT_OPEN_ALL_IN_TIER,
            EULT_BUYING_MODIFICATION_MULTI, EULT_BUYING_MODIFICATION_FAIL, EULT_BUY_ITEM,
            EULT_BUY_BATTLE, EULT_CONVERT_EXPERIENCE, EULT_SELL_BLUEPRINT,
            EULT_EXCHANGE_WARBONDS, EULT_CLAN_ACTION,
            EULT_BUYENTITLEMENT, EULT_OPEN_TROPHY, EULT_CLAN_UNITS]
    checkFunc = function(userlogBlk) {
      let body = userlogBlk?.body
      if (!body)
        return true

      let logType = userlogBlk?.type
      if (logType == EULT_CLAN_ACTION
          || logType == EULT_BUYING_UNLOCK
          || logType == EULT_BUYING_RESOURCE)
        return getTblValue("goldCost", body, 0) > 0 || getTblValue("wpCost", body, 0) > 0

      if (logType == EULT_BUYENTITLEMENT)
        return getTblValue("cost", body, 0) > 0

      if (logType == EULT_OPEN_TROPHY)
        return getTblValue("gold", body, 0) > 0 || getTblValue("warpoints", body, 0) > 0

      return true
    }
  }
  {
    id = "achivements"
    show = [EULT_NEW_RANK, EULT_NEW_UNLOCK, EULT_CHARD_AWARD]
    checkFunc = function(userlog) { return !isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id = "battletasks"
    reqFeature = "BattleTasks"
    show = [EULT_PUNLOCK_ACCEPT, EULT_PUNLOCK_CANCELED, EULT_PUNLOCK_REROLL_PROPOSAL,
            EULT_PUNLOCK_EXPIRED, EULT_PUNLOCK_NEW_PROPOSAL, EULT_NEW_UNLOCK, EULT_PUNLOCK_ACCEPT_MULTI]
    unlocks = [UNLOCKABLE_ACHIEVEMENT, UNLOCKABLE_TROPHY, UNLOCKABLE_WARBOND, UNLOCKABLE_AWARD]
    checkFunc = function(userlog) { return isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id = "crew"
    show = [EULT_BUYING_SLOT, EULT_TRAINING_AIRCRAFT, EULT_UPGRADING_CREW,
            EULT_SPECIALIZING_CREW, EULT_PURCHASINGSKILLPOINTS]
  }
  {
    id = "items"
    reqFeature = "Items"
    show = [EULT_BUY_ITEM, EULT_OPEN_TROPHY, EULT_NEW_ITEM, EULT_NEW_UNLOCK,
            EULT_ACTIVATE_ITEM, EULT_REMOVE_ITEM, EULT_TICKETS_REMINDER,
            EULT_CONVERT_BLUEPRINTS, EULT_INVENTORY_ADD_ITEM, EULT_INVENTORY_FAIL_ITEM]
    unlocks = [UNLOCKABLE_TROPHY]
    checkFunc = isMissionExtrCheckFucn
  }
  {
    id = "onlineShop"
    show = [EULT_BUYENTITLEMENT, EULT_BUYING_UNLOCK]
  }
  {
    id = "worldWar"
    reqFeature = "WorldWar"
    show = [EULT_WW_START_OPERATION, EULT_WW_CREATE_OPERATION, EULT_WW_END_OPERATION, EULT_WW_AWARD]
  }
  {
    id = "systemNotifications"
    show = [EULT_COMPLAINT_UPHELD]
  }
]

::gui_modal_userLog <- function gui_modal_userLog() {
  loadHandler(gui_handlers.UserLogHandler)
}

let actionByLogType = {
  [EULT_PUNLOCK_ACCEPT]       = @(_log) guiStartBattleTasksWnd(),
  [EULT_PUNLOCK_EXPIRED]      = @(_log) guiStartBattleTasksWnd(),
  [EULT_PUNLOCK_CANCELED]     = @(_log) guiStartBattleTasksWnd(),
  [EULT_PUNLOCK_NEW_PROPOSAL] = @(_log) guiStartBattleTasksWnd(),
  [EULT_PUNLOCK_ACCEPT_MULTI] = @(_log) guiStartBattleTasksWnd(),
  [EULT_INVITE_TO_TOURNAMENT] = function (logObj) {
    let battleId = logObj?.battleId
    if (battleId == null)
      return

    if (!isInMenu())
      return ::g_invites.showLeaveSessionFirstPopup()

    if (!antiCheat.showMsgboxIfEacInactive({ enableEAC = true }))
      return

    if (!isCrossPlayEnabled())
      return addPopup(null, colorize("warningTextColor", loc("xbox/crossPlayRequired")))

    log($"join to tournament battle with id {battleId}")
    get_cur_gui_scene().performDelayed({}, @() ::SessionLobby.joinBattle(logObj.battleId))
  }
}

gui_handlers.UserLogHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/userlog.blk"

  fullLogs = null // Pure logObj with dub instances to match with user logObj count in blk
  logs = null // Without dub instances (everyDayLoginAward)
  listObj = null
  curPage = null

  nextLogId = 0
  logsPerPage = 10
  haveNext = false

  selectedIndex = 0
  currentLog = null

  slotbarActions = [ "take", "showroom", "testflight", "sec_weapons", "weapons", "info" ]

  logRowTplName = "%gui/userLog/userLogRow.tpl"

  function initScreen() {
    if (!checkObj(this.scene))
      return this.goBack()

    this.listObj = this.scene.findObject("items_list")

    this.fillTabs()
  }

  function fillTabs() {
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(OPTIONS_MODE_SEARCH)
    let value = get_gui_option(USEROPT_USERLOG_FILTER)
    let curIdx = (value in ::userlog_pages) ? value : 0

    let view = {
      tabs = []
    }
    foreach (idx, page in ::userlog_pages) {
      if (getTblValue("reqFeature", page) && !hasFeature(page.reqFeature))
        continue
      view.tabs.append({
        id = $"page_{idx}"
        cornerImg = "#ui/gameuiskin#new_icon.svg"
        cornerImgId =$"img_new_{page.id}"
        cornerImgSmall = true
        tabName =$"#userlog/page/{page.id}"
        navImagesText = ::get_navigation_images_text(idx, ::userlog_pages.len())
      })
    }
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let tabsObj = this.scene.findObject("tabs_list")
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    this.updateTabNewIconWidgets()

    tabsObj.setValue(curIdx)
  }

  function getNewMessagesByPages() {
    let res = array(::userlog_pages.len(), 0)
    let total = get_user_logs_count()
    for (local i = 0; i < total; i++) {
      let blk = DataBlock()
      get_user_log_blk_body(i, blk)

      if (blk?.disabled) // was seen
        continue

      foreach (idx, page in ::userlog_pages)
        if (::isUserlogVisible(blk, page, i))
          res[idx]++
    }
    return res
  }

  function initPage(page) {
    if (!page)
      return
    this.curPage = page

    this.fullLogs = ::getUserLogsList(this.curPage)
    this.logs = this.fullLogs.filter(@(p) !p?.isDubTrophy)
    this.guiScene.replaceContentFromText(this.listObj, "", 0, this)
    this.nextLogId = 0
    this.haveNext = false
    this.addLogsPage()
    let childrenCount = this.listObj.childrenCount() - (this.haveNext ? 1 : 0)
    if (this.selectedIndex < childrenCount || childrenCount > 0) {
      this.selectedIndex = clamp(this.selectedIndex, 0, childrenCount - 1)
      this.listObj.setValue(this.selectedIndex);
    }
    move_mouse_on_child_by_value(this.listObj)

    let msgObj = this.scene.findObject("middle_message")
    msgObj.show(this.logs.len() == 0)
    if (this.logs.len() == 0)
      msgObj.setValue(loc("userlog/noMessages"))
    this.setCurrentLogForCopy()
  }

  function setCurrentLogForCopy() {
    this.currentLog = this.logs?[this.selectedIndex]
    if(this.currentLog != null && ![EULT_EARLY_SESSION_LEAVE, EULT_SESSION_RESULT].contains(this.currentLog.type))
      this.currentLog = null
  }

  function addLogsPage() {
    if (this.nextLogId >= this.logs.len())
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let showTo = (this.nextLogId + this.logsPerPage < this.logs.len()) ? this.nextLogId + this.logsPerPage : this.logs.len()

    local data = ""
    for (local i = this.nextLogId; i < showTo; i++)
      if (i != this.nextLogId || !this.haveNext) {
        let rowName = "row" + this.logs[i].idx
        data += format("expandable { id:t='%s' } ", rowName)
      }
    this.guiScene.appendWithBlk(this.listObj, data, this)

    for (local i = this.nextLogId; i < showTo; i++)
      this.fillLog(this.logs[i])
    this.nextLogId = showTo

    this.haveNext = this.nextLogId < this.logs.len()
    if (this.haveNext)
      this.addNextButton(this.logs[this.nextLogId])

    this.guiScene.setUpdatesEnabled(true, true)
  }

  function fillLog(logObj) {
    let rowName =$"row{logObj.idx}"
    let rowObj = this.listObj.findObject(rowName)
    let rowData = ::get_userlog_view_data(logObj)
    if ((rowData?.descriptionBlk ?? "") != "")
      rowData.hasExpandImg <- true
    let viewBlk = handyman.renderCached(this.logRowTplName, rowData)

    this.guiScene.replaceContentFromText(rowObj, viewBlk, viewBlk.len(), this)

    if (logObj.type != EULT_SESSION_RESULT) // for this case tooltip setted inside userLogRow.tpl
      rowObj.tooltip = rowData.tooltip

    if (logObj.enabled)
      rowObj.status = "owned"
  }

  function addNextButton(logObj) {
    let rowName =$"row{logObj.idx}"
    local rowObj = this.listObj.findObject(rowName)
    if (!rowObj) {
      let data = format("expandable { id:t='%s' } ", rowName)
      this.guiScene.appendWithBlk(this.listObj, data, this)
      rowObj = this.listObj.findObject(rowName)
    }

    let viewBlk = handyman.renderCached(this.logRowTplName,
      {
        middle = loc("userlog/showMore")
      })
    this.guiScene.replaceContentFromText(rowObj, viewBlk, viewBlk.len(), this)
  }

  function saveOnlineJobWithUpdate() {
    this.taskId = saveOnlineJob()
    log("saveOnlineJobWithUpdate")
    if (this.taskId >= 0) {
      set_char_cb(this, this.slotOpCb)
      this.afterSlotOp = this.updateTabNewIconWidgets
    }
  }

  function markCurrentPageSeen() {
    local needSave = false
    if (this.fullLogs)
      foreach (logObj in this.fullLogs)
        if (logObj.enabled && logObj.idx >= 0 && logObj.idx < get_user_logs_count()) {
          if (disable_user_log_entry(logObj.idx))
            needSave = true
        }

    if (needSave)
      this.saveOnlineJobWithUpdate()
  }

  function markItemSeen(index) {
    local needSave = false

    let total = get_user_logs_count()
    local counter = 0
    for (local i = total - 1; i >= 0; i--) {
      let blk = DataBlock()
      get_user_log_blk_body(i, blk)
      if (!isInArray(blk?.type, ::hidden_userlogs)) {
        if (index == counter && !blk?.disabled) {
          if (disable_user_log_entry(i)) {
            needSave = true
            break;
          }
        }
        counter++
      }
    }

    if (needSave)
      this.saveOnlineJobWithUpdate()
  }

  function updateTabNewIconWidgets() {
    if (!checkObj(this.scene))
      return

    let newMsgs = this.getNewMessagesByPages()
    foreach (idx, count in newMsgs) {
      let obj = this.scene.findObject("img_new_" + ::userlog_pages[idx].id)
      if (checkObj(obj))
        obj.show(count > 0)
    }
    ::update_gamercards()
  }

  function goBack() {
    this.markCurrentPageSeen()

    restoreCharCallback()
    this.afterSlotOp = null;
    this.taskId = null

    this.restoreMainOptions()
    base.goBack()
  }

  function onUserLog(_obj) {
    this.goBack()
  }

  function onItemSelect(obj) {
    if (!obj)
      return

    let index = obj.getValue();
    let childrenCount = obj.childrenCount()
    if (index != this.selectedIndex && this.selectedIndex != -1) {
      this.markItemSeen(this.selectedIndex);
      if (this.selectedIndex < childrenCount)
        obj.getChild(this.selectedIndex).status = ""
    }
    this.selectedIndex = index;

    if (this.haveNext && this.selectedIndex == (childrenCount - 1)) {
      this.addLogsPage()
      obj.setValue(this.selectedIndex)
    }

    this.setCurrentLogForCopy()

    this.guiScene.applyPendingChanges(false)
    let childObj = obj.getChild(this.selectedIndex)
    if (!checkObj(childObj))
      return

    childObj.scrollToView()
    move_mouse_on_obj(childObj)
  }

  function onChangePage(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let idx = to_integer_safe(::getObjIdByPrefix(obj.getChild(value), "page_"), -1)
    let newPage = getTblValue(idx, ::userlog_pages)
    if (!newPage || newPage == this.curPage)
      return

    if (this.logs) {
      this.markCurrentPageSeen()
      this.updateTabNewIconWidgets()
    }
    this.initPage(newPage)
    set_gui_option(USEROPT_USERLOG_FILTER, value)
    ::update_gamercards()
  }

  function onRefresh(_obj) {
    if (this.logs) {
      this.markCurrentPageSeen()
      this.updateTabNewIconWidgets()
    }
    this.initPage(this.curPage)
    ::update_gamercards()
  }

  function onUpdateItemsDef() {
    if (this.logs)
      for (local i = 0; i < this.nextLogId; i++) {
        let logObj = this.logs[i]
        if (isInArray(logObj.type, [ EULT_INVENTORY_ADD_ITEM, EULT_OPEN_TROPHY ])) {
          this.fillLog(logObj)
        }
      }
  }

  function onEventItemsShopUpdate(_params) {
    this.doWhenActiveOnce("onUpdateItemsDef")
  }

  function onUserLogAction(obj) {
    let logIdx = obj?.logIdx
    let logObj = logIdx != null
      ? u.search(this.logs, @(l) l.idx == logIdx.tointeger())
      : this.logs?[this.selectedIndex]
    if (!logObj)
      return

    actionByLogType?[logObj.type](logObj)
  }

  function copyToClipboard() {
    if(this.currentLog == null)
      return
    copy_to_clipboard(get_userlog_plain_text(this.currentLog))
  }
}
