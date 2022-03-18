let time = require("scripts/time.nut")
let { getPlayerName,
        isPlayerFromPS4,
        isPlayerFromXboxOne,
        isPlatformSony,
        isPlatformXboxOne } = require("scripts/clientState/platform.nut")
let playerContextMenu = require("scripts/user/playerContextMenu.nut")
let vehiclesModal = require("scripts/unit/vehiclesModal.nut")
let wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")
let clanMembershipAcceptance = require("scripts/clans/clanMembershipAcceptance.nut")
let clanRewardsModal = require("scripts/rewards/clanRewardsModal.nut")
let clanInfoView = require("scripts/clans/clanInfoView.nut")
let { getSeparateLeaderboardPlatformValue } = require("scripts/social/crossplay.nut")

let clan_member_list = [
  {id = "onlineStatus", lbDataType = ::g_lb_data_type.TEXT, myClanOnly = true, iconStyle = true, needHeader = false}
  {id = "nick", lbDataType = ::g_lb_data_type.NICK, align = "left"}
  {id = ::ranked_column_prefix, lbDataType = ::g_lb_data_type.NUM, loc = "rating", byDifficulty = true
    tooltip = "#clan/personal/dr_era/desc"}
  {
    id = "activity"
    lbDataType = ::g_lb_data_type.NUM
    field = @() ::has_feature("ClanVehicles") ? "totalPeriodActivity" : "totalActivity"
    showByFeature = "ClanActivity"
    getCellTooltipText = function(data) { return loc("clan/personal/" + id + "/cell/desc") }
    getTooltipText  = @(depth) ::loc("clan/personal/activity/desc",
      {historyDepth = depth})
  }
  {
    id = "role",
    lbDataType = ::g_lb_data_type.ROLE,
    sortId = "roleRank"
    sortPrepare = function(member) { member[sortId] <- ::clan_get_role_rank(member.role) }
    getCellTooltipText = function(data) { return lbDataType.getPrimaryTooltipText(::getTblValue(id, data)) }
  }
  {id = "date", lbDataType = ::g_lb_data_type.DATE }
]

let clan_data_list = [
  {id = "air_kills", lbDataType = ::g_lb_data_type.NUM, field = "akills"}
  {id = "ground_kills", lbDataType = ::g_lb_data_type.NUM, field = "gkills"}
  {id = "deaths", lbDataType = ::g_lb_data_type.NUM, field = "deaths"}
  {id = "time_pvp_played", lbDataType = ::g_lb_data_type.TIME_MIN, field = "ftime"}
]

let default_clan_member_list = {
  onlyMyClan = false
  iconStyle = false
  byDifficulty = false
}
foreach(idx, item in clan_member_list)
{
  foreach(param, value in default_clan_member_list)
    if (!(param in item))
      clan_member_list[idx][param] <- value

  if (!("tooltip" in item))
    item.tooltip <-"#clan/personal/" + item.id + "/desc"
}

