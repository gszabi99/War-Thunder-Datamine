local clanBlackList = [
  { id = "nick", type = ::g_lb_data_type.NICK },
  { id = "initiator_nick", type = ::g_lb_data_type.NICK },
  { id = "date", type = ::g_lb_data_type.DATE }]

::gui_start_clan_blacklist <- function gui_start_clan_blacklist(clanData = null)
{
  clanData = clanData || ::my_clan_info
  if (!clanData)
    return

  ::gui_start_modal_wnd(::gui_handlers.clanBlacklistModal, {clanData = clanData})
}

::gui_handlers.clanBlacklistModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/clans/clanRequests.blk"
  wndType = handlerType.MODAL

  myRights = []
  curCandidate = null
  blacklistRow = ["nick", "initiator_nick", { id="date", type = ::g_lb_data_type.DATE }]

  clanData = null
  blacklistData = null

  curPage = 0
  rowsPerPage = 10

  function initScreen()
  {
    myRights = ::clan_get_role_rights(::clan_get_admin_editor_mode() ? ::ECMR_CLANADMIN : ::clan_get_my_role())

    blacklistData = clanData.blacklist
    updateBlacklistTable()
    let tObj = scene.findObject("clan_title_table")
    if(tObj)
      tObj.setValue(::loc("clan/blacklist"))
  }

  function updateBlacklistTable()
  {
    if (!::check_obj(scene) || !blacklistData)
      return

    if (curPage > 0 && blacklistData.len() <= curPage * rowsPerPage)
      curPage--

    let tblObj = scene.findObject("candidatesList")
    local data = ""

    let headerRow = []
    foreach(item in blacklistRow)
    {
      let itemName = (typeof(item) != "table")? item : item.id
      let name = "#clan/"+(itemName == "date"? "bannedDate" : itemName)
      headerRow.append({
        id = itemName,
        text = name,
        tdalign="center",
      })
    }
    data = ::buildTableRow("row_header", headerRow, null,
      "enable:t='no'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    let startIdx = curPage * rowsPerPage
    let lastIdx = min((curPage + 1) * rowsPerPage, blacklistData.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      let rowName = "row_" + i
      let rowData = []

      foreach(item in blacklistRow)
      {
         let itemName = (typeof(item) != "table")? item : item.id
         rowData.append({
          id = itemName,
          text = "",
         })
      }
      data += ::buildTableRow(rowName, rowData, (i-curPage*rowsPerPage)%2==0, "")
    }
    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    for(local i=startIdx; i < lastIdx; i++)
      fillRow(tblObj, i)

    tblObj.setValue(1) //after header
    guiScene.setUpdatesEnabled(true, true)
    ::move_mouse_on_child_by_value(tblObj)
    onSelect()

    ::generatePaginator(scene.findObject("paginator_place"), this, curPage, ((blacklistData.len()-1) / rowsPerPage).tointeger())
  }

  function fillRow(tblObj, i)
  {
    let block = blacklistData[i]
    let rowObj = tblObj.findObject("row_"+i)
    if (rowObj)
    {
      let comments = ("comments" in block) ? block.comments : ""
      rowObj.tooltip = comments.len()
        ? ::loc("clan/blacklistRowTooltip", {comments = comments}) : ""

      foreach(item in clanBlackList)
      {
        let vObj = rowObj.findObject("txt_" + item.id)
        let itemValue = (item.id in block)? block[item.id] : 0
        if(vObj)
          vObj.setValue(item.type.getShortTextByValue(itemValue))
      }
    }
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    updateBlacklistTable()
  }

  function onSelect()
  {
    curCandidate = null
    if (blacklistData && blacklistData.len()>0)
    {
      let objTbl = scene.findObject("candidatesList");
      let index = objTbl.getValue() + curPage*rowsPerPage - 1 //header
      if (index in blacklistData)
        curCandidate = blacklistData[index]
    }

    this.showSceneBtn("btn_removeBlacklist", curCandidate != null && ::isInArray("MEMBER_BLACKLIST", myRights))
    this.showSceneBtn("btn_user_options", curCandidate != null && ::show_console_buttons)
  }

  function onUserCard()
  {
    if (curCandidate)
      ::gui_modal_userCard({ uid = curCandidate.uid })
  }

  function onRequestApprove(){}
  function onRequestReject(){}

  function onDeleteFromBlacklist()
  {
    if (curCandidate)
      ::g_clans.blacklistAction(curCandidate.uid, false, clanData == ::my_clan_info? "-1" : clanData.id)
  }

  function onUserRClick()
  {
    openUserPopupMenu()
  }

  function onUserAction()
  {
    let table = scene.findObject("candidatesList")
    if (!::checkObj(table))
      return

    let index = table.getValue()
    if (index < 0 || index >= table.childrenCount())
      return

    let position = table.getChild(index).getPosRC()
    openUserPopupMenu(position)
  }

  function openUserPopupMenu(position = null)
  {
    if (!curCandidate)
      return

    let menu = [
      {
        text = ::loc("msgbox/btn_delete")
        show = ::isInArray("MEMBER_BLACKLIST", myRights)
        action = onDeleteFromBlacklist
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = @() ::gui_modal_userCard({ uid = curCandidate.uid })
      }
    ]
    ::gui_right_click_menu(menu, this, position)
  }

  function hideCandidateByName(name)
  {
    if (!name)
      return

    foreach(idx, candidate in blacklistData)
      if (candidate.nick == name)
      {
        blacklistData.remove(idx)
        break
      }

    if (blacklistData.len() > 0)
      updateBlacklistTable()
    else
      goBack()
  }

  function onEventClanCandidatesListChanged(p)
  {
    let uid = p?.userId
    let candidate = ::u.search(blacklistData, @(candidate) candidate.uid == uid )
    hideCandidateByName(candidate?.nick)
  }
}
