from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let platformModule = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")

const SQUAD_MEMBERS_TO_HIDE_TITLE = 3

let function getSquadLeaderOperation() {
  if (!::is_worldwar_enabled() || !::g_squad_manager.isSquadMember())
    return null

  let operationId = ::g_squad_manager.getWwOperationId()
  return operationId >= 0 ? ::g_ww_global_status_actions.getOperationById(operationId) : null
}

::init_squad_widget_handler <- function init_squad_widget_handler(nestObj)
{
  if (!hasFeature("Squad") || !hasFeature("SquadWidget") || !checkObj(nestObj))
    return null
  return ::handlersManager.loadCustomHandler(::gui_handlers.SquadWidgetCustomHandler, { scene = nestObj })
}

::gui_handlers.SquadWidgetCustomHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/squads/squadWidget"

  squadStateToString = {
    [squadMemberState.SQUAD_LEADER] = "leader",
    [squadMemberState.SQUAD_MEMBER] = "notReady",
    [squadMemberState.SQUAD_MEMBER_READY] = "ready",
    [squadMemberState.SQUAD_MEMBER_OFFLINE] = "offline",
  }

  function getSceneTplView()
  {
    let readyText = loc("mainmenu/btnReady")
    let notReadyText = loc("multiplayer/btnNotReady")
    let readyTextWidth = daguiFonts.getStringWidthPx(readyText, "fontNormal", this.guiScene)
    let notReadyTextWidth = daguiFonts.getStringWidthPx(notReadyText, "fontNormal", this.guiScene)
    let squadLeaderOperationId = getSquadLeaderOperation()?.id
    let view = {
      readyBtnHiddenText = readyTextWidth > notReadyTextWidth ? readyText : notReadyText
      isWorldWarShow = squadLeaderOperationId != null
        && squadLeaderOperationId != ::ww_get_operation_id()
      members = []
    }

    let showCrossplayIcon = crossplayModule.needShowCrossPlayInfo()
    for (local i = 0; i < ::g_squad_manager.MAX_SQUAD_SIZE; i++)
      view.members.append({
        id = i.tostring()
        showCrossplayIcon = showCrossplayIcon
      })

    return view
  }

  function initScreen()
  {
    updateView()
  }

  function updateView()
  {
    let leader = ::g_squad_manager.getSquadLeaderData()
    updateMemberView(0, leader)
    local memberViewIndex = 1
    let members = ::g_squad_manager.getMembers()
    foreach(_uid, member in members)
    {
      if (member == leader)
        continue

      updateMemberView(memberViewIndex++, member)
    }

    while (memberViewIndex < ::g_squad_manager.MAX_SQUAD_SIZE)
      updateMemberView(memberViewIndex++, null)

    updateVisibles()
  }

  function updateMemberView(mebmerObjIndex, member)
  {
    let indexStr = mebmerObjIndex.tostring()
    let isVisible = member != null
    let memberObj = this.showSceneBtn("member_" + indexStr, isVisible)
    if (!isVisible || !checkObj(memberObj))
      return

    this.showSceneBtn("member_waiting_" + indexStr, !member.isActualData())
    this.showSceneBtn("member_state_block_" + indexStr, member.isActualData())

    memberObj["uid"] = member.uid
    memberObj["isMe"] = member.isMe()? "yes" : "no"
    memberObj.setUserData(member)
    memberObj.findObject("member_icon_" + indexStr).setValue(member.pilotIcon)
    memberObj.findObject("member_tooltip_" + indexStr)["uid"] = member.uid

    if (member.isActualData())
    {
      let contact = ::getContact(member.uid)
      local countryIcon = ""
      if (::checkCountry(member.country, "squad member data ( uid = " + member.uid + ")", true))
        countryIcon = ::get_country_icon(member.country)

      let status = ::g_squad_manager.getPlayerStatusInMySquad(member.uid)
      memberObj["status"] = getTblValue(status, squadStateToString, "")
      memberObj.findObject("member_country_" + indexStr)["background-image"] = countryIcon

      let memberVoipObj = memberObj.findObject("member_voip_" + indexStr)
      memberVoipObj["isVoipActive"] = contact.voiceStatus == voiceChatStats.talking ? "yes" : "no"
      let needShowVoice = chatStatesCanUseVoice()
        && ::get_option_voicechat()
        && !platformModule.isXBoxPlayerName(member.name)
      memberVoipObj.show(needShowVoice)

      let memberCrossPlayObj = memberObj.findObject("member_crossplay_active_" + indexStr)
      memberCrossPlayObj["isEnabledCrossPlay"] = member.crossplay ? "yes" : "no"

      let speakingMemberNickTextObj = memberObj.findObject("speaking_member_nick_text_" + indexStr)
      speakingMemberNickTextObj.setValue(platformModule.getPlayerName(member.name))
    }
  }

  function updateVisibles()
  {
    let canInvite = ::g_squad_manager.canInviteMember()
    let isInTransition = ::g_squad_manager.isStateInTransition()

    let plusButtonObj = this.showSceneBtn("btn_squadPlus", canInvite)
    if (plusButtonObj && canInvite)
      plusButtonObj.enable(::ps4_is_ugc_enabled() && ::ps4_is_chat_enabled())

    this.showSceneBtn("wait_icon", isInTransition)

    this.showSceneBtn("txt_squad_title", ::g_squad_manager.canManageSquad()
      && ::g_squad_manager.getMembers().len() < SQUAD_MEMBERS_TO_HIDE_TITLE)
    let squadLeaderOperation = getSquadLeaderOperation()
    let btnSquadReady = this.showSceneBtn("btn_squad_ready",
      ::g_squad_manager.canSwitchReadyness() && !squadLeaderOperation)
    btnSquadReady.findObject("text").setValue(
      loc(::g_squad_manager.isMeReady() ? "multiplayer/btnNotReady" : "mainmenu/btnReady"))

    this.showSceneBtn("btn_squadInvites", ::gui_handlers.squadInviteListWnd.canOpen())
    updateVisibleNewApplications()

    let btnSquadLeave = this.showSceneBtn("btn_squadLeave", ::g_squad_manager.canLeaveSquad())
    btnSquadLeave.tooltip = loc("squadAction/leave")

    let wwBtnObj = this.showSceneBtn("btn_world_war",
      squadLeaderOperation && squadLeaderOperation.id != ::ww_get_operation_id())
    if (wwBtnObj?.isValid())
      wwBtnObj.tooltip = "".concat(loc("worldwar/squadLeaderInOperation"), " ",
        loc("ui/quotes", { text = squadLeaderOperation?.getNameText() ?? ""}))

    this.scene.show(isInTransition || canInvite || ::g_squad_manager.isInSquad())
  }

  function canShowContactTooltip(contact)
  {
    return contact != null
  }

  function onSquadPlus()
  {
    if (is_platform_xbox && !hasFeature("SquadInviteIngame"))
    {
      ::xbox_show_invite_window()
      return
    }

    ::open_search_squad_player()
  }

  function onSquadReady() {
    if (::ww_get_operation_id() < 0)
      ::g_squad_manager.setReadyFlag()
  }

  function onSquadInvitesClick(obj)
  {
    if (checkObj(obj))
      ::gui_handlers.squadInviteListWnd.open(obj.findObject("invite_widget"))
  }

  function onSquadLeave()
  {
    if (!::g_squad_manager.isInSquad())
      return

    this.msgBox("leave_squad", loc("squad/ask/leave"),
      [
        ["yes", function() {
          ::g_squad_manager.leaveSquad()
        }],
        ["no", function() {} ]
      ], "yes",
      { cancel_fn = function() {} })
  }

  function onSquadMemberMenu(obj)
  {
    ::g_squad_utils.showMemberMenu(obj)
  }

  function updateVisibleNewApplications()
  {
    let objGlow = this.scene.findObject("iconGlow")
    if (checkObj(objGlow))
      objGlow.wink = (::gui_handlers.squadInviteListWnd.canOpen() &&
        ::g_squad_manager.hasNewApplication) ? "yes" : "no"
  }

  /**event handlers**/
  function onEventSquadHasNewApplications(_params)
  {
    this.doWhenActiveOnce("updateVisibleNewApplications")
  }

  function onEventSquadSetReady(_params)
  {
    this.doWhenActiveOnce("updateView")
  }

  function onEventSquadDataUpdated(_params)
  {
    this.doWhenActiveOnce("updateView")
  }

  function onEventMyStatsUpdated(_params)
  {
    this.doWhenActiveOnce("updateView")
  }

  function onEventSquadStatusChanged(_params)
  {
    this.doWhenActiveOnce("updateVisibles")
  }

  function onEventQueueChangeState(_params)
  {
    this.doWhenActiveOnce("updateVisibles")
  }

  function onEventVoiceChatStatusUpdated(params)
  {
    let uid = getTblValue("uid", params, "")
    if (::g_squad_manager.getMemberData(uid) == null)
      return

    this.doWhenActiveOnce("updateView")
  }

  function onEventVoiceChatOptionUpdated(_p)
  {
    this.doWhenActiveOnce("updateView")
  }

  function checkActiveForDelayedAction()
  {
    return this.isSceneActive()
  }

  function onWorldWar() {
    let squadLeaderOperationId = getSquadLeaderOperation()?.id
    if (squadLeaderOperationId == null || squadLeaderOperationId == ::ww_get_operation_id())
      return

    this.guiScene.performDelayed(this, @()::g_world_war.joinOperationById(squadLeaderOperationId))
  }
}