::showClanPage <- function showClanPage(id, name, tag)
{
  ::gui_start_modal_wnd(::gui_handlers.clanPageModal,
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}

::gui_handlers.clanPageModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanPageModal.blk"

  clanIdStrReq = ""
  clanNameReq  = ""
  clanTagReq   = ""

  isClanInfo = true
  isMyClan = false
  myRights = []

  statsSortReverse = false
  statsSortBy      = ""
  clanData         = null
  curMode          = 0

  lbTableWeak = null
  isWorldWarMode = false
  curWwCategory = null
  curWwMembers = null

  playerByRow      = null
  playerByRowLb    = null
  curPlayer        = null
  lastHoveredDataIdx = -1

  function initScreen()
  {
    playerByRow   = []
    playerByRowLb = []

    if (clanIdStrReq == "" && clanNameReq == "" && clanTagReq == "")
    {
      goBack()
      return
    }
    curWwCategory = ::g_lb_category.EVENTS_PERSONAL_ELO
    initLbTable()
    curMode = getCurDMode()
    reinitClanWindow()
  }

  function setDefaultSort()
  {
    statsSortBy = ::ranked_column_prefix + ::g_difficulty.getDifficultyByDiffCode(curMode).clanDataEnding
  }

  function reinitClanWindow()
  {
    if (::is_in_clan() &&
      (::clan_get_my_clan_id() == clanIdStrReq ||
       ::clan_get_my_clan_name() == clanNameReq ||
       ::clan_get_my_clan_tag() == clanTagReq))
    {
      ::requestMyClanData()
      if (!::my_clan_info)
        return

      clanData = ::my_clan_info

      setDefaultSort()
      fillClanPage()
      return
    }
    if (clanIdStrReq == "" && clanNameReq == "" && clanTagReq == "")
      return

    taskId = ::clan_request_info(clanIdStrReq, clanNameReq, clanTagReq)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = function()
      {
        clanData = ::get_clan_info_table()
        if (!clanData)
          return goBack()

        setDefaultSort()
        fillClanPage()
        ::broadcastEvent("ClanInfoAvailable", {clanId = clanData.id})
      }
      afterSlotOpError = function(result)
      {
        goBack()
        return
      }
    }
    else
    {
      goBack()
      msgBox("unknown_identification", ::loc("charServer/updateError/13"),
        [["ok", function() {} ]], "ok")
      dagor.debug(::format("Failed to find clan by id: %s", clanIdStrReq))
      return
    }
  }

  function initLbTable()
  {
    lbTableWeak = ::gui_handlers.LeaderboardTable.create({
      scene = scene.findObject("lb_table_nest")
      onCategoryCb = ::Callback(onCategory, this)
      onRowSelectCb = ::Callback(onSelectedPlayerIdxLb, this)
      onRowHoverCb = ::show_console_buttons ? ::Callback(onSelectedPlayerIdxLb, this) : null
      onRowDblClickCb = ::Callback(onUserCard, this)
      onRowRClickCb = ::Callback(onUserRClick, this)
    })
  }

  function onEventClanInfoUpdate(params = {})
  {
    if (clanIdStrReq == ::clan_get_my_clan_id()
        || (clanData && clanData.id == ::clan_get_my_clan_id()))
    {
      if (!::my_clan_info)
        return goBack()
      clanData = ::my_clan_info
      fillClanPage()
    }
  }

  function onEventProfileUpdated(p)
  {
    fillClanManagment()
  }

  function onEventContactsGroupUpdate(p) {
    doWhenActiveOnce("reinitClanWindow")
  }

  function fillClanInfoRow(id, text, feature = "")
  {
    let obj = scene.findObject(id)
    if (!::check_obj(obj))
      return

    if (!::u.isEmpty(feature) && !::has_feature(feature))
      text = ""
    text = ::g_chat.filterMessageText(text, false)

    obj.setValue(text)
  }

  function fillClanPage()
  {
    if (!::checkObj(scene))
      return

    clanData = ::getFilteredClanData(clanData)

    isMyClan = ::clan_get_my_clan_id() == clanData.id;
    scene.findObject("clan_loading").show(false)

    showSceneBtn("clan-icon", true)

    fillClanInfoRow("clan-region",
      clanData.region != "" ? ::loc("clan/clan_region") + ::loc("ui/colon") + clanData.region : "",
      "ClanRegions")
    fillClanInfoRow("clan-about",
      clanData.desc != "" || clanData.announcement != ""
        ? ::g_string.implode(
            [clanData.desc, ::has_feature("ClanAnnouncements") ? clanData.announcement : ""],
            "\n")
        : "")
    fillClanInfoRow("clan-motto",
      clanData.slogan != "" ? ::loc("clan/clan_slogan") + ::loc("ui/colon") + clanData.slogan : "")

    fillCreatorData()

    scene.findObject("nest_lock_clan_req").clan_locked = !clanMembershipAcceptance.getValue(clanData) ? "yes" : "no"

        // Showing clan name in special header object if possible.
    let clanName = clanData.tag + " " + clanData.name
    let headerTextObj = scene.findObject("clan_page_header_text")
    let clanTitleObj = scene.findObject("clan-title")
    if (::checkObj(headerTextObj))
    {
      let locId = "clan/clanInfo/" + clanData.clanType.getTypeName()
      let text = ::colorize(clanData.clanType.color, ::loc(locId, { clanName = clanName }))
      headerTextObj.setValue(text)
      clanTitleObj.setValue("")
    }
    else
      clanTitleObj.setValue(::colorize(clanData.clanType.color, clanName))

    let clanDate = clanData.getCreationDateText()
    let dateText = ::loc("clan/creationDate") + " " + ::colorize("activeTextColor", clanDate)

    let membersCountText = ::g_clans.getClanMembersCountText(clanData)
    let countText = ::loc("clan/memberListTitle")
      + ::loc("ui/parentheses/space", { text = ::colorize("activeTextColor", membersCountText) })
    scene.findObject("clan-memberCount-date").setValue(::g_string.implode([countText, dateText], " "))

    fillClanRequirements()

    local updStatsText = time.buildTimeStr(time.getUtcMidnight(), false, false)

    updStatsText = ::loc("ui/parentheses/space",
      { text = format(::loc("clan/updateStatsTime"), updStatsText) })
    scene.findObject("update_stats_info_text").setValue(
      "<b>{0}</b> {1}".subst(::colorize("commonTextColor", ::loc("clan/stats")), updStatsText))

    fillModeListBox(scene.findObject("clan_container"), getCurDMode(),
      ::get_show_in_squadron_statistics, getAdditionalTabsArray())
    fillClanManagment()

    showSceneBtn("clan_main_stats", true)
    fillClanStats(clanData.astat)
  }

  function fillCreatorData()
  {
    let obj = scene.findObject("clan-prevChanges")
    if (!::check_obj(obj))
      return

    let isVisible = ::has_feature("ClanChangedInfoData")
                      && clanData.changedByUid != ""
                      && clanData.changedByNick != ""
                      && clanData.changedTime

    local text = ""
    if (isVisible)
    {
      text += ::loc("clan/lastChanges") + ::loc("ui/colon")
      let color = ::my_user_id_str == clanData.changedByUid? "mainPlayerColor" : "activeTextColor"
      text += ::g_string.implode(
        [
          ::colorize(color, getPlayerName(clanData.changedByNick))
          clanData.getInfoChangeDateText()
        ]
        ::loc("ui/comma")
      )
    }
    obj.setValue(text)
  }

  function fillClanRequirements()
  {
    if (!clanData)
      return

    scene.findObject("clan-membershipReq").setValue(
      clanInfoView.getClanRequirementsText(clanData.membershipRequirements))
  }


  function fillClanManagment()
  {
    if (!clanData)
      return

    let adminMode = ::clan_get_admin_editor_mode()
    let myClanId = ::clan_get_my_clan_id();
    local showMembershipsButton = false
    isMyClan = myClanId == clanData.id;

    if (!isMyClan && myClanId == "-1" && ::clan_get_requested_clan_id() != clanData.id &&
      clanMembershipAcceptance.getValue(clanData))
        showMembershipsButton = true

    if(isMyClan || adminMode)
      myRights = ::clan_get_role_rights(adminMode ? ::ECMR_CLANADMIN : ::clan_get_my_role())
    else
      myRights = []

    let showBtnLock = clanMembershipAcceptance.canChange(clanData)
    let hasLeaderRight = isInArray("LEADER", myRights)
    let showMembershipsReqEditorButton = ( ::has_feature("ClansMembershipEditor") ) && (
                                            ( isMyClan && isInArray("CHANGE_INFO", myRights) ) || ::clan_get_admin_editor_mode() )
    let showClanSeasonRewards = ::has_feature("ClanSeasonRewardsLog") && (clanData.rewardLog.len() > 0)

    let buttonsList = {
      btn_showRequests = ((isMyClan && (isInArray("MEMBER_ADDING", myRights) || isInArray("MEMBER_REJECT", myRights))) || adminMode) && clanData.candidates.len() > 0
      btn_leaveClan = isMyClan && (!hasLeaderRight || ::g_clans.getLeadersCount(clanData) > 1)
      btn_edit_clan_info = ::ps4_is_ugc_enabled() && ((isMyClan && isInArray("CHANGE_INFO", myRights)) || adminMode)
      btn_upgrade_clan = clanData.clanType.getNextType() != ::g_clan_type.UNKNOWN && (adminMode || (isMyClan && hasLeaderRight))
      btn_showBlacklist = ((isMyClan && isInArray("MEMBER_BLACKLIST", myRights)) || adminMode) && clanData.blacklist.len()
      btn_lock_clan_req = showBtnLock
      img_lock_clan_req = !showBtnLock && !clanMembershipAcceptance.getValue(clanData)
      btn_complain = !isMyClan
      btn_membership_req = showMembershipsButton
      btn_log = ::has_feature("ClanLog")
      btn_season_reward_log = showClanSeasonRewards
      clan_awards_container = showClanSeasonRewards
      btn_clan_membership_req_edit = showMembershipsReqEditorButton
      btn_clanSquads = ::has_feature("ClanSquads") && isMyClan
      btn_clanActivity = ::has_feature("ClanVehicles") && isMyClan
      btn_clanVehicles = ::has_feature("ClanVehicles") && isMyClan
    }
    ::showBtnTable(scene, buttonsList)

    showSceneBtn("clan_actions", buttonsList.btn_showRequests
      || buttonsList.btn_clanSquads
      || buttonsList.btn_log)

    let showRequestsBtn = scene.findObject("btn_showRequests")
    if (::checkObj(showRequestsBtn))
    {
      let isShow = ::getTblValue("btn_showRequests", buttonsList, false)
      showRequestsBtn.setValue(::loc("clan/btnShowRequests")+" ("+clanData.candidates.len()+")")
      showRequestsBtn.wink = isShow ? "yes" : "no"
    }

    if (showClanSeasonRewards)
    {
      let containerObj = scene.findObject("clan_awards_container")
      if (::checkObj(containerObj))
        guiScene.performDelayed(this, (@(containerObj, clanData) function () {
          if (!isValid())
            return

          let count = ::g_dagui_utils.countSizeInItems(containerObj.getParent(), "@clanMedalSizeMin", 1, 0, 0).itemsCountX
          let medals = ::g_clans.getClanPlaceRewardLogData(clanData, count)
          local markup = ""
          local rest = ::min(medals.len(), ::get_warpoints_blk()?.maxClanBestRewards ?? 6)
          foreach (m in medals)
            if(clanRewardsModal.isRewardVisible(m, clanData))
              if(rest-- > 0)
                markup += "layeredIconContainer { size:t='@clanMedalSizeMin,"
                  + "@clanMedalSizeMin'; overflow:t='hidden' "
                  + ::LayersIcon.getIconData(m.iconStyle, null, null, null, m.iconParams, m.iconConfig)
                  + "}"

          guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
        })(containerObj, clanData))
    }

    updateAdminModeSwitch()
    updateUserOptionButton()
  }

  function getCurClan()
  {
    return clanData?.id
  }

  function updateUserOptionButton()
  {
    ::showBtnTable(scene, {
      btn_usercard      = curPlayer != null && ::has_feature("UserCards")
      btn_user_options  = curPlayer != null && ::show_console_buttons
    })
  }

  function fillClanElo()
  {
    let difficulty = ::g_difficulty.getDifficultyByDiffCode(curMode)
    let lbImageObj = scene.findObject("clan_elo_icon")
    if (::check_obj(lbImageObj))
      lbImageObj["background-image"] = difficulty.clanRatingImage

    let eloTextObj = scene.findObject("clan_elo_value")
    if (::check_obj(eloTextObj))
    {
      let clanElo = clanData.astat?[::ranked_column_prefix + difficulty.clanDataEnding] ?? 0
      eloTextObj.setValue(clanElo.tostring())
    }
  }

  function fillClanActivity()
  {
    let activityTextObj = scene.findObject("clan_activity_value")
    let activityIconObj = scene.findObject("clan_activity_icon")
    if (!::checkObj(activityTextObj) || !::checkObj(activityIconObj))
      return

    let showActivity = ::has_feature("ClanActivity")
    if (showActivity)
    {
      let clanActivity = clanData.astat?.clan_activity_by_periods ?? clanData.astat?.activity ?? 0
      activityTextObj.setValue(clanActivity.tostring())
      activityIconObj["background-image"] = "#ui/gameuiskin#lb_activity.svg"
    }
    activityTextObj.show(showActivity)
    activityIconObj.show(showActivity)
  }

  function setCurDMode(mode)
  {
    ::saveLocalByAccount("wnd/clanDiffMode", mode)
  }

  function getCurDMode()
  {
    let diffMode = ::loadLocalByAccount(
      "wnd/clanDiffMode",
      ::get_current_shop_difficulty().diffCode
    )

    let diff = ::g_difficulty.getDifficultyByDiffCode(diffMode)

    if (::get_show_in_squadron_statistics(diff))
      return diffMode
    return ::g_difficulty.REALISTIC.diffCode
  }

  function cp_onStatsModeChange(obj)
  {
    let tabObj = obj.getChild(obj.getValue())

    isWorldWarMode = tabObj?.isWorldWarMode == "yes"
    showSceneBtn("clan_members_list", !isWorldWarMode)
    showSceneBtn("lb_table_nest", isWorldWarMode)
    showSceneBtn("season_over_notice", isWorldWarMode && !::g_world_war.isWWSeasonActiveShort())

    curPlayer = null

    if (isWorldWarMode)
    {
      fillClanWwMemberList()
      return
    }

    let diffCode = tabObj.holderDiffCode.tointeger()
    let diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
    if(!::get_show_in_squadron_statistics(diff))
      return

    curMode = diffCode
    setCurDMode(curMode)
    updateSortingField()
    fillClanMemberList(clanData.members)
    fillClanElo()
    fillClanActivity()
  }

  function updateSortingField()
  {
    if (statsSortBy.len() >= ::ranked_column_prefix.len() &&
        statsSortBy.slice(0, ::ranked_column_prefix.len()) == ::ranked_column_prefix)
      statsSortBy = ::ranked_column_prefix + ::g_difficulty.getDifficultyByDiffCode(curMode).clanDataEnding
  }

  function updateAdminModeSwitch()
  {
    let show = isClanInfo && ::is_myself_clan_moderator()
    let enable = ::clan_get_admin_editor_mode()
    local obj = scene.findObject("admin_mode_switch")
    if (!::checkObj(obj))
    {
      if (!show)
        return
      let containerObj = scene.findObject("header_buttons")
      if (!::checkObj(containerObj))
        return
      let text = ::loc("clan/admin_mode")
      let markup = ::create_option_switchbox({
        id = "admin_mode_switch"
        value = enable
        textChecked = text
        textUnchecked = text
        cb = "onSwitchAdminMode"
      })
      guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
      obj = containerObj.findObject("admin_mode_switch")
      if (!::checkObj(obj))
        return
    }
    else
      obj.setValue(enable)
    obj.show(show)
  }

  function onSwitchAdminMode()
  {
    enableAdminMode(!::clan_get_admin_editor_mode())
  }

  function enableAdminMode(enable)
  {
    if (enable == ::clan_get_admin_editor_mode())
      return
    if (enable && (!isClanInfo || !::is_myself_clan_moderator()))
      return
    ::clan_set_admin_editor_mode(enable)
    fillClanManagment()
    onSelectUser()
  }

  function onShowRequests()
  {
    if ((!isMyClan || !isInArray("MEMBER_ADDING", myRights)) && !::clan_get_admin_editor_mode())
      return;

    showClanRequests(clanData.candidates, clanData.id, this)
  }

  function onLockNewReqests()
  {
    let value = clanMembershipAcceptance.getValue(clanData)
    clanMembershipAcceptance.setValue(clanData, !value, this)
  }

  function onLeaveClan()
  {
    if (!isMyClan)
      return;

    msgBox("leave_clan", ::loc("clan/leaveConfirmation"),
      [
        ["yes", function()
        {
          leaveClan();
        }],
        ["no",  function() {} ],
      ], "no", { cancel_fn = function(){}} )
  }

  function leaveClan()
  {
    if (!::is_in_clan())
      return afterClanLeave()

    taskId = ::clan_request_leave()

    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      ::sync_handler_simulate_signal("clan_info_reload")
      afterSlotOp = guiScene.performDelayed(this,function()
        {
          ::update_gamercards()
          msgBox("left_clan", ::loc("clan/leftClan"),
            [["ok", function() { if (isValid()) afterClanLeave() } ]], "ok")
        })
    }
  }

  function afterClanLeave()
  {
    goBack()
  }

  function fillClanStats(data)
  {
    let clanTableObj = scene.findObject("clan_stats_table");
    local rowIdx = 0
    local rowBlock = ""
    let rowHeader = [{width = "0.25pw"}]
    /*header*/
    foreach(item in clan_data_list)
    {
      rowHeader.append({
                       image = "#ui/gameuiskin#lb_" + item.id + ".svg"
                       imageRawParams = "input-transparent:t='yes';"
                       tooltip = "#multiplayer/" + item.id
                       tdalign="center"
                       active = false
                    })
    }
    rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowHeader, null,
      "class:t='smallIconsStyle'; background-color:t='@separatorBlockColor'")
    rowIdx++

    /*body*/
    foreach(diff in ::g_difficulty.types)
    {
      if (!diff.isAvailable() || !::get_show_in_squadron_statistics(diff))
        continue

      let rowParams = []
      rowParams.append({
                         text = diff.getLocName(),
                         active = false,
                         tdalign="left"
                      })

      foreach(item in clan_data_list)
      {
        let dataId = item.field + diff.clanDataEnding
        let value = dataId in data? data[dataId] : "0"
        let textCell = item.lbDataType.getShortTextByValue(value)

        rowParams.append({
                          text = textCell,
                          active = false,
                          tdalign="center"
                        })
      }
      rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowParams, null, "")
      rowIdx++
    }
    guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function fillClanWwMemberList()
  {
    if (curWwMembers == null)
      updateCurWwMembers() //fill default wwMembers list
    lbTableWeak.updateParams(
      ::leaderboardModel,
      ::ww_leaderboards_list,
      curWwCategory,
      {lbMode = "ww_users_clan"})

    sortWwMembers()
    playerByRowLb = curWwMembers.map(@(member) member.name)
    curPlayer = null
    let myPos = curWwMembers.findindex(@(member) member.name == ::my_user_name) ?? -1
    lbTableWeak.fillTable(curWwMembers, null, myPos, true, true)

    updateUserOptionButton()
  }

  function sortWwMembers()
  {
    let field = curWwCategory.field
    let addField = ::g_lb_category.EVENTS_PERSONAL_ELO.field
    local idx = 0

    curWwMembers = ::u.map(curWwMembers.sort(@(a, b) (b?[field] ?? 0) <=> (a?[field] ?? 0)
      || (b?[addField] ?? 0) <=> (a?[addField] ?? 0)), @(member) member.__update({ pos = idx++ }))
  }

  function fillClanMemberList(membersData)
  {
    sortMembers(membersData)

    let headerRow = [{text = "#clan/number", width = "0.1@sf"}]
    foreach(column in clan_member_list)
    {
      if (!needShowColumn(column))
        continue

      let rowData = {
        id       = column.id,
        text     = ::getTblValue("needHeader", column, true) ? "#clan/" + ::getTblValue("loc", column, column.id) : "",
        tdalign  = ::getTblValue("align", column, "center"),
        callback = "onStatsCategory",
        active   = isSortByColumn(column.id)
        tooltip  = column?.getTooltipText(clanData?.historyDepth.tostring()) ?? column.tooltip
      }
      // It is important to set width to
      // all rows if column has fixed width.
      // Next two lines fix table layout issue.
      if (::getTblValue("iconStyle", column, false))
        rowData.width <- "0.01@sf"
      headerRow.append(rowData)
    }

    playerByRow = []
    curPlayer = null
    local markup = []
    let isConsoleOnlyPlayers = getSeparateLeaderboardPlatformValue()
    let consoleConst = isPlatformSony
      ? [::TP_PS4, ::TP_PS5]
      : isPlatformXboxOne
        ? [::TP_XBOXONE, ::TP_XBOX_SCARLETT]
        : [::TP_UNKNOWN]

    foreach(member in membersData) {
      if (isConsoleOnlyPlayers) {
        if (member?.platform != null) {
          if (!::isInArray(member.platform, consoleConst))
            continue
        }
        else {
          if ((isPlatformSony && !isPlayerFromPS4(member.nick))
            || (isPlatformXboxOne && !isPlayerFromXboxOne(member.nick)))
            continue
        }
      }

      let rowIdx = playerByRow.len()
      let rowData = [{ text = (rowIdx + 1).tostring() }]
      let isMe = member.nick == ::my_user_name
      foreach(column in clan_member_list)
      {
        if (!needShowColumn(column))
          continue
        rowData.append(getClanMembersCell(member, column))
      }

      markup.append(::buildTableRowNoPad($"row_{rowIdx}", rowData, rowIdx % 2 != 0, isMe ? "mainPlayer:t='yes';" : ""))
      playerByRow.append(member.nick)
    }

    markup.insert(0, ::buildTableRowNoPad("row_header", headerRow, null,"isLeaderBoardHeader:t='yes'"))
    markup = "".join(markup)

    guiScene.setUpdatesEnabled(false, false)
    let tblObj = scene.findObject("clan_members_list")
    guiScene.replaceContentFromText(tblObj, markup, markup.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    onSelectUser()
    updateMembersStatus()
  }

  function needShowColumn(column)
  {
    if ((column?.myClanOnly ?? false) && !isMyClan)
      return false

    if (column?.showByFeature != null && !::has_feature(column?.showByFeature))
      return false

    return true
  }

  function getFieldNameByColumn(columnId)
  {
    local fieldName = columnId
    if (columnId == ::ranked_column_prefix)
      fieldName = ::ranked_column_prefix + ::g_difficulty.getDifficultyByDiffCode(curMode).clanDataEnding
    else
    {
      let category = ::u.search(clan_member_list, (@(columnId) function(category) { return category.id == columnId })(columnId))
      let field = category?.field ?? columnId
      fieldName = ::u.isFunction(field) ? field() : field
    }
    return fieldName
  }

  function isSortByColumn(columnId)
  {
    return getFieldNameByColumn(columnId) == statsSortBy
  }

  function getClanMembersCell(member, column)
  {
    let id = getFieldId(column)
    let res = {
      text = column.lbDataType.getShortTextByValue(member[id])
      tdalign = ::getTblValue("align", column, "center")
    }

    if ("getCellTooltipText" in column)
      res.tooltip <- column.getCellTooltipText(member)

    if (::getTblValue("iconStyle", column, false))
    {
      res.id       <- "icon_" + member.nick
      res.needText <- false
      res.imageType <- "contactStatusImg"
      res.image    <- ""
      if (!("tooltip" in res))
        res.tooltip <- ""
      res.width    <- "0.01@sf"
    }

    return res
  }

  function getFieldId(column)
  {
    if (!("field" in column) && !column.byDifficulty)
      return column.id

    let field = column?.field ?? column.id
    local fieldId = ::u.isFunction(field) ? field() : field
    if (column.byDifficulty)
      fieldId += ::g_difficulty.getDifficultyByDiffCode(curMode).clanDataEnding
    return fieldId
  }

  function sortMembers(members)
  {
    if (typeof members != "array")
      return

    let columnData = getColumnDataById(statsSortBy)
    let sortId = ::getTblValue("sortId", columnData, statsSortBy)
    if ("sortPrepare" in columnData)
      foreach(m in members)
        columnData.sortPrepare(m)

    members.sort((@(sortId, statsSortReverse) function(left, right) {
      local res = 0
      if (sortId != "" && sortId != "nick")
      {
        if (left[sortId] < right[sortId])
          res = 1
        else if (left[sortId] > right[sortId])
          res = -1
      }

      if (!res)
      {
        let nickLeft  = left.nick.tolower()
        let nickRight = right.nick.tolower()
        if (nickLeft < nickRight)
          res = 1
        else if (nickLeft > nickRight)
          res = -1
      }
      return statsSortReverse ? -res : res
    })(sortId, statsSortReverse))
  }

  function onEventClanRoomMembersChanged(params = {})
  {
    if (!isMyClan)
      return

    let presence = ::getTblValue("presence", params, ::g_contact_presence.UNKNOWN)
    let nick = ::getTblValue("nick", params, "")

    if (nick == "")
    {
      updateMembersStatus()
      return
    }

    if (!("members" in my_clan_info))
      return

    let member = ::u.search(
      my_clan_info.members,
      (@(nick) function (member) { return member.nick == nick })(nick)
    )

    if (member)
    {
      member.onlineStatus = presence
      drawIcon(nick, presence)
    }
  }

  function onEventClanRquirementsChanged(params)
  {
    fillClanRequirements()
  }

  function updateMembersStatus()
  {
    if (!isMyClan)
      return
    if (!::gchat_is_connected())
      return
    if ("members" in my_clan_info)
      foreach (it in my_clan_info.members)
      {
        it.onlineStatus = ::getMyClanMemberPresence(it.nick)
        drawIcon(it.nick, it.onlineStatus)
      }
  }

  function drawIcon(nick, presence)
  {
    let gObj = scene.findObject("clan_members_list")
    let imgObj = gObj.findObject("img_icon_" + nick)
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = presence.getIcon()
    imgObj["background-color"] = presence.getIconColor()
    imgObj["tooltip"] = ::loc(presence.getTooltip())
  }

  function getColumnDataById(id)
  {
    return ::u.search(clan_member_list, (@(id) function(c) { return c.id == id })(id))
  }

  function onStatsCategory(obj)
  {
    if (!obj)
      return
    let value = obj.id
    let sortBy = getFieldNameByColumn(value)

    if (statsSortBy == sortBy)
      statsSortReverse = !statsSortReverse
    else
    {
      statsSortBy = sortBy
      local columnData = getColumnDataById(value)
      statsSortReverse = ::getTblValue("inverse", columnData, false)
    }
    guiScene.performDelayed(this, function() { fillClanMemberList(clanData.members) })
  }

  function onSelectUser(obj = null)
  {
    if (::show_console_buttons)
      return
    obj = obj ?? scene.findObject("clan_members_list")
    if (!::check_obj(obj))
      return

    let dataIdx = obj.getValue() - 1 // skiping header row
    onSelectedPlayerIdx(dataIdx)
  }

  function onRowHover(obj)
  {
    if (!::show_console_buttons)
      return
    if (!::check_obj(obj))
      return

    let isHover = obj.isHovered()
    let dataIdx = ::to_integer_safe(::g_string.cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == lastHoveredDataIdx))
     return

    lastHoveredDataIdx = isHover ? dataIdx : -1
    onSelectedPlayerIdx(lastHoveredDataIdx)
  }

  function onSelectedPlayerIdx(dataIdx)
  {
    curPlayer = playerByRow?[dataIdx]
    updateUserOptionButton()
  }

  function onSelectedPlayerIdxLb(dataIdx)
  {
    curPlayer = playerByRowLb?[dataIdx]
    updateUserOptionButton()
  }

  function onChangeMembershipRequirementsWnd()
  {
    if (::has_feature("Clans") && ::has_feature("ClansMembershipEditor")){
      gui_start_modal_wnd(::gui_handlers.clanChangeMembershipReqWnd,
        {
          clanData = clanData,
          owner = this,
        })
    }
    else
      notAvailableYetMsgBox();
  }

  function onOpenClanBlacklist()
  {
    ::gui_start_clan_blacklist(clanData)
  }

  function onUserCard()
  {
    if (curPlayer && ::has_feature("UserCards"))
      ::gui_modal_userCard({ name = curPlayer })
  }

  function onUserRClick()
  {
    openUserRClickMenu()
  }

  function openUserRClickMenu()
  {
    if (!curPlayer)
      return

    let curMember = ::u.search(clanData.members, (@(member) member.nick == curPlayer).bindenv(this))
    if (!curMember)
      return

    playerContextMenu.showMenu(null, this, {
      uid = curMember.uid
      playerName = curMember.nick
      clanData = clanData
    })
  }

  function onMembershipReq(obj = null)
  {
    let curClan = getCurClan()
    if (curClan)
      ::g_clans.requestMembership(curClan)
  }

  function onClanAverageActivity(obj = null)
  {
    if (clanData)
      ::gui_handlers.clanAverageActivityModal.open(clanData)
  }

  function onClanVehicles(obj = null)
  {
    vehiclesModal.open(@(u)u.isSquadronVehicle() && u.isVisibleInShop(), {
      wndTitleLocId = "clan/vehicles"
      lastSelectedUnit = ::getAircraftByName(::clan_get_researching_unit())
    })
  }

  function onClanSquads(obj = null)
  {
    if (clanData)
      ::gui_handlers.MyClanSquadsListModal.open()
  }

  function onClanLog(obj = null)
  {
    if (clanData)
      ::show_clan_log(clanData.id)
  }

  function onClanSeasonRewardLog(obj = null)
  {
    if (clanData)
      ::g_clans.showClanRewardLog(clanData)
  }

  function onEventClanMembershipRequested(p)
  {
    fillClanManagment()
  }

  function onEventClanMemberDismissed(p)
  {
    if (::clan_get_admin_editor_mode())
      ::sync_handler_simulate_signal("clan_info_reload")

    if (::clan_get_admin_editor_mode())
      reinitClanWindow()
  }

  function onEditClanInfo()
  {
    gui_modal_edit_clan(clanData, this)
  }

  function onUpgradeClan()
  {
    gui_modal_upgrade_clan(clanData, this)
  }

  function onClanComplain()
  {
    ::g_clans.openComplainWnd(clanData)
  }

  function goBack()
  {
    if(::clan_get_admin_editor_mode())
      ::clan_set_admin_editor_mode(false)
    base.goBack()
  }

  function onUserOption()
  {
    openUserRClickMenu()
  }

  function onMembersListFocus(obj)
  {
    guiScene.performDelayed(this, function() {
      if (::check_obj(scene))
        onSelectUser()
    })
  }

  function onEventClanMembersUpgraded(p)
  {
    if (::clan_get_admin_editor_mode() && p.clanId == clanIdStrReq)
      reinitClanWindow()
  }

  function onEventClanMemberRoleChanged(p)
  {
    if (::clan_get_admin_editor_mode())
      reinitClanWindow()
  }

  function onEventClanMembershipAcceptanceChanged(p)
  {
    if (::clan_get_admin_editor_mode())
      reinitClanWindow()
  }

  function onCategory(obj)
  {
  }

  function getWndHelpConfig()
  {
    let res = {
      textsBlk = "%gui/clans/clanPageModalHelp.blk"
      objContainer = scene.findObject("clan_container")
    }

    let links = [
      { obj = ["clan_activity_icon", "clan_activity_value"]
        msgId = "hint_clan_activity"
      }

      { obj = ["clan_elo_icon", "clan_elo_value"]
        msgId = "hint_clan_elo"
      }

      { obj = "img_td_1"
        msgId = "hint_air_kills"
      }

      { obj = "img_td_2"
        msgId = "hint_ground_kills"
      }

      { obj = "img_td_3"
        msgId = "hint_death"
      }

      { obj = "img_td_4"
        msgId = "hint_time_pvp_played"
      }

      { obj = "txt_activity"
        msgId = "hint_membership_activity"
      }
    ]

    res.links <- links
    return res
  }

  function requestWwMembersList()
  {
    let cb = ::Callback(function(membersData) {
        updateCurWwMembers(membersData)
        updateWwMembersList()
      }, this)
    wwLeaderboardData.requestWwLeaderboardData(
      "ww_users_clan",
      {
        gameMode = "ww_users_clan"
        table    = "season"
        group    = clanData.id.tostring()
        start    = 0
        count    = clanData.mlimit
        category = ::g_lb_category.EVENTS_PERSONAL_ELO.field
      },
      @(membersData) cb(membersData))
  }

  function getAdditionalTabsArray()
  {
    if (!::is_worldwar_enabled() || !::has_feature("WorldWarLeaderboards"))
      return []

    if (getSeparateLeaderboardPlatformValue() && !::has_feature("ConsoleSeparateWWLeaderboards"))
      return []

    requestWwMembersList()
    return [{
      id = "worldwar_mode"
      hidden = false
      tabName = ::loc("userlog/page/worldWar")
      selected = false
      isWorldWarMode = true
      tooltip = ::loc("worldwar/ClanMembersLeaderboard/tooltip")
    }]
  }

  function getDefaultWwMemberData(member)
  {
    return {
      idx = -1
      _id = member.uid.tointeger()
      unit_rank = { value_total = member?.max_unit_rank ?? 1 }
    }
  }

  function updateDataByUnitRank(membersData)
  {
    let res = {}
    foreach (member in clanData.members)
    {
      res[member.nick] <- getDefaultWwMemberData(member)
      let data = ::u.search(membersData, @(inst) inst?._id == member.uid.tointeger())
      if (data != null)
        res[member.nick].__update(data)
    }
    return res
  }

  function updateCurWwMembers(membersData = {})
  {
    curWwMembers = wwLeaderboardData.convertWwLeaderboardData(
      updateDataByUnitRank(membersData)).rows
  }


  function updateWwMembersList()
  {
    if (!isClanInfo)
      return

    if(isWorldWarMode)
      fillClanWwMemberList()
  }
}
