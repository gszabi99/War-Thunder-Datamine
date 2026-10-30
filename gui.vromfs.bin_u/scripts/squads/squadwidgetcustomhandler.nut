import "%scripts/social/crossplay.nut" as crossplayModule
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/squads/squadInviteListWnd.nut" import squadInviteListWnd
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/chat/chatStates.nut" import chatStatesCanUseVoice
from "%scripts/squads/leaderWwOperationStates.nut" import getSquadLeaderOperation
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/user/playerContextMenu.nut" import showSquadMemberMenu
from "%scripts/contacts/searchForSquadHandler.nut" import openSearchSquadPlayer
from "%scripts/globalWorldwarUtils.nut" import joinOperationById
from "%scripts/contacts/contacts.nut" import getContact
from "chat" import get_option_voicechat
from "worldwar" import wwGetOperationId
from "%scripts/dagui_natives.nut" import ps4_is_ugc_enabled, ps4_is_chat_enabled
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import WW_GLOBAL_STATUS_TYPE
from "%scripts/squads/squadsConsts.nut" import squadMemberState
from "%scripts/chat/chatConsts.nut" import voiceChatStats
from "%scripts/shop/shopCountriesList.nut" import checkCountry

const SQUAD_MEMBERS_TO_HIDE_TITLE = 3

