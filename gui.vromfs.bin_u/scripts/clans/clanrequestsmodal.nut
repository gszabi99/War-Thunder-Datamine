from "%scripts/dagui_natives.nut" import clan_get_admin_editor_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import buildTableRow

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { move_mouse_on_child_by_value } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")

let clanContextMenu = require("%scripts/clans/clanContextMenu.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { gui_modal_userCard } = require("%scripts/user/userCard/userCardView.nut")
let { approvePlayerRequest, rejectPlayerRequest } = require("%scripts/clans/clanActions.nut")
let { getMyClanRights } = require("%scripts/clans/clanInfo.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")

let clan_candidate_list = [
  { id = "nick", type = lbDataType.NICK }
  { id = "date", type = lbDataType.DATE }
];

gui_handlers.clanRequestsModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanRequests.blk";
  owner = null;
  rowTexts = [];
  candidatesData = null;
  candidatesList = [];
  myRights = [];
  curCandidate = null;
  memListModified = false
  curPage = 0
  rowsPerPage = 10
  clanId = "-1"

  function initScreen() {
    this.myRights = getMyClanRights()
    this.memListModified = false
    let myClanInfoV = myClanInfo.get()
    let isMyClan = myClanInfoV != null && myClanInfoV.id == this.clanId
    this.clanId = isMyClan ? "-1" : this.clanId
    this.fillRequestList()
  }

  function fillRequestList() {
    this.rowTexts = [];
    this.candidatesList = [];

    foreach (candidate in this.candidatesData) {
      let rowTemp = {};
      foreach (item in clan_candidate_list) {
        let value = item.id in candidate ? candidate[item.id] : 0
        rowTemp[item.id] <- { value = value, text = item.type.getShortTextByValue(value) }
      }
      this.candidatesList.append({ nick = candidate.nick, uid = candidate.uid });
      this.rowTexts.append(rowTemp);
    }
    
    

    this.updateRequestList()
  }

  function updateRequestList() {
    if (!checkObj(this.scene))
      return;

    if (this.curPage > 0 && this.rowTexts.len() <= this.curPage * this.rowsPerPage)
      this.curPage--

    let tblObj = this.scene.findObject("candidatesList");
    local data = "";

    let headerRow = [];
    foreach (item in clan_candidate_list) {
      let name = $"#clan/{item.id == "date" ? "requestDate" : item.id}"
      headerRow.append({
        id = item.id,
        text = name,
        tdalign = "center",
      });
    }
    data = buildTableRow("row_header", headerRow, null,
      "enable:t='no'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ");

    let startIdx = this.curPage * this.rowsPerPage
    let lastIdx = min((this.curPage + 1) * this.rowsPerPage, this.rowTexts.len())
    for (local i = startIdx; i < lastIdx; i++) {
      let rowName = $"row_{i}";
      let rowData = [];

      foreach (item in clan_candidate_list) {
        rowData.append({
          id = item.id,
          text = "",
        });
      }
      data = "".concat(data, buildTableRow(rowName, rowData, (i - startIdx) % 2 == 0, ""))
    }

    this.guiScene.setUpdatesEnabled(false, false);
    this.guiScene.replaceContentFromText(tblObj, data, data.len(), this);

    for (local i = startIdx; i < lastIdx; i++) {
      let row = this.rowTexts[i]
      foreach (item, itemValue in row)
        tblObj.findObject($"row_{i}").findObject($"txt_{item}").setValue(itemValue.text);
    }

    tblObj.setValue(1) 
    this.guiScene.setUpdatesEnabled(true, true);
    move_mouse_on_child_by_value(tblObj)
    this.onSelect()

    generatePaginator(this.scene.findObject("paginator_place"), this, this.curPage, ((this.rowTexts.len() - 1) / this.rowsPerPage).tointeger())
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.updateRequestList()
  }

  function onSelect() {
    this.curCandidate = null;
    if (this.candidatesList && this.candidatesList.len() > 0) {
      let objTbl = this.scene.findObject("candidatesList");
      let index = objTbl.getValue() + this.curPage * this.rowsPerPage - 1; 
      if (index in this.candidatesList)
        this.curCandidate = this.candidatesList[index];
    }
    showObjById("btn_approve", !showConsoleButtons.value && this.curCandidate != null && (isInArray("MEMBER_ADDING", this.myRights) || clan_get_admin_editor_mode()), this.scene)
    showObjById("btn_reject", !showConsoleButtons.value && this.curCandidate != null && isInArray("MEMBER_REJECT", this.myRights), this.scene)
    showObjById("btn_user_options", this.curCandidate != null && showConsoleButtons.value, this.scene)
  }

  function onUserCard() {
    if (this.curCandidate)
      gui_modal_userCard({ uid = this.curCandidate.uid })
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

    clanContextMenu.retrieveRequestActions(this.clanId, this.curCandidate.uid, this.curCandidate?.nick, this, function(menu) {
      openRightClickMenu(menu, this, position)
    })
  }

  function onRequestApprove() {
    approvePlayerRequest(this.curCandidate.uid, this.clanId)
  }

  function onRequestReject() {
    rejectPlayerRequest(this.curCandidate.uid, this.clanId)
  }

  function hideCandidateByName(name) {
    if (!name)
      return

    this.memListModified = true
    foreach (idx, candidate in this.rowTexts)
      if (candidate.nick.value == name) {
        this.rowTexts.remove(idx)
        foreach (cIdx, player in this.candidatesList)
          if (player.nick == name) {
            this.candidatesList.remove(cIdx)
            break
          }
        break
      }

    if (this.rowTexts.len() > 0)
      this.updateRequestList()
    else
      this.goBack()
  }

  function afterModalDestroy() {
    if (this.memListModified) {
      if (clan_get_admin_editor_mode() && (this.owner && "reinitClanWindow" in this.owner))
        this.owner.reinitClanWindow()
      
      
    }
  }

  function onDeleteFromBlacklist() {}

  function onEventClanCandidatesListChanged(p) {
    let uid = p?.userId
    let candidate = u.search(this.candidatesList, @(candidate) candidate.uid == uid)
    this.hideCandidateByName(candidate?.nick)
  }
}