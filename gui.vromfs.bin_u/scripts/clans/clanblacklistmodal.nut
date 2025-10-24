from "%scripts/dagui_natives.nut" import clan_get_admin_editor_mode, clan_get_my_role, clan_get_role_rights
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRow

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let { gui_modal_userCard } = require("%scripts/user/userCard/userCardView.nut")
let { blacklistAction } = require("%scripts/clans/clanActions.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")

local clanBlackList = [
  { id = "nick", type = lbDataType.NICK },
  { id = "initiator_nick", type = lbDataType.NICK },
  { id = "date", type = lbDataType.DATE }]

gui_handlers.clanBlacklistModal <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/clans/clanRequests.blk"
  wndType = handlerType.MODAL

  myRights = []
  curCandidate = null
  blacklistRow = ["nick", "initiator_nick", { id = "date", type = lbDataType.DATE }]

  clanData = null
  blacklistData = null

  curPage = 0
  rowsPerPage = 10

  function initScreen() {
    this.myRights = clan_get_role_rights(clan_get_admin_editor_mode() ? ECMR_CLANADMIN : clan_get_my_role())

    this.blacklistData = this.clanData.blacklist
    this.updateBlacklistTable()
    let tObj = this.scene.findObject("clan_title_table")
    if (tObj)
      tObj.setValue(loc("clan/blacklist"))
  }

  function updateBlacklistTable() {
    if (!checkObj(this.scene) || !this.blacklistData)
      return

    if (this.curPage > 0 && this.blacklistData.len() <= this.curPage * this.rowsPerPage)
      this.curPage--

    let tblObj = this.scene.findObject("candidatesList")
    local data = ""

    let headerRow = []
    foreach (item in this.blacklistRow) {
      let itemName = (type(item) != "table") ? item : item.id
      let name = "".concat("#clan/", (itemName == "date" ? "bannedDate" : itemName))
      headerRow.append({
        id = itemName,
        text = name,
        tdalign = "center",
      })
    }
    data = buildTableRow("row_header", headerRow, null,
      "enable:t='no'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    let startIdx = this.curPage * this.rowsPerPage
    let lastIdx = min((this.curPage + 1) * this.rowsPerPage, this.blacklistData.len())
    for (local i = startIdx; i < lastIdx; i++) {
      let rowName = $"row_{i}"
      let rowData = []

      foreach (item in this.blacklistRow) {
         let itemName = (type(item) != "table") ? item : item.id
         rowData.append({
          id = itemName,
          text = "",
         })
      }
      data = "".concat(data, buildTableRow(rowName, rowData, (i - this.curPage * this.rowsPerPage) % 2 == 0, ""))
    }
    this.guiScene.setUpdatesEnabled(false, false)
    this.guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    for (local i = startIdx; i < lastIdx; i++)
      this.fillRow(tblObj, i)

    tblObj.setValue(1) 
    this.guiScene.setUpdatesEnabled(true, true)
    move_mouse_on_child_by_value(tblObj)
    this.onSelect()

    generatePaginator(this.scene.findObject("paginator_place"), this, this.curPage, ((this.blacklistData.len() - 1) / this.rowsPerPage).tointeger())
  }

  function fillRow(tblObj, i) {
    let block = this.blacklistData[i]
    let rowObj = tblObj.findObject($"row_{i}")
    if (rowObj) {
      let comments = ("comments" in block) ? block.comments : ""
      rowObj.tooltip = comments.len()
        ? loc("clan/blacklistRowTooltip", { comments = comments }) : ""

      foreach (item in clanBlackList) {
        let vObj = rowObj.findObject($"txt_{item.id}")
        let itemValue = (item.id in block) ? block[item.id] : 0
        if (vObj)
          vObj.setValue(item.type.getShortTextByValue(itemValue))
      }
    }
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.updateBlacklistTable()
  }

  function onSelect() {
    this.curCandidate = null
    if (this.blacklistData && this.blacklistData.len() > 0) {
      let objTbl = this.scene.findObject("candidatesList");
      let index = objTbl.getValue() + this.curPage * this.rowsPerPage - 1 
      if (index in this.blacklistData)
        this.curCandidate = this.blacklistData[index]
    }

    showObjById("btn_removeBlacklist", this.curCandidate != null && isInArray("MEMBER_BLACKLIST", this.myRights), this.scene)
    showObjById("btn_user_options", this.curCandidate != null && showConsoleButtons.get(), this.scene)
  }

  function onUserCard() {
    if (this.curCandidate)
      gui_modal_userCard({ uid = this.curCandidate.uid })
  }

  function onRequestApprove() {}
  function onRequestReject() {}

  function onDeleteFromBlacklist() {
    if (this.curCandidate)
      blacklistAction(this.curCandidate.uid, false, this.clanData == myClanInfo.get() ? "-1" : this.clanData.id)
  }

  function onUserRClick() {
    this.openUserPopupMenu()
  }

  function onUserAction() {
    let table = this.scene.findObject("candidatesList")
    if (!checkObj(table))
      return

    let index = table.getValue()
    if (index < 0 || index >= table.childrenCount())
      return

    let position = table.getChild(index).getPosRC()
    this.openUserPopupMenu(position)
  }

  function openUserPopupMenu(position = null) {
    if (!this.curCandidate)
      return

    let menu = [
      {
        text = loc("msgbox/btn_delete")
        show = isInArray("MEMBER_BLACKLIST", this.myRights)
        action = this.onDeleteFromBlacklist
      }
      {
        text = loc("mainmenu/btnProfile")
        action = @() gui_modal_userCard({ uid = this.curCandidate.uid })
      }
    ]
    openRightClickMenu(menu, this, position)
  }

  function hideCandidateByName(name) {
    if (!name)
      return

    foreach (idx, candidate in this.blacklistData)
      if (candidate.nick == name) {
        this.blacklistData.remove(idx)
        break
      }

    if (this.blacklistData.len() > 0)
      this.updateBlacklistTable()
    else
      this.goBack()
  }

  function onEventClanCandidatesListChanged(p) {
    let uid = p?.userId
    let candidate = u.search(this.blacklistData, @(candidate) candidate.uid == uid)
    this.hideCandidateByName(candidate?.nick)
  }
}

function openClanBlacklistWnd(clanData = null) {
  clanData = clanData ?? myClanInfo.get()
  if (!clanData)
    return

  loadHandler(gui_handlers.clanBlacklistModal, { clanData = clanData })
}

return {
  openClanBlacklistWnd
}
