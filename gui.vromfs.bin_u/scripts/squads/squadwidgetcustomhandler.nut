local platformModule = require("scripts/clientState/platform.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local { chatStatesCanUseVoice } = require("scripts/chat/chatStates.nut")

const SQUAD_MEMBERS_TO_HIDE_TITLE = 3

::init_squad_widget_handler <- function init_squad_widget_handler(nestObj)
{
  if (!::has_feature("Squad") || !::has_feature("SquadWidget") || !::checkObj(nestObj))
    return null
  return ::handlersManager.loadCustomHandler(::gui_handlers.SquadWidgetCustomHandler, { scene = nestObj })
}

class ::gui_handlers.SquadWidgetCustomHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/squads/squadWidget"

  squadStateToString = {
    [squadMemberState.SQUAD_LEADER] = "leader",
    [squadMemberState.SQUAD_MEMBER] = "notReady",
    [squadMemberState.SQUAD_MEMBER_READY] = "ready",
    [squadMemberState.SQUAD_MEMBER_OFFLINE] = "offline",
  }

  function getSceneTplView()
  {
    local readyText = ::loc("mainmenu/btnReady")
    local notReadyText = ::loc("multiplayer/btnNotReady")
    local readyTextWidth = daguiFonts.getStringWidthPx(readyText, "fontNormal", guiScene)
    local notReadyTextWidth = daguiFonts.getStringWidthPx(notReadyText, "fontNormal", guiScene)
    local view = {
      readyBtnHiddenText = readyTextWidth > notReadyTextWidth ? readyText : notReadyText
      members = []
    }

    local showCrossplayIcon = crossplayModule.needShowCrossPlayInfo()
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
    local leader = ::g_squad_manager.getSquadLeaderData()
    updateMemberView(0, leader)
    local memberViewIndex = 1
    local members = ::g_squad_manager.getMembers()
    foreach(uid, member in members)
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
    local indexStr = mebmerObjIndex.tostring()
    local isVisible = member != null
    local memberObj = showSceneBtn("member_" + indexStr, isVisible)
    if (!isVisible || !::checkObj(memberObj))
      return

    showSceneBtn("member_waiting_" + indexStr, !member.isActualData())
    showSceneBtn("member_state_block_" + indexStr, member.isActualData())

    memberObj["uid"] = member.uid
    memberObj["isMe"] = member.isMe()? "yes" : "no"
    memberObj.setUserData(member)
    memberObj.findObject("member_icon_" + indexStr).setValue(member.pilotIcon)
    memberObj.findObject("member_tooltip_" + indexStr)["uid"] = member.uid

    if (member.isActualData())
    {
      local contact = ::getContact(member.uid)
      local countryIcon = ""
      if (checkCountry(member.country, "squad member data ( uid = " + member.uid + ")", true))
        countryIcon = ::get_country_icon(member.country)

      local status = ::g_squad_manager.getPlayerStatusInMySquad(member.uid)
      memberObj["status"] = ::getTblValue(status, squadStateToString, "")
      memberObj.findObject("member_country_" + indexStr)["background-image"] = countryIcon

      local memberVoipObj = memberObj.findObject("member_voip_" + indexStr)
      memberVoipObj["isVoipActive"] = contact.voiceStatus == voiceChatStats.talking ? "yes" : "no"
      local needShowVoice = chatStatesCanUseVoice()
        && ::get_option_voicechat()
        && !platformModule.isXBoxPlayerName(member.name)
      memberVoipObj.show(needShowVoice)

      local memberCrossPlayObj = memberObj.findObject("member_crossplay_active_" + indexStr)
      memberCrossPlayObj["isEnabledCrossPlay"] = member.crossplay ? "yes" : "no"

      local speakingMemberNickTextObj = memberObj.findObject("speaking_member_nick_text_" + indexStr)
      speakingMemberNickTextObj.setValue(platformModule.getPlayerName(member.name))
    }
  }

  function updateVisibles()
  {
    local canInvite = ::g_squad_manager.canInviteMember()
    local isInTransition = ::g_squad_manager.isStateInTransition()

    local plusButtonObj = showSceneBtn("btn_squadPlus", canInvite)
    if (plusButtonObj && canInvite)
      plusButtonObj.enable(::ps4_is_ugc_enabled() && ::ps4_is_chat_enabled())

    showSceneBtn("wait_icon", isInTransition)

    showSceneBtn("txt_squad_title", ::g_squad_manager.canManageSquad()
      && ::g_squad_manager.getMembers().len() < SQUAD_MEMBERS_TO_HIDE_TITLE)
    local btnSquadReady = showSceneBtn("btn_squad_ready", ::g_squad_manager.canSwitchReadyness())
    btnSquadReady.findObject("text").setValue(
      ::loc(::g_squad_manager.isMeReady() ? "multiplayer/btnNotReady" : "mainmenu/btnReady"))

    showSceneBtn("btn_squadInvites", ::gui_handlers.squadInviteListWnd.canOpen())
    updateVisibleNewApplications()

    local btnSquadLeave = showSceneBtn("btn_squadLeave", ::g_squad_manager.canLeaveSquad())
    btnSquadLeave.tooltip = ::loc("squadAction/leave")

    scene.show(isInTransition || canInvite || ::g_squad_manager.isInSquad())
  }

  function canShowContactTooltip(contact)
  {
    return contact != null
  }

  function onSquadPlus()
  {
    if (::is_platform_xbox && !::has_feature("SquadInviteIngame"))
    {
      ::xbox_show_invite_window()
      return
    }

    ::open_search_squad_player()
  }

  function onSquadReady()
  {
    ::g_squad_manager.setReadyFlag()
  }

  function onSquadInvitesClick(obj)
  {
    if (::checkObj(obj))
      ::gui_handlers.squadInviteListWnd.open(obj.findObject("invite_widget"))
  }

  function onSquadLeave()
  {
    if (!::g_squad_manager.isInSquad())
      return

    msgBox("leave_squad", ::loc("squad/ask/leave"),
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
    local objGlow = scene.findObject("iconGlow")
    if (::check_obj(objGlow))
      objGlow.wink = (::gui_handlers.squadInviteListWnd.canOpen() &&
        ::g_squad_manager.hasNewApplication) ? "yes" : "no"
  }

  /**event handlers**/
  function onEventSquadHasNewApplications(params)
  {
    doWhenActiveOnce("updateVisibleNewApplications")
  }

  function onEventSquadSetReady(params)
  {
    doWhenActiveOnce("updateView")
  }

  function onEventSquadDataUpdated(params)
  {
    doWhenActiveOnce("updateView")
  }

  function onEventMyStatsUpdated(params)
  {
    doWhenActiveOnce("updateView")
  }

  function onEventSquadStatusChanged(params)
  {
    doWhenActiveOnce("updateVisibles")
  }

  function onEventQueueChangeState(params)
  {
    doWhenActiveOnce("updateVisibles")
  }

  function onEventVoiceChatStatusUpdated(params)
  {
    local uid = ::getTblValue("uid", params, "")
    if (::g_squad_manager.getMemberData(uid) == null)
      return

    doWhenActiveOnce("updateView")
  }

  function onEventVoiceChatOptionUpdated(p)
  {
    doWhenActiveOnce("updateView")
  }

  function checkActiveForDelayedAction()
  {
    return isSceneActive()
  }
}
