local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")

::CLAN_LOG_ROWS_IN_PAGE <- 10
::show_clan_log <- function show_clan_log(clanId)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.clanLogModal,
    {clanId = clanId}
  )
}

class ::gui_handlers.clanLogModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanLogModal.blk"

  loadButtonId = "button_load_more"

  logListObj = null

  clanId        = null
  requestMarker = null
  currentFocusItem = 5
  selectedIndex = 0

  function initScreen()
  {
    logListObj = scene.findObject("log_list")
    if (!::checkObj(logListObj))
      return goBack()

    initFocusArray()
    restoreFocus()
    fetchLogPage()
  }

  function fetchLogPage()
  {
    ::g_clans.requestClanLog(
      clanId,
      ::CLAN_LOG_ROWS_IN_PAGE,
      requestMarker,
      handleLogData,
      function (result) {},
      this
    )
  }

  function handleLogData(logData)
  {
    requestMarker = logData.requestMarker

    guiScene.setUpdatesEnabled(false, false)
    removeNextButton()
    showLogs(logData)
    if (logData.logEntries.len() >= ::CLAN_LOG_ROWS_IN_PAGE)
      addNextButton()
    guiScene.setUpdatesEnabled(true, true)

    selectLogItem()
  }

  function showLogs(logData)
  {
    local blk = ::handyman.renderCached("gui/logEntryList", logData, {
      details = ::load_template_text("gui/clans/clanLogDetails")
    })
    guiScene.appendWithBlk(logListObj, blk, this)
  }

  function selectLogItem()
  {
    if (logListObj.childrenCount() <= 0)
      return

    if (selectedIndex >= logListObj.childrenCount())
      selectedIndex = logListObj.childrenCount() - 1

    logListObj.setValue(selectedIndex)
    logListObj.select()
    logListObj.getChild(selectedIndex).scrollToView()
  }

  function onUserLinkRClick(obj, itype, link) {
    local uid = ::g_string.cutPrefix(link, "uid_", null)

    if (uid == null)
      return

    playerContextMenu.showMenu(::getContact(uid), this)
  }

  function removeNextButton()
  {
    local obj = logListObj.findObject(loadButtonId)
    if (::checkObj(obj))
      guiScene.destroyElement(obj)
  }

  function addNextButton()
  {
    local obj = logListObj.findObject(loadButtonId)
    if (!obj)
    {
      local data = format("expandable { id:t='%s'}", loadButtonId)
      guiScene.appendWithBlk(logListObj, data, this)
      obj = logListObj.findObject(loadButtonId)
    }

    local viewBlk = ::handyman.renderCached("gui/userLog/userLogRow",
      {
        middle = ::loc("userlog/showMore")
        hasExpandImg = true
      })
    guiScene.replaceContentFromText(obj, viewBlk, viewBlk.len(), this)
  }

  function onItemSelect(obj)
  {
    local listChildrenCount = logListObj.childrenCount()
    if (listChildrenCount <= 0)
      return

    local index = obj.getValue()
    if (index == -1 || index > listChildrenCount - 1)
      return

    selectedIndex = index
    local selectedObj = obj.getChild(index)
    if (::check_obj(selectedObj) && selectedObj?.id == loadButtonId)
      fetchLogPage()
  }

  function getMainFocusObj()
  {
    return logListObj
  }
}
