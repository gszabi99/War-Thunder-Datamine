from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file(v))

::CLAN_LOG_ROWS_IN_PAGE <- 10
::show_clan_log <- function show_clan_log(clanId)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.clanLogModal,
    {clanId = clanId}
  )
}

::gui_handlers.clanLogModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanLogModal.blk"

  loadButtonId = "button_load_more"

  logListObj = null

  clanId        = null
  requestMarker = null
  selectedIndex = 0

  function initScreen()
  {
    this.logListObj = this.scene.findObject("log_list")
    if (!checkObj(this.logListObj))
      return this.goBack()

    this.fetchLogPage()
  }

  function fetchLogPage()
  {
    ::g_clans.requestClanLog(
      this.clanId,
      ::CLAN_LOG_ROWS_IN_PAGE,
      this.requestMarker,
      this.handleLogData,
      function (_result) {},
      this
    )
  }

  function handleLogData(logData)
  {
    this.requestMarker = logData.requestMarker

    this.guiScene.setUpdatesEnabled(false, false)
    this.removeNextButton()
    this.showLogs(logData)
    if (logData.logEntries.len() >= ::CLAN_LOG_ROWS_IN_PAGE)
      this.addNextButton()
    this.guiScene.setUpdatesEnabled(true, true)

    this.selectLogItem()
  }

  function showLogs(logData)
  {
    for (local i = 0; i < logData.logEntries.len(); i++) {
      let author = logData.logEntries[i]?.uN ?? logData.logEntries[i]?.details.uN ?? ""
      logData.logEntries[i] = ::getFilteredClanData(logData.logEntries[i], author)
      if ("details" in logData.logEntries[i])
        logData.logEntries[i].details = ::getFilteredClanData(logData.logEntries[i].details, author)
    }

    let blk = ::handyman.renderCached("%gui/logEntryList.tpl", logData, {
      details = loadTemplateText("%gui/clans/clanLogDetails.tpl")
    })
    this.guiScene.appendWithBlk(this.logListObj, blk, this)
  }

  function selectLogItem()
  {
    if (this.logListObj.childrenCount() <= 0)
      return

    if (this.selectedIndex >= this.logListObj.childrenCount())
      this.selectedIndex = this.logListObj.childrenCount() - 1

    this.logListObj.setValue(this.selectedIndex)
    ::move_mouse_on_child(this.logListObj, this.selectedIndex)
  }

  function onUserLinkRClick(_obj, _itype, link) {
    let uid = ::g_string.cutPrefix(link, "uid_", null)

    if (uid == null)
      return

    playerContextMenu.showMenu(::getContact(uid), this)
  }

  function removeNextButton()
  {
    let obj = this.logListObj.findObject(this.loadButtonId)
    if (checkObj(obj))
      this.guiScene.destroyElement(obj)
  }

  function addNextButton()
  {
    local obj = this.logListObj.findObject(this.loadButtonId)
    if (!obj)
    {
      let data = format("expandable { id:t='%s'}", this.loadButtonId)
      this.guiScene.appendWithBlk(this.logListObj, data, this)
      obj = this.logListObj.findObject(this.loadButtonId)
    }

    let viewBlk = ::handyman.renderCached("%gui/userLog/userLogRow.tpl",
      {
        middle = loc("userlog/showMore")
        hasExpandImg = true
      })
    this.guiScene.replaceContentFromText(obj, viewBlk, viewBlk.len(), this)
  }

  function onItemSelect(obj)
  {
    let listChildrenCount = this.logListObj.childrenCount()
    if (listChildrenCount <= 0)
      return

    let index = obj.getValue()
    if (index == -1 || index > listChildrenCount - 1)
      return

    this.selectedIndex = index
    let selectedObj = obj.getChild(index)
    if (checkObj(selectedObj) && selectedObj?.id == this.loadButtonId)
      this.fetchLogPage()
  }
}