register_gui_handler("SquadWidgetCustomHandler", class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/squads/squadWidget.tpl"

  squadStateToString = {
    [squadMemberState.SQUAD_LEADER] = "leader",
    [squadMemberState.SQUAD_MEMBER] = "notReady",
    [squadMemberState.SQUAD_MEMBER_READY] = "ready",
    [squadMemberState.SQUAD_MEMBER_OFFLINE] = "offline",
  }

  function getSceneTplView() {
    let readyText = loc("mainmenu/btnReady")
    let notReadyText = loc("multiplayer/btnNotReady")
    let readyTextWidth = getStringWidthPx(readyText, "fontNormal", this.guiScene)
    let notReadyTextWidth = getStringWidthPx(notReadyText, "fontNormal", this.guiScene)
    let squadLeaderOperationId = getSquadLeaderOperation()?.id
    let view = {
      readyBtnHiddenText = readyTextWidth > notReadyTextWidth ? readyText : notReadyText
      isWorldWarShow = squadLeaderOperationId != null
        && squadLeaderOperationId != wwGetOperationId()
      members = []
    }

    let showCrossplayIcon = crossplayModule.needShowCrossPlayInfo()
    for (local i = 0; i < g_squad_manager.getSMMaxSquadSize(); i++)
      view.members.append({
        id = i.tostring()
        showCrossplayIcon = showCrossplayIcon
      })

    return view
  }

  function initScreen() {
    this.updateView()
  }

  function updateView() {
    let leader = g_squad_manager.getSquadLeaderData()
    this.updateMemberView(0, leader)
    local memberViewIndex = 1
    let members = g_squad_manager.getMembers()
    foreach (_uid, member in members) {
      if (member == leader)
        continue

      this.updateMemberView(memberViewIndex++, member)
    }

    while (memberViewIndex < g_squad_manager.getSMMaxSquadSize())
      this.updateMemberView(memberViewIndex++, null)

    this.updateVisibles()
  }

  function updateMemberView(mebmerObjIndex, member) {
    let indexStr = mebmerObjIndex.tostring()
    let isVisible = member != null
    let memberObj = showObjById($"member_{indexStr}", isVisible, this.scene)
    if (!isVisible || !checkObj(memberObj))
      return

    showObjById($"member_waiting_{indexStr}", !member.isActualData(), this.scene)
    showObjById($"member_state_block_{indexStr}", member.isActualData(), this.scene)

    memberObj["uid"] = member.uid
    memberObj["isMe"] = member.isMe() ? "yes" : "no"
    memberObj.setUserData(member)
    memberObj.findObject($"member_icon_{indexStr}").setValue(member.pilotIcon)
    memberObj.findObject($"member_tooltip_{indexStr}")["uid"] = member.uid

    if (member.isActualData()) {
      let contact = getContact(member.uid)
      local countryIcon = ""
      if (checkCountry(member.country, $"squad member data ( uid = {member.uid})", true))
        countryIcon = getCountryIcon(member.country)

      let status = g_squad_manager.getPlayerStatusInMySquad(member.uid)
      memberObj["status"] = (this.squadStateToString?[status] ?? "")
      memberObj.findObject($"member_country_{indexStr}")["background-image"] = countryIcon

      let memberVoipObj = memberObj.findObject($"member_voip_{indexStr}")
      memberVoipObj["isVoipActive"] = contact.voiceStatus == voiceChatStats.talking ? "yes" : "no"
      let needShowVoice = chatStatesCanUseVoice() && get_option_voicechat()
      memberVoipObj.show(needShowVoice)

      let memberCrossPlayObj = memberObj.findObject($"member_crossplay_active_{indexStr}")
      memberCrossPlayObj["isEnabledCrossPlay"] = member.crossplay ? "yes" : "no"

      let speakingMemberNickTextObj = memberObj.findObject($"speaking_member_nick_text_{indexStr}")
      speakingMemberNickTextObj.setValue(getPlayerName(member.name))
    }
  }

  function updateVisibles() {
    let canInvite = g_squad_manager.canInviteMember()
    let isInTransition = g_squad_manager.isStateInTransition()

    let plusButtonObj = showObjById("btn_squadPlus", canInvite, this.scene)
    if (plusButtonObj && canInvite)
      plusButtonObj.enable(ps4_is_ugc_enabled() && ps4_is_chat_enabled())

    showObjById("wait_icon", isInTransition, this.scene)

    showObjById("txt_squad_title", g_squad_manager.canManageSquad()
      && g_squad_manager.getMembers().len() < SQUAD_MEMBERS_TO_HIDE_TITLE, this.scene)

    showObjById("btn_squadInvites", squadInviteListWnd.canOpen(), this.scene)
    this.updateVisibleNewApplications()

    let btnSquadLeave = showObjById("btn_squadLeave", g_squad_manager.canLeaveSquad(), this.scene)
    btnSquadLeave.tooltip = loc("squadAction/leave")

    this.updateWwButtons()
    this.scene.show(isInTransition || canInvite || g_squad_manager.isInSquad())
  }

  function updateWwButtons() {
    let squadLeaderOperation = getSquadLeaderOperation()
    let wwBtnObj = showObjById("btn_world_war",
      squadLeaderOperation && squadLeaderOperation.id != wwGetOperationId(), this.scene)
    if (wwBtnObj?.isValid())
      wwBtnObj.tooltip = "".concat(loc("worldwar/squadLeaderInOperation"), " ",
        loc("ui/quotes", { text = squadLeaderOperation?.getNameText() ?? "" }))

    let btnSquadReady = showObjById("btn_squad_ready",
      g_squad_manager.canSwitchReadyness() && !squadLeaderOperation, this.scene)
    btnSquadReady.findObject("text").setValue(
      loc(g_squad_manager.isMeReady() ? "multiplayer/btnNotReady" : "mainmenu/btnReady"))
  }

  function canShowContactTooltip(contact) {
    return contact != null
  }

  function onSquadPlus() {
    openSearchSquadPlayer()
  }

  function onSquadReady() {
    if (wwGetOperationId() < 0)
      g_squad_manager.setReadyFlag()
  }

  function onSquadInvitesClick(obj) {
    if (checkObj(obj))
      squadInviteListWnd.open(obj.findObject("invite_widget"))
  }

  function onSquadLeave() {
    if (!g_squad_manager.isInSquad())
      return

    this.msgBox("leave_squad", loc("squad/ask/leave"),
      [
        ["yes", function() {
          g_squad_manager.leaveSquad()
        }],
        ["no", function() {} ]
      ], "yes",
      { cancel_fn = function() {} })
  }

  function onSquadMemberMenu(obj) {
    showSquadMemberMenu(obj)
  }

  function updateVisibleNewApplications() {
    let objGlow = this.scene.findObject("iconGlow")
    if (checkObj(objGlow))
      objGlow.wink = (squadInviteListWnd.canOpen() &&
        g_squad_manager.getHasNewApplication()) ? "yes" : "no"
  }

  
  function onEventSquadHasNewApplications(_params) {
    this.doWhenActiveOnce("updateVisibleNewApplications")
  }

  function onEventSquadSetReady(_params) {
    this.doWhenActiveOnce("updateView")
  }

  function onEventSquadDataUpdated(_params) {
    this.doWhenActiveOnce("updateView")
  }

  function onEventMyStatsUpdated(_params) {
    this.doWhenActiveOnce("updateView")
  }

  function onEventSquadStatusChanged(_params) {
    this.doWhenActiveOnce("updateVisibles")
  }

  function onEventQueueChangeState(_params) {
    this.doWhenActiveOnce("updateVisibles")
  }

  function onEventVoiceChatStatusUpdated(params) {
    let uid = (params?.uid ?? "")
    if (g_squad_manager.getMemberData(uid) == null)
      return

    this.doWhenActiveOnce("updateView")
  }

  function onEventVoiceChatOptionUpdated(_p) {
    this.doWhenActiveOnce("updateView")
  }

  function checkActiveForDelayedAction() {
    return this.isSceneActive()
  }

  onEventOperationInfoUpdated = @(_) this.updateWwButtons()

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
      this.updateWwButtons()
  }

  function onWorldWar() {
    let squadLeaderOperationId = getSquadLeaderOperation()?.id
    if (squadLeaderOperationId == null || squadLeaderOperationId == wwGetOperationId())
      return

    this.guiScene.performDelayed(this, @() joinOperationById(squadLeaderOperationId,
      g_squad_manager.getWwOperationCountry()))
  }
})
