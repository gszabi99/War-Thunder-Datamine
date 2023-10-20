//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { countSizeInItems } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { isPlayerFromPS4, isPlayerFromXboxOne, isPlatformSony, isPlatformXboxOne
} = require("%scripts/clientState/platform.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let vehiclesModal = require("%scripts/unit/vehiclesModal.nut")
let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let clanMembershipAcceptance = require("%scripts/clans/clanMembershipAcceptance.nut")
let clanRewardsModal = require("%scripts/rewards/clanRewardsModal.nut")
let clanInfoView = require("%scripts/clans/clanInfoView.nut")
let { getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { convertLeaderboardData } = require("%scripts/leaderboard/requestLeaderboardData.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { create_option_switchbox } = require("%scripts/options/optionsExt.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { get_warpoints_blk } = require("blkGetters")
let { userName, userIdStr } = require("%scripts/user/myUser.nut")

let clan_member_list = [
  { id = "onlineStatus", lbDataType = lbDataType.TEXT, myClanOnly = true, iconStyle = true, needHeader = false }
  { id = "nick", lbDataType = lbDataType.NICK, align = "left" }
  { id = ::ranked_column_prefix, lbDataType = lbDataType.NUM, loc = "rating", byDifficulty = true
    tooltip = "#clan/personal/dr_era/desc" }
  {
    id = "activity"
    lbDataType = lbDataType.NUM
    field = @() hasFeature("ClanVehicles") ? "totalPeriodActivity" : "totalActivity"
    showByFeature = "ClanActivity"
    getCellTooltipText = function(_data) { return loc($"clan/personal/{this.id}/cell/desc") }
    getTooltipText  = @(depth) loc("clan/personal/activity/desc",
      { historyDepth = depth })
  }
  {
    id = "role",
    lbDataType = lbDataType.ROLE,
    sortId = "roleRank"
    sortPrepare = function(member) { member[this.sortId] <- ::clan_get_role_rank(member.role) }
    getCellTooltipText = function(data) { return this.lbDataType.getPrimaryTooltipText(data?[this.id]) }
  }
  { id = "date", lbDataType = lbDataType.DATE }
]

let clan_data_list = [
  { id = "air_kills", lbDataType = lbDataType.NUM, field = "akills" }
  { id = "ground_kills", lbDataType = lbDataType.NUM, field = "gkills" }
  { id = "deaths", lbDataType = lbDataType.NUM, field = "deaths" }
  { id = "time_pvp_played", lbDataType = lbDataType.TIME_MIN, field = "ftime" }
]

let default_clan_member_list = {
  onlyMyClan = false
  iconStyle = false
  byDifficulty = false
}
foreach (idx, item in clan_member_list) {
  foreach (param, value in default_clan_member_list)
    if (!(param in item))
      clan_member_list[idx][param] <- value

  if (!("tooltip" in item))
    item.tooltip <- $"#clan/personal/{item.id}/desc"
}

::showClanPage <- function showClanPage(id, name, tag) {
  ::gui_start_modal_wnd(gui_handlers.clanPageModal,
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}

gui_handlers.clanPageModal <- class extends gui_handlers.BaseGuiHandlerWT {
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
  needFillModeListBox = true

  function initScreen() {
    this.playerByRow   = []
    this.playerByRowLb = []

    if (this.clanIdStrReq == "" && this.clanNameReq == "" && this.clanTagReq == "") {
      this.goBack()
      return
    }
    this.curWwCategory = ::g_lb_category.EVENTS_PERSONAL_ELO
    this.initLbTable()
    this.curMode = this.getCurDMode()
    this.setDefaultSort()
    this.reinitClanWindow()
  }

  setDefaultSort = @() this.statsSortBy = $"{::ranked_column_prefix}{::g_difficulty.getDifficultyByDiffCode(this.curMode).clanDataEnding}"

  function reinitClanWindow() {
    if (::is_in_clan() &&
      (::clan_get_my_clan_id() == this.clanIdStrReq ||
       ::clan_get_my_clan_name() == this.clanNameReq ||
       ::clan_get_my_clan_tag() == this.clanTagReq)) {
      ::requestMyClanData()
      if (!::my_clan_info)
        return

      this.clanData = ::my_clan_info
      this.fillClanPage()
      return
    }
    if (this.clanIdStrReq == "" && this.clanNameReq == "" && this.clanTagReq == "")
      return

    this.taskId = ::clan_request_info(this.clanIdStrReq, this.clanNameReq, this.clanTagReq)
    if (this.taskId >= 0) {
      ::set_char_cb(this, this.slotOpCb)
      this.afterSlotOp = function() {
        this.clanData = ::get_clan_info_table()
        if (!this.clanData)
          return this.goBack()
        this.fillClanPage()
        broadcastEvent("ClanInfoAvailable", { clanId = this.clanData.id })
      }
      this.afterSlotOpError = function(_result) {
        this.goBack()
        return
      }
    }
    else {
      this.goBack()
      this.msgBox("unknown_identification", loc("charServer/updateError/13"),
        [["ok", function() {} ]], "ok")
      log(format("Failed to find clan by id: %s", this.clanIdStrReq))
      return
    }
  }

  function initLbTable() {
    this.lbTableWeak = gui_handlers.LeaderboardTable.create({
      scene = this.scene.findObject("lb_table_nest")
      onCategoryCb = Callback(this.onCategory, this)
      onRowSelectCb = Callback(this.onSelectedPlayerIdxLb, this)
      onRowHoverCb = showConsoleButtons.value ? Callback(this.onSelectedPlayerIdxLb, this) : null
      onRowDblClickCb = Callback(this.onUserCard, this)
      onRowRClickCb = Callback(this.onUserRClick, this)
    })
  }

  function onEventClanInfoUpdate(_params = {}) {
    if (this.clanIdStrReq == ::clan_get_my_clan_id()
        || (this.clanData && this.clanData.id == ::clan_get_my_clan_id())) {
      if (!::my_clan_info)
        return this.goBack()
      this.clanData = ::my_clan_info
      this.fillClanPage()
    }
  }

  function onEventProfileUpdated(_p) {
    this.fillClanManagment()
  }

  function onEventContactsGroupUpdate(_p) {
    this.doWhenActiveOnce("reinitClanWindow")
  }

  function fillClanInfoRow(id, text, feature = "") {
    let obj = this.scene.findObject(id)
    if (!checkObj(obj))
      return

    if (!u.isEmpty(feature) && !hasFeature(feature))
      text = ""
    text = ::g_chat.filterMessageText(text, false)

    obj.setValue(text)
  }

  function fillClanPage() {
    if (!checkObj(this.scene))
      return

    this.clanData = ::getFilteredClanData(this.clanData)

    this.isMyClan = ::clan_get_my_clan_id() == this.clanData.id;
    this.scene.findObject("clan_loading").show(false)

    this.showSceneBtn("clan-icon", true)
    this.fillClanInfoRow("clan-region",
      this.clanData.region != "" ? $"{loc("clan/clan_region")}{loc("ui/colon")}{this.clanData.region}" : "",
      "ClanRegions")
    this.fillClanInfoRow("clan-about",
      this.clanData.desc != "" || this.clanData.announcement != ""
        ? "\n".join([this.clanData.desc, hasFeature("ClanAnnouncements") ? this.clanData.announcement : ""], true)
        : "")
    this.fillClanInfoRow("clan-motto",
      this.clanData.slogan != "" ? $"{loc("clan/clan_slogan")}{loc("ui/colon")}{this.clanData.slogan}" : "")

    this.fillCreatorData()

    this.scene.findObject("nest_lock_clan_req").clan_locked = !clanMembershipAcceptance.getValue(this.clanData) ? "yes" : "no"

        // Showing clan name in special header object if possible.
    let clanName = $"{this.clanData.tag} {this.clanData.name}"
    let headerTextObj = this.scene.findObject("clan_page_header_text")
    let clanTitleObj = this.scene.findObject("clan-title")
    if (checkObj(headerTextObj)) {
      let locId = $"clan/clanInfo/{this.clanData.clanType.getTypeName()}"
      let text = colorize(this.clanData.clanType.color, loc(locId, { clanName = clanName }))
      headerTextObj.setValue(text)
      clanTitleObj.setValue("")
    }
    else
      clanTitleObj.setValue(colorize(this.clanData.clanType.color, clanName))

    let clanDate = this.clanData.getCreationDateText()
    let dateText = $"{loc("clan/creationDate")} {colorize("activeTextColor", clanDate)}"

    let membersCountText = ::g_clans.getClanMembersCountText(this.clanData)
    let countText = "".concat(loc("clan/memberListTitle"),
      loc("ui/parentheses/space", { text = colorize("activeTextColor", membersCountText) }))
    this.scene.findObject("clan-memberCount-date").setValue(" ".join([countText, dateText], true))

    this.fillClanRequirements()

    local updStatsText = time.buildTimeStr(time.getUtcMidnight(), false, false)

    updStatsText = loc("ui/parentheses/space",
      { text = format(loc("clan/updateStatsTime"), updStatsText) })
    this.scene.findObject("update_stats_info_text").setValue(
      "<b>{0}</b> {1}".subst(colorize("commonTextColor", loc("clan/stats")), updStatsText))
     this.onceFillModeList(this.scene.findObject("clan_container"), this.getCurDMode(),
      ::get_show_in_squadron_statistics, this.getAdditionalTabsArray())
    this.fillClanManagment()

    this.showSceneBtn("clan_main_stats", true)
    this.fillClanStats(this.clanData.astat)
  }

  function onceFillModeList(scene, mode, statistics, additionalTabsArray) {
    if(this.needFillModeListBox)
      this.fillModeListBox(scene, mode, statistics, additionalTabsArray)
    this.needFillModeListBox = false
  }

  function fillCreatorData() {
    let obj = this.scene.findObject("clan-prevChanges")
    if (!checkObj(obj))
      return

    let isVisible = hasFeature("ClanChangedInfoData")
                      && this.clanData.changedByUid != ""
                      && this.clanData.changedByNick != ""
                      && this.clanData.changedTime

    local text = ""
    if (isVisible) {
      let color = userIdStr.value == this.clanData.changedByUid ? "mainPlayerColor" : "activeTextColor"
      text = "".concat(loc("clan/lastChanges"), loc("ui/colon"),
      loc("ui/comma").join(
        [
          colorize(color, getPlayerName(this.clanData.changedByNick))
          this.clanData.getInfoChangeDateText()
        ],
        true
      ))
    }
    obj.setValue(text)
  }

  function fillClanRequirements() {
    if (!this.clanData)
      return

    this.scene.findObject("clan-membershipReq").setValue(
      clanInfoView.getClanRequirementsText(this.clanData.membershipRequirements))
  }


  function fillClanManagment() {
    if (!this.clanData)
      return

    let adminMode = ::clan_get_admin_editor_mode()
    let myClanId = ::clan_get_my_clan_id();
    local showMembershipsButton = false
    this.isMyClan = myClanId == this.clanData.id;

    if (!this.isMyClan && myClanId == "-1" && ::clan_get_requested_clan_id() != this.clanData.id &&
      clanMembershipAcceptance.getValue(this.clanData))
        showMembershipsButton = true

    if (this.isMyClan || adminMode)
      this.myRights = ::clan_get_role_rights(adminMode ? ECMR_CLANADMIN : ::clan_get_my_role())
    else
      this.myRights = []

    let showBtnLock = clanMembershipAcceptance.canChange(this.clanData)
    let hasLeaderRight = isInArray("LEADER", this.myRights)
    let showMembershipsReqEditorButton = (hasFeature("ClansMembershipEditor")) && (
                                            (this.isMyClan && isInArray("CHANGE_INFO", this.myRights)) || ::clan_get_admin_editor_mode())
    let showClanSeasonRewards = hasFeature("ClanSeasonRewardsLog") && (this.clanData.rewardLog.len() > 0)

    let buttonsList = {
      btn_showRequests = ((this.isMyClan && (isInArray("MEMBER_ADDING", this.myRights) || isInArray("MEMBER_REJECT", this.myRights))) || adminMode) && this.clanData.candidates.len() > 0
      btn_leaveClan = this.isMyClan && (!hasLeaderRight || ::g_clans.getLeadersCount(this.clanData) > 1)
      btn_edit_clan_info = ::ps4_is_ugc_enabled() && ((this.isMyClan && isInArray("CHANGE_INFO", this.myRights)) || adminMode)
      btn_upgrade_clan = this.clanData.clanType.getNextType() != ::g_clan_type.UNKNOWN && (adminMode || (this.isMyClan && hasLeaderRight))
      btn_showBlacklist = ((this.isMyClan && isInArray("MEMBER_BLACKLIST", this.myRights)) || adminMode) && this.clanData.blacklist.len()
      btn_lock_clan_req = showBtnLock
      img_lock_clan_req = !showBtnLock && !clanMembershipAcceptance.getValue(this.clanData)
      btn_complain = !this.isMyClan
      btn_membership_req = showMembershipsButton
      btn_log = hasFeature("ClanLog")
      btn_season_reward_log = showClanSeasonRewards
      clan_awards_container = showClanSeasonRewards
      btn_clan_membership_req_edit = showMembershipsReqEditorButton
      btn_clanSquads = hasFeature("ClanSquads") && this.isMyClan
      btn_clanActivity = hasFeature("ClanVehicles") && this.isMyClan
      btn_clanVehicles = hasFeature("ClanVehicles") && this.isMyClan
    }
    showObjectsByTable(this.scene, buttonsList)

    this.showSceneBtn("clan_actions", buttonsList.btn_showRequests
      || buttonsList.btn_clanSquads
      || buttonsList.btn_log)

    let showRequestsBtn = this.scene.findObject("btn_showRequests")
    if (checkObj(showRequestsBtn)) {
      showRequestsBtn.setValue($"{loc("clan/btnShowRequests")} ({this.clanData.candidates.len()})")
      showRequestsBtn.wink = buttonsList.btn_showRequests ? "yes" : "no"
    }

    if (showClanSeasonRewards) {
      let containerObj = this.scene.findObject("clan_awards_container")
      if (checkObj(containerObj))
        this.guiScene.performDelayed(this, (@(clanData) function () { //-ident-hides-ident
          if (!this.isValid())
            return

          let count = countSizeInItems(containerObj.getParent(), "@clanMedalSizeMin", 1, 0, 0).itemsCountX
          let medals = ::g_clans.getClanPlaceRewardLogData(clanData, count)
          local markup = ""
          local rest = min(medals.len(), get_warpoints_blk()?.maxClanBestRewards ?? 6)
          foreach (m in medals)
            if (clanRewardsModal.isRewardVisible(m, clanData))
              if (rest-- > 0)
                markup = "".concat(markup,
                  "layeredIconContainer { size:t='@clanMedalSizeMin,",
                  "@clanMedalSizeMin'; overflow:t='hidden' ",
                  LayersIcon.getIconData(m.iconStyle, null, null, null, m.iconParams, m.iconConfig),
                  "}")
          this.guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
        })(this.clanData))
    }

    this.updateAdminModeSwitch()
    this.updateUserOptionButton()
  }

  function getCurClan() {
    return this.clanData?.id
  }

  function updateUserOptionButton() {
    showObjectsByTable(this.scene, {
      btn_usercard      = this.curPlayer != null && hasFeature("UserCards")
      btn_user_options  = this.curPlayer != null && showConsoleButtons.value
    })
  }

  function fillClanElo() {
    let difficulty = ::g_difficulty.getDifficultyByDiffCode(this.curMode)
    let lbImageObj = this.scene.findObject("clan_elo_icon")
    if (checkObj(lbImageObj))
      lbImageObj["background-image"] = difficulty.clanRatingImage

    let eloTextObj = this.scene.findObject("clan_elo_value")
    if (checkObj(eloTextObj)) {
      let clanElo = this.clanData.astat?[$"{::ranked_column_prefix}{difficulty.clanDataEnding}"] ?? 0
      eloTextObj.setValue(clanElo.tostring())
    }
  }

  function fillClanActivity() {
    let activityTextObj = this.scene.findObject("clan_activity_value")
    let activityIconObj = this.scene.findObject("clan_activity_icon")
    if (!checkObj(activityTextObj) || !checkObj(activityIconObj))
      return

    let showActivity = hasFeature("ClanActivity")
    if (showActivity) {
      let clanActivity = this.clanData.astat?.clan_activity_by_periods ?? this.clanData.astat?.activity ?? 0
      activityTextObj.setValue(clanActivity.tostring())
      activityIconObj["background-image"] = "#ui/gameuiskin#lb_activity.svg"
    }
    activityTextObj.show(showActivity)
    activityIconObj.show(showActivity)
  }

  function setCurDMode(mode) {
    saveLocalByAccount("wnd/clanDiffMode", mode)
  }

  function getCurDMode() {
    let diffMode = loadLocalByAccount(
      "wnd/clanDiffMode",
      ::get_current_shop_difficulty().diffCode
    )

    let diff = ::g_difficulty.getDifficultyByDiffCode(diffMode)

    if (::get_show_in_squadron_statistics(diff))
      return diffMode
    return ::g_difficulty.REALISTIC.diffCode
  }

  function cp_onStatsModeChange(obj) {
    let tabObj = obj.getChild(obj.getValue())
    this.isWorldWarMode = tabObj?.isWorldWarMode == "yes"
    this.showSceneBtn("clan_members_list_nest", !this.isWorldWarMode)
    this.showSceneBtn("lb_table_nest", this.isWorldWarMode)
    this.showSceneBtn("season_over_notice", this.isWorldWarMode && !::g_world_war.isWWSeasonActive())

    this.curPlayer = null

    if (this.isWorldWarMode) {
      this.fillClanWwMemberList()
      return
    }

    let diffCode = tabObj.holderDiffCode.tointeger()
    let diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
    if (!::get_show_in_squadron_statistics(diff))
      return

    this.curMode = diffCode
    this.setCurDMode(this.curMode)
    this.updateSortingField()
    this.fillClanMemberList(this.clanData.members)
    this.fillClanElo()
    this.fillClanActivity()
  }

  function updateSortingField() {
    if (this.statsSortBy.len() >= ::ranked_column_prefix.len() &&
        this.statsSortBy.indexof(::ranked_column_prefix) == 0)
      this.setDefaultSort()
  }

  function updateAdminModeSwitch() {
    let show = this.isClanInfo && ::is_myself_clan_moderator()
    let enable = ::clan_get_admin_editor_mode()
    local obj = this.scene.findObject("admin_mode_switch")
    if (!checkObj(obj)) {
      if (!show)
        return
      let containerObj = this.scene.findObject("header_buttons")
      if (!checkObj(containerObj))
        return
      let text = loc("clan/admin_mode")
      let markup = create_option_switchbox({
        id = "admin_mode_switch"
        value = enable
        textChecked = text
        textUnchecked = text
        cb = "onSwitchAdminMode"
      })
      this.guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
      obj = containerObj.findObject("admin_mode_switch")
      if (!checkObj(obj))
        return
    }
    else
      obj.setValue(enable)
    obj.show(show)
  }

  function onSwitchAdminMode() {
    this.enableAdminMode(!::clan_get_admin_editor_mode())
  }

  function enableAdminMode(enable) {
    if (enable == ::clan_get_admin_editor_mode())
      return
    if (enable && (!this.isClanInfo || !::is_myself_clan_moderator()))
      return
    ::clan_set_admin_editor_mode(enable)
    this.fillClanManagment()
    this.onSelectUser()
  }

  function onShowRequests() {
    if ((!this.isMyClan || !isInArray("MEMBER_ADDING", this.myRights)) && !::clan_get_admin_editor_mode())
      return;

    ::showClanRequests(this.clanData.candidates, this.clanData.id, this)
  }

  function onLockNewReqests() {
    let value = clanMembershipAcceptance.getValue(this.clanData)
    clanMembershipAcceptance.setValue(this.clanData, !value, this)
  }

  function onLeaveClan() {
    if (!this.isMyClan)
      return;

    this.msgBox("leave_clan", loc("clan/leaveConfirmation"),
      [
        ["yes", function() {
          this.leaveClan();
        }],
        ["no",  function() {} ],
      ], "no", { cancel_fn = function() {} })
  }

  function leaveClan() {
    if (!::is_in_clan())
      return this.afterClanLeave()

    this.taskId = ::clan_request_leave()

    if (this.taskId >= 0) {
      ::set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox()
      ::sync_handler_simulate_signal("clan_info_reload")
      this.afterSlotOp = this.guiScene.performDelayed(this, function() {
          ::update_gamercards()
          this.msgBox("left_clan", loc("clan/leftClan"),
            [["ok", function() { if (this.isValid()) this.afterClanLeave() } ]], "ok")
        })
    }
  }

  function afterClanLeave() {
    this.goBack()
  }

  function fillClanStats(data) {
    let clanTableObj = this.scene.findObject("clan_stats_table");
    local rowIdx = 0
    local rowBlock = ""
    let rowHeader = [{ width = "0.25pw" }]
    /*header*/
    foreach (item in clan_data_list) {
      rowHeader.append({
                       image = $"#ui/gameuiskin#lb_{item.id}.svg"
                       imageRawParams = "input-transparent:t='yes';"
                       tooltip = $"#multiplayer/{item.id}"
                       tdalign = "center"
                       active = false
                    })
    }
    rowBlock = "".concat(rowBlock, ::buildTableRowNoPad($"row_{rowIdx}", rowHeader, null,
      "class:t='smallIconsStyle'; background-color:t='@separatorBlockColor'"))
    rowIdx++

    /*body*/
    foreach (diff in ::g_difficulty.types) {
      if (!diff.isAvailable() || !::get_show_in_squadron_statistics(diff))
        continue

      let rowParams = []
      rowParams.append({
                         text = diff.getLocName(),
                         active = false,
                         tdalign = "left"
                      })

      foreach (item in clan_data_list) {
        let dataId = $"{item.field}{diff.clanDataEnding}"
        let value = dataId in data ? data[dataId] : "0"
        let textCell = item.lbDataType.getShortTextByValue(value)

        rowParams.append({
                          text = textCell,
                          active = false,
                          tdalign = "center"
                        })
      }
      rowBlock = "".concat(rowBlock, ::buildTableRowNoPad($"row_{rowIdx}", rowParams, null, ""))
      rowIdx++
    }
    this.guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function fillClanWwMemberList() {
    if (this.curWwMembers == null)
      this.updateCurWwMembers() //fill default wwMembers list
    this.lbTableWeak.updateParams(
      ::leaderboardModel,
      ::ww_leaderboards_list,
      this.curWwCategory,
      { lbMode = "ww_users_clan" })

    this.sortWwMembers()
    this.playerByRowLb = this.curWwMembers.map(@(member) member.name)
    this.curPlayer = null
    let myPos = this.curWwMembers.findindex(@(member) member.name == userName.value) ?? -1
    this.lbTableWeak.fillTable(this.curWwMembers, null, myPos, true, true)

    this.updateUserOptionButton()
  }

  function sortWwMembers() {
    let field = this.curWwCategory.field
    let addField = ::g_lb_category.EVENTS_PERSONAL_ELO.field
    local idx = 0
    this.curWwMembers.sort(@(a, b) (b?[field] ?? 0) <=> (a?[field] ?? 0)
      || (b?[addField] ?? 0) <=> (a?[addField] ?? 0))

    this.curWwMembers = this.curWwMembers.map(@(member) member.__update({ pos = idx++ }))
  }

  function fillClanMemberList(membersData) {
    this.sortMembers(membersData)

    let headerRow = [{ text = "#clan/number", width = "0.1@sf" }]
    foreach (column in clan_member_list) {
      if (!this.needShowColumn(column))
        continue

      let rowData = {
        id       = column.id,
        text     = (column?.needHeader ?? true) ? $"#clan/{column?.loc ?? column.id}" : "",
        tdalign  = column?.align ?? "center",
        callback = "onStatsCategory",
        active   = this.isSortByColumn(column.id)
        tooltip  = column?.getTooltipText(this.clanData?.historyDepth.tostring()) ?? column.tooltip
      }
      // It is important to set width to
      // all rows if column has fixed width.
      // Next two lines fix table layout issue.
      if (column?.iconStyle ?? false)
        rowData.width <- "0.01@sf"
      headerRow.append(rowData)
    }

    this.playerByRow = []
    this.curPlayer = null
    local markup = []
    let isConsoleOnlyPlayers = getSeparateLeaderboardPlatformValue()
    let consoleConst = isPlatformSony
      ? [TP_PS4, TP_PS5]
      : isPlatformXboxOne
        ? [TP_XBOXONE, TP_XBOX_SCARLETT]
        : [TP_UNKNOWN]

    foreach (member in membersData) {
      if (isConsoleOnlyPlayers) {
        if (member?.platform != null) {
          if (!isInArray(member.platform, consoleConst))
            continue
        }
        else {
          if ((isPlatformSony && !isPlayerFromPS4(member.nick))
            || (isPlatformXboxOne && !isPlayerFromXboxOne(member.nick)))
            continue
        }
      }

      let rowIdx = this.playerByRow.len()
      let rowData = [{ text = (rowIdx + 1).tostring() }]
      let isMe = member.nick == userName.value
      foreach (column in clan_member_list) {
        if (!this.needShowColumn(column))
          continue
        rowData.append(this.getClanMembersCell(member, column))
      }

      markup.append(::buildTableRowNoPad($"row_{rowIdx}", rowData, rowIdx % 2 != 0, isMe ? "mainPlayer:t='yes';" : ""))
      this.playerByRow.append(member.nick)
    }

    markup.insert(0, ::buildTableRowNoPad("row_header", headerRow, null, "isLeaderBoardHeader:t='yes'"))
    markup = "".join(markup)

    this.guiScene.setUpdatesEnabled(false, false)
    let tblObj = this.scene.findObject("clan_members_list")
    this.guiScene.replaceContentFromText(tblObj, markup, markup.len(), this)
    this.guiScene.setUpdatesEnabled(true, true)

    this.onSelectUser()
    this.updateMembersStatus()
  }

  function needShowColumn(column) {
    if ((column?.myClanOnly ?? false) && !this.isMyClan)
      return false

    if (column?.showByFeature != null && !hasFeature(column?.showByFeature))
      return false

    return true
  }

  function getFieldNameByColumn(columnId) {
    local fieldName = columnId
    if (columnId == ::ranked_column_prefix)
      fieldName = $"{::ranked_column_prefix}{::g_difficulty.getDifficultyByDiffCode(this.curMode).clanDataEnding}"
    else {
      let category = u.search(clan_member_list,  function(category) { return category.id == columnId })
      let field = category?.field ?? columnId
      fieldName = u.isFunction(field) ? field() : field
    }
    return fieldName
  }

  function isSortByColumn(columnId) {
    return this.getFieldNameByColumn(columnId) == this.statsSortBy
  }

  function getClanMembersCell(member, column) {
    let id = this.getFieldId(column)
    let res = {
      text = column.lbDataType.getShortTextByValue(member[id])
      tdalign = column?.align ?? "center"
    }

    if ("getCellTooltipText" in column)
      res.tooltip <- column.getCellTooltipText(member)

    if (column?.iconStyle ?? false) {
      res.id       <- $"icon_{member.nick}"
      res.needText <- false
      res.imageType <- "contactStatusImg"
      res.image    <- ""
      if (!("tooltip" in res))
        res.tooltip <- ""
      res.width    <- "0.01@sf"
    }

    return res
  }

  function getFieldId(column) {
    if (!("field" in column) && !column.byDifficulty)
      return column.id

    let field = column?.field ?? column.id
    local fieldId = u.isFunction(field) ? field() : field
    if (column.byDifficulty)
      fieldId = $"{fieldId}{::g_difficulty.getDifficultyByDiffCode(this.curMode).clanDataEnding}"
    return fieldId
  }

  function sortMembers(members) {
    if (type(members) != "array")
      return

    let columnData = this.getColumnDataById(this.statsSortBy)
    let sortId = columnData?.sortId ?? this.statsSortBy
    if ("sortPrepare" in columnData)
      foreach (m in members)
        columnData.sortPrepare(m)

    let isReversSort = this.statsSortReverse
    members.sort(function(left, right) {
      local res = 0
      if (sortId != "" && sortId != "nick") {
        if (left[sortId] < right[sortId])
          res = 1
        else if (left[sortId] > right[sortId])
          res = -1
      }

      if (!res) {
        let nickLeft  = left.nick.tolower()
        let nickRight = right.nick.tolower()
        if (nickLeft < nickRight)
          res = 1
        else if (nickLeft > nickRight)
          res = -1
      }
      return isReversSort ? -res : res
    })
  }

  function onEventClanRoomMembersChanged(params = {}) {
    if (!this.isMyClan)
      return

    let presence = params?.presence ?? ::g_contact_presence.UNKNOWN
    let nick = params?.nick ?? ""

    if (nick == "") {
      this.updateMembersStatus()
      return
    }

    if (!("members" in ::my_clan_info))
      return

    let member = u.search(
      ::my_clan_info.members,
      function (member) { return member.nick == nick }
    )

    if (member) {
      member.onlineStatus = presence
      this.drawIcon(nick, presence)
    }
  }

  function onEventClanRquirementsChanged(_params) {
    this.fillClanRequirements()
  }

  function updateMembersStatus() {
    if (!this.isMyClan)
      return
    if (!::gchat_is_connected())
      return
    if ("members" in ::my_clan_info)
      foreach (it in ::my_clan_info.members) {
        it.onlineStatus = ::getMyClanMemberPresence(it.nick)
        this.drawIcon(it.nick, it.onlineStatus)
      }
  }

  function drawIcon(nick, presence) {
    let gObj = this.scene.findObject("clan_members_list")
    let imgObj = gObj.findObject($"img_icon_{nick}")
    if (!checkObj(imgObj))
      return

    imgObj["background-image"] = presence.getIcon()
    imgObj["background-color"] = presence.getIconColor()
    imgObj["tooltip"] = loc(presence.getTooltip())
  }

  function getColumnDataById(id) {
    return u.search(clan_member_list,  function(c) { return c.id == id })
  }

  function onStatsCategory(obj) {
    if (!obj)
      return
    let value = obj.id
    let sortBy = this.getFieldNameByColumn(value)

    if (this.statsSortBy == sortBy)
      this.statsSortReverse = !this.statsSortReverse
    else {
      this.statsSortBy = sortBy
      local columnData = this.getColumnDataById(value)
      this.statsSortReverse = columnData?.inverse ?? false
    }
    this.guiScene.performDelayed(this, function() { this.fillClanMemberList(this.clanData.members) })
  }

  function onSelectUser(obj = null) {
    if (showConsoleButtons.value)
      return
    obj = obj ?? this.scene.findObject("clan_members_list")
    if (!checkObj(obj))
      return

    let dataIdx = obj.getValue() - 1 // skiping header row
    this.onSelectedPlayerIdx(dataIdx)
  }

  function onRowHover(obj) {
    if (!showConsoleButtons.value)
      return
    if (!checkObj(obj))
      return

    let isHover = obj.isHovered()
    let dataIdx = to_integer_safe(cutPrefix(obj.id, "row_", ""), -1, false)
    if (isHover == (dataIdx == this.lastHoveredDataIdx))
     return

    this.lastHoveredDataIdx = isHover ? dataIdx : -1
    this.onSelectedPlayerIdx(this.lastHoveredDataIdx)
  }

  function onSelectedPlayerIdx(dataIdx) {
    this.curPlayer = this.playerByRow?[dataIdx]
    this.updateUserOptionButton()
  }

  function onSelectedPlayerIdxLb(dataIdx) {
    this.curPlayer = this.playerByRowLb?[dataIdx]
    this.updateUserOptionButton()
  }

  function onChangeMembershipRequirementsWnd() {
    if (hasFeature("Clans") && hasFeature("ClansMembershipEditor")) {
      ::gui_start_modal_wnd(gui_handlers.clanChangeMembershipReqWnd,
        {
          clanData = this.clanData,
          owner = this,
        })
    }
    else
      this.notAvailableYetMsgBox();
  }

  function onOpenClanBlacklist() {
    ::gui_start_clan_blacklist(this.clanData)
  }

  function onUserCard() {
    if (this.curPlayer && hasFeature("UserCards"))
      ::gui_modal_userCard({ name = this.curPlayer })
  }

  function onUserRClick() {
    this.openUserRClickMenu()
  }

  function openUserRClickMenu() {
    if (!this.curPlayer)
      return

    let curMember = u.search(this.clanData.members, (@(member) member.nick == this.curPlayer).bindenv(this))
    if (!curMember)
      return

    playerContextMenu.showMenu(null, this, {
      uid = curMember.uid
      playerName = curMember.nick
      clanData = this.clanData
    })
  }

  function onMembershipReq(_obj = null) {
    let curClan = this.getCurClan()
    if (curClan)
      ::g_clans.requestMembership(curClan)
  }

  function onClanAverageActivity(_obj = null) {
    if (this.clanData)
      gui_handlers.clanAverageActivityModal.open(this.clanData)
  }

  function onClanVehicles(_obj = null) {
    vehiclesModal.open(@(unit) unit.isSquadronVehicle() && unit.isVisibleInShop(), {
      wndTitleLocId = "clan/vehicles"
      lastSelectedUnit = getAircraftByName(::clan_get_researching_unit())
    })
  }

  function onClanSquads(_obj = null) {
    if (this.clanData)
      gui_handlers.MyClanSquadsListModal.open()
  }

  function onClanLog(_obj = null) {
    if (this.clanData)
      ::show_clan_log(this.clanData.id)
  }

  function onClanSeasonRewardLog(_obj = null) {
    if (this.clanData)
      ::g_clans.showClanRewardLog(this.clanData)
  }

  function onEventClanMembershipRequested(_p) {
    this.fillClanManagment()
  }

  function onEventClanMemberDismissed(_p) {
    if (::clan_get_admin_editor_mode())
      ::sync_handler_simulate_signal("clan_info_reload")

    if (::clan_get_admin_editor_mode())
      this.reinitClanWindow()
  }

  function onEditClanInfo() {
    ::gui_modal_edit_clan(this.clanData, this)
  }

  function onUpgradeClan() {
    ::gui_modal_upgrade_clan(this.clanData, this)
  }

  function onClanComplain() {
    ::g_clans.openComplainWnd(this.clanData)
  }

  function goBack() {
    if (::clan_get_admin_editor_mode())
      ::clan_set_admin_editor_mode(false)
    base.goBack()
  }

  function onUserOption() {
    this.openUserRClickMenu()
  }

  function onMembersListFocus(_obj) {
    this.guiScene.performDelayed(this, function() {
      if (checkObj(this.scene))
        this.onSelectUser()
    })
  }

  function onEventClanMembersUpgraded(p) {
    if (::clan_get_admin_editor_mode() && p.clanId == this.clanIdStrReq)
      this.reinitClanWindow()
  }

  function onEventClanMemberRoleChanged(_p) {
    if (::clan_get_admin_editor_mode())
      this.reinitClanWindow()
  }

  function onEventClanMembershipAcceptanceChanged(_p) {
    if (::clan_get_admin_editor_mode())
      this.reinitClanWindow()
  }

  function onCategory(_obj) {
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/clans/clanPageModalHelp.blk"
      objContainer = this.scene.findObject("clan_container")
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

  function requestWwMembersList() {
    let cb = Callback(function(membersData) {
        this.updateCurWwMembers(membersData)
        this.updateWwMembersList()
      }, this)
    wwLeaderboardData.requestWwLeaderboardData(
      "ww_users_clan",
      {
        gameMode = "ww_users_clan"
        table    = "season"
        group    = this.clanData.id.tostring()
        start    = 0
        count    = this.clanData.mlimit
        category = ::g_lb_category.EVENTS_PERSONAL_ELO.field
      },
      @(membersData) cb(membersData))
  }

  function getAdditionalTabsArray() {
    if (!::is_worldwar_enabled() || !hasFeature("WorldWarLeaderboards"))
      return []

    if (getSeparateLeaderboardPlatformValue() && !hasFeature("ConsoleSeparateWWLeaderboards"))
      return []

    this.requestWwMembersList()
    return [{
      id = "worldwar_mode"
      hidden = false
      tabName = loc("userlog/page/worldWar")
      selected = false
      isWorldWarMode = true
      tooltip = loc("worldwar/ClanMembersLeaderboard/tooltip")
    }]
  }

  function getDefaultWwMemberData(member) {
    return {
      idx = -1
      _id = member.uid.tointeger()
      unit_rank = { value_total = member?.max_unit_rank ?? 1 }
    }
  }

  function updateDataByUnitRank(membersData) {
    let res = {}
    foreach (member in this.clanData.members) {
      res[member.nick] <- this.getDefaultWwMemberData(member)
      let data = u.search(membersData, @(inst) inst?._id == member.uid.tointeger())
      if (data != null)
        res[member.nick].__update(data)
    }
    return res
  }

  function updateCurWwMembers(membersData = {}) {
    this.curWwMembers = convertLeaderboardData(
      this.updateDataByUnitRank(membersData)).rows
  }


  function updateWwMembersList() {
    if (!this.isClanInfo)
      return

    if (this.isWorldWarMode)
      this.fillClanWwMemberList()
  }
}
