let { format } = require("string")
let { actionByLogType, saveOnlineJob } = require("%scripts/userLog/userlogUtils.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = ::require_native("guiOptions")

::hidden_userlogs <- [
  ::EULT_NEW_STREAK,
  ::EULT_SESSION_START,
  ::EULT_WW_START_OPERATION,
  ::EULT_WW_CREATE_OPERATION,
  ::EULT_WW_END_OPERATION,
  ::EULT_WW_AWARD
]

::popup_userlogs <- [
  ::EULT_SESSION_RESULT
  {
    type = ::EULT_CHARD_AWARD
    rewardType = [
      "WagerWin"
      "WagerFail"
      "WagerStageWin"
      "WagerStageFail"
    ]
  }
  ::EULT_EXCHANGE_WARBONDS
]

::userlog_pages <- [
  {
    id="all"
    hide = ::hidden_userlogs
  }
  {
    id="battle"
    show = [::EULT_EARLY_SESSION_LEAVE, ::EULT_SESSION_RESULT,
            ::EULT_AWARD_FOR_PVE_MODE]
  }
  {
    id="economic"
    show = [::EULT_BUYING_AIRCRAFT, ::EULT_REPAIR_AIRCRAFT, ::EULT_REPAIR_AIRCRAFT_MULTI,
            ::EULT_BUYING_WEAPON, ::EULT_BUYING_WEAPONS_MULTI, ::EULT_BUYING_WEAPON_FAIL,
            ::EULT_SESSION_RESULT, ::EULT_BUYING_MODIFICATION, ::EULT_BUYING_SPARE_AIRCRAFT,
            ::EULT_BUYING_UNLOCK, ::EULT_BUYING_RESOURCE,
            ::EULT_CHARD_AWARD, ::EULT_ADMIN_ADD_GOLD,
            ::EULT_ADMIN_REVERT_GOLD, ::EULT_BUYING_SCHEME, ::EULT_OPEN_ALL_IN_TIER,
            ::EULT_BUYING_MODIFICATION_MULTI, ::EULT_BUYING_MODIFICATION_FAIL, ::EULT_BUY_ITEM,
            ::EULT_BUY_BATTLE, ::EULT_CONVERT_EXPERIENCE, ::EULT_SELL_BLUEPRINT,
            ::EULT_EXCHANGE_WARBONDS, ::EULT_CLAN_ACTION,
            ::EULT_BUYENTITLEMENT, ::EULT_OPEN_TROPHY, ::EULT_CLAN_UNITS]
    checkFunc = function(userlogBlk)
    {
      let body = userlogBlk?.body
      if (!body)
        return true

      let logType = userlogBlk?.type
      if (logType == ::EULT_CLAN_ACTION
          || logType == ::EULT_BUYING_UNLOCK
          || logType == ::EULT_BUYING_RESOURCE)
        return ::getTblValue("goldCost", body, 0) > 0 || ::getTblValue("wpCost", body, 0) > 0

      if (logType == ::EULT_BUYENTITLEMENT)
        return ::getTblValue("cost", body, 0) > 0

      if (logType == ::EULT_OPEN_TROPHY)
        return ::getTblValue("gold", body, 0) > 0 || ::getTblValue("warpoints", body, 0) > 0

      return true
    }
  }
  {
    id="achivements"
    show = [::EULT_NEW_RANK, ::EULT_NEW_UNLOCK, ::EULT_CHARD_AWARD]
    checkFunc = function(userlog) { return !::g_battle_tasks.isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id="battletasks"
    reqFeature = "BattleTasks"
    show = [::EULT_PUNLOCK_ACCEPT, ::EULT_PUNLOCK_CANCELED, ::EULT_PUNLOCK_REROLL_PROPOSAL,
            ::EULT_PUNLOCK_EXPIRED, ::EULT_PUNLOCK_NEW_PROPOSAL, ::EULT_NEW_UNLOCK, ::EULT_PUNLOCK_ACCEPT_MULTI]
    unlocks = [::UNLOCKABLE_ACHIEVEMENT, ::UNLOCKABLE_TROPHY, ::UNLOCKABLE_WARBOND, ::UNLOCKABLE_AWARD]
    checkFunc = function(userlog) { return ::g_battle_tasks.isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id="crew"
    show = [::EULT_BUYING_SLOT, ::EULT_TRAINING_AIRCRAFT, ::EULT_UPGRADING_CREW,
            ::EULT_SPECIALIZING_CREW, ::EULT_PURCHASINGSKILLPOINTS]
  }
  {
    id = "items"
    reqFeature = "Items"
    show = [::EULT_BUY_ITEM, ::EULT_OPEN_TROPHY, ::EULT_NEW_ITEM, ::EULT_NEW_UNLOCK,
            ::EULT_ACTIVATE_ITEM, ::EULT_REMOVE_ITEM, ::EULT_TICKETS_REMINDER,
            ::EULT_CONVERT_BLUEPRINTS, ::EULT_INVENTORY_ADD_ITEM, ::EULT_INVENTORY_FAIL_ITEM]
    unlocks = [::UNLOCKABLE_TROPHY]
  }
  {
    id="onlineShop"
    show = [::EULT_BUYENTITLEMENT, ::EULT_BUYING_UNLOCK]
  }
  {
    id="worldWar"
    reqFeature = "WorldWar"
    show = [::EULT_WW_START_OPERATION, ::EULT_WW_CREATE_OPERATION, ::EULT_WW_END_OPERATION, ::EULT_WW_AWARD]
  }
]

::gui_modal_userLog <- function gui_modal_userLog()
{
  ::gui_start_modal_wnd(::gui_handlers.UserLogHandler)
}

::gui_handlers.UserLogHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/userlog.blk"

  fullLogs = null // Pure log with dub instances to match with user log count in blk
  logs = null // Without dub instances (everyDayLoginAward)
  listObj = null
  curPage = null

  nextLogId = 0
  logsPerPage = 10
  haveNext = false

  selectedIndex = 0

  slotbarActions = [ "take", "showroom", "testflight", "sec_weapons", "weapons", "info" ]

  logRowTplName = "%gui/userLog/userLogRow"

  function initScreen()
  {
    if (!::checkObj(scene))
      return goBack()

    listObj = scene.findObject("items_list")

    fillTabs()
  }

  function fillTabs()
  {
    mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(::OPTIONS_MODE_SEARCH)
    let value = ::get_gui_option(::USEROPT_USERLOG_FILTER)
    let curIdx = (value in ::userlog_pages)? value : 0

    let view = {
      tabs = []
    }
    foreach(idx, page in ::userlog_pages)
    {
      if (::getTblValue("reqFeature", page) && !::has_feature(page.reqFeature))
        continue
      view.tabs.append({
        id = "page_" + idx
        cornerImg = "#ui/gameuiskin#new_icon.svg"
        cornerImgId = "img_new_" + page.id
        cornerImgSmall = true
        tabName = "#userlog/page/" + page.id
        navImagesText = ::get_navigation_images_text(idx, ::userlog_pages.len())
      })
    }
    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    let tabsObj = scene.findObject("tabs_list")
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    updateTabNewIconWidgets()

    tabsObj.setValue(curIdx)
  }

  function getNewMessagesByPages()
  {
    let res = array(::userlog_pages.len(), 0)
    let total = ::get_user_logs_count()
    for(local i=0; i<total; i++)
    {
      let blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)

      if (blk?.disabled) // was seen
        continue

      foreach(idx, page in ::userlog_pages)
        if (::isUserlogVisible(blk, page, i))
          res[idx]++
    }
    return res
  }

  function initPage(page)
  {
    if (!page) return
    curPage = page

    fullLogs = getUserLogsList(curPage)
    logs = fullLogs.filter(@(p) !p?.isDubTrophy)
    guiScene.replaceContentFromText(listObj, "", 0, this)
    nextLogId = 0
    haveNext = false
    addLogsPage()
    let childrenCount = listObj.childrenCount() - (haveNext ? 1 : 0)
    if (selectedIndex < childrenCount || childrenCount > 0)
    {
      selectedIndex = clamp(selectedIndex, 0, childrenCount - 1)
      listObj.setValue(selectedIndex);
    }
    ::move_mouse_on_child_by_value(listObj)

    let msgObj = scene.findObject("middle_message")
    msgObj.show(logs.len()==0)
    if (logs.len()==0)
      msgObj.setValue(::loc("userlog/noMessages"))
  }

  function addLogsPage()
  {
    if (nextLogId>=logs.len())
      return

    guiScene.setUpdatesEnabled(false, false)
    let showTo = (nextLogId+logsPerPage < logs.len())? nextLogId+logsPerPage : logs.len()

    local data=""
    for(local i=nextLogId; i<showTo; i++)
      if (i!=nextLogId || !haveNext)
      {
        let rowName = "row"+logs[i].idx
        data += format("expandable { id:t='%s' } ", rowName)
      }
    guiScene.appendWithBlk(listObj, data, this)

    for(local i=nextLogId; i<showTo; i++)
      fillLog(logs[i])
    nextLogId=showTo

    haveNext = nextLogId<logs.len()
    if (haveNext)
      addNextButton(logs[nextLogId])

    guiScene.setUpdatesEnabled(true, true)
  }

  function fillLog(log)
  {
    let rowName = "row"+log.idx
    let rowObj = listObj.findObject(rowName)
    let rowData = ::get_userlog_view_data(log)
    if ((rowData?.descriptionBlk ?? "") != "")
      rowData.hasExpandImg <- true
    let viewBlk = ::handyman.renderCached(logRowTplName, rowData)

    guiScene.replaceContentFromText(rowObj, viewBlk, viewBlk.len(), this)

    rowObj.tooltip = rowData.tooltip
    if (log.enabled)
      rowObj.status="owned"
  }

  function addNextButton(log)
  {
    let rowName = "row"+log.idx
    local rowObj = listObj.findObject(rowName)
    if (!rowObj)
    {
      let data = format("expandable { id:t='%s' } ", rowName)
      guiScene.appendWithBlk(listObj, data, this)
      rowObj = listObj.findObject(rowName)
    }

    let viewBlk = ::handyman.renderCached(logRowTplName,
      {
        middle = ::loc("userlog/showMore")
      })
    guiScene.replaceContentFromText(rowObj, viewBlk, viewBlk.len(), this)
  }

  function saveOnlineJobWithUpdate()
  {
    taskId = saveOnlineJob()
    ::dagor.debug("saveOnlineJobWithUpdate")
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = updateTabNewIconWidgets
    }
  }

  function markCurrentPageSeen()
  {
    local needSave = false
    if (fullLogs)
      foreach(log in fullLogs)
        if (log.enabled && log.idx >= 0 && log.idx < ::get_user_logs_count())
        {
          if (::disable_user_log_entry(log.idx))
            needSave = true
        }

    if (needSave)
      saveOnlineJobWithUpdate()
  }

  function markItemSeen(index)
  {
    local needSave = false

    let total = ::get_user_logs_count()
    local counter = 0
    for(local i=total-1; i>=0; i--)
    {
      let blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)
      if (!::isInArray(blk?.type, ::hidden_userlogs))
      {
        if (index == counter && !blk?.disabled)
        {
          if (::disable_user_log_entry(i))
          {
            needSave = true
            break;
          }
        }
        counter++
      }
    }

    if (needSave)
      saveOnlineJobWithUpdate()
  }

  function updateTabNewIconWidgets()
  {
    if (!::checkObj(scene))
      return

    let newMsgs = getNewMessagesByPages()
    foreach(idx, count in newMsgs)
    {
      let obj = scene.findObject("img_new_" + ::userlog_pages[idx].id)
      if (::checkObj(obj))
        obj.show(count > 0)
    }
    update_gamercards();
  }

  function goBack()
  {
    markCurrentPageSeen()

    ::g_tasker.restoreCharCallback()
    afterSlotOp = null;
    taskId = null

    restoreMainOptions()
    base.goBack()
  }

  function onUserLog(obj)
  {
    goBack()
  }

  function onItemSelect(obj)
  {
    if (!obj)
      return

    let index = obj.getValue();
    let childrenCount = obj.childrenCount()
    if (index != selectedIndex && selectedIndex != -1)
    {
      markItemSeen(selectedIndex);
      if (selectedIndex < childrenCount)
        obj.getChild(selectedIndex).status=""
    }
    selectedIndex = index;

    if (haveNext && selectedIndex == (childrenCount-1))
    {
      addLogsPage()
      obj.setValue(selectedIndex)
    }
    guiScene.applyPendingChanges(false)
    let childObj = obj.getChild(selectedIndex)
    if (!::check_obj(childObj))
      return

    childObj.scrollToView()
    ::move_mouse_on_obj(childObj)
  }

  function onChangePage(obj)
  {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let idx = ::to_integer_safe(::getObjIdByPrefix(obj.getChild(value), "page_"), -1)
    let newPage = ::getTblValue(idx, ::userlog_pages)
    if (!newPage || newPage == curPage)
      return

    if (logs)
    {
      markCurrentPageSeen()
      updateTabNewIconWidgets()
    }
    initPage(newPage)
    ::set_gui_option(::USEROPT_USERLOG_FILTER, value)
    ::update_gamercards()
  }

  function onRefresh(obj)
  {
    if (logs)
    {
      markCurrentPageSeen()
      updateTabNewIconWidgets()
    }
    initPage(curPage)
    ::update_gamercards()
  }

  function onUpdateItemsDef()
  {
    if (logs)
      for(local i=0; i<nextLogId; i++)
      {
        log = logs[i]
        if (::isInArray(log.type, [ ::EULT_INVENTORY_ADD_ITEM, ::EULT_OPEN_TROPHY ]))
        {
          fillLog(log)
        }
      }
  }

  function onEventItemsShopUpdate(params)
  {
    doWhenActiveOnce("onUpdateItemsDef")
  }

  function onUserLogAction(obj)
  {
    let logIdx = obj?.logIdx
    let log = logIdx != null
      ? ::u.search(logs, @(l) l.idx == logIdx.tointeger())
      : logs?[selectedIndex]
    if (!log)
      return

    actionByLogType?[log.type](log)
  }
}
