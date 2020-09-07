local u = require("sqStdLibs/helpers/u.nut")
local platformModule = require("scripts/clientState/platform.nut")
local localDevoice = require("scripts/penitentiary/localDevoice.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local { isChatEnabled, attemptShowOverlayMessage,
  isCrossNetworkMessageAllowed } = require("scripts/chat/chatStates.nut")

//-----------------------------
// params keys:
//  - uid
//  - playerName
//  - clanTag
//  - roomId
//  - isMPChat
//  - canInviteToChatRoom
//  - isMPLobby
//  - clanData
//  - chatLog
//  - squadMemberData
//  - position
//  - canComplain
// ----------------------------

local verifyContact = function(params)
{
  local name = params?.playerName
  local newContact = ::getContact(params?.uid, name, params?.clanTag)
  if (!newContact && name)
    newContact = ::Contact.getByName(name)

  return newContact
}

local getPlayerCardInfoTable = function(uid, name)
{
  local info = {}
  if (uid)
   info.uid <- uid
  if (name)
   info.name <- name

  return info
}

local showLiveCommunicationsRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableLiveCommunications"))
local showCrossNetworkPlayRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkPlay"))
local showCrossNetworkCommunicationsRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkCommunications"))
local showNotAvailableActionPopup = @() ::g_popups.add(null, ::loc("xbox/actionNotAvailableDiffPlatform"))
local showBlockedPlayerPopup = @(playerName) ::g_popups.add(null, ::loc("chat/player_blocked", {playerName = platformModule.getPlayerName(playerName)}))
local showNoInviteForDiffPlatformPopup = @() ::g_popups.add(null, ::loc("msg/squad/noPlayersForDiffConsoles"))
local showXboxPlayerMuted = @(playerName) ::g_popups.add(null, ::loc("popup/playerMuted", {playerName = platformModule.getPlayerName(playerName)}))

local notifyPlayerAboutRestriction = function(contact, isInvite = false)
{
  local isCrossNetworkMessagesAllowed = isCrossNetworkMessageAllowed(contact.name)
  local isXBoxOnePlayer = platformModule.isPlayerFromXboxOne(contact.name)
  if (::is_platform_xboxone)
  {
    attemptShowOverlayMessage(contact.name, isInvite)
    //There is no system level error message, added custom.
    if (contact.getInteractionStatus() == XBOX_COMMUNICATIONS_BLOCKED && !contact.isInFriendGroup())
      showLiveCommunicationsRestrictionMsgBox()
    else if (!isXBoxOnePlayer && !isCrossNetworkMessagesAllowed) // It is not included in interactionStatus
      showCrossNetworkCommunicationsRestrictionMsgBox()
    return
  }

  if (!isCrossNetworkMessagesAllowed)
    showCrossNetworkCommunicationsRestrictionMsgBox()
  else
    showLiveCommunicationsRestrictionMsgBox()
}

local getActions = function(contact, params)
{
  local uid = contact.uid
  local uidInt64 = contact.uidInt64
  local name = contact.name
  local clanTag = contact.clanTag
  local isMe = contact.isMe()
  local isFriend = contact.isInFriendGroup()
  local isBlock = contact.isInBlockGroup()

  local isXBoxOnePlayer = platformModule.isPlayerFromXboxOne(name)
  local isPS4Player = platformModule.isPlayerFromPS4(name)

  local canChat = contact.canChat()
  local canInvite = contact.canInvite()
  local isProfileMuted = contact.isMuted()
  local canInteractCrossConsole = platformModule.canInteractCrossConsole(name)
  local canInteractCrossPlatform = isPS4Player || isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
  local showCrossPlayIcon = canInteractCrossConsole && crossplayModule.needShowCrossPlayInfo() && (!isXBoxOnePlayer || !isPS4Player)
  local hasChat = isChatEnabled()

  local roomId = params?.roomId
  local roomData = roomId? ::g_chat.getRoomById(roomId) : null

  local isMPChat = params?.isMPChat ?? false
  local isMPLobby = params?.isMPLobby ?? false
  local canInviteToChatRoom = params?.canInviteToChatRoom ?? true

  local chatLog = params?.chatLog ?? roomData?.getLogForBanhammer() ?? null
  local canInviteToSesson = isXBoxOnePlayer == ::is_platform_xboxone

  local actions = []
//---- <Session Join> ---------
  actions.append({
    text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("multiplayer/invite_to_session"))
    show = canInviteToChatRoom && ::SessionLobby.canInvitePlayer(uid) && canInviteToSesson
    isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
    action = function () {
      if (!canInteractCrossConsole)
        return showNotAvailableActionPopup()
      if (!canInteractCrossPlatform)
        return showCrossNetworkPlayRestrictionMsgBox()

      if (::isPlayerPS4Friend(name))
        ::g_psn_sessions.invite(::SessionLobby.getExternalId(), ::get_psn_account_id(name))
      ::SessionLobby.invitePlayer(uid)
    }
  })

  if (contact.inGameEx && contact.online && ::isInMenu())
  {
    local eventId = contact.gameConfig?.eventId
    local event = ::events.getEvent(eventId)
    if (event && ::events.isEnableFriendsJoin(event))
    {
      actions.append({
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("contacts/join_team"))
        show = canInviteToSesson
        isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossNetworkPlayRestrictionMsgBox()
          else
            ::queues.joinFriendsQueue(contact.inGameEx, eventId)
        }
      })
    }
  }
//---- </Session Join> ---------

//---- <Common> ----------------
  actions.append(
    {
      text = ::loc("contacts/message")
      show = !isMe && ::ps4_is_chat_enabled() && ::has_feature("Chat") && !u.isEmpty(name)
      isVisualDisabled = !canChat || isBlock || isProfileMuted
      action = function() {
        if (isBlock)
          return showBlockedPlayerPopup(name)

        if (isProfileMuted) //There was no xbox message, so don't try to call overlay msg
          return showXboxPlayerMuted(name)

        if (!canChat)
          return notifyPlayerAboutRestriction(contact)

        ::openChatPrivate(name)
      }
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      show = ::has_feature("UserCards") && getPlayerCardInfoTable(uid, name).len() > 0
      action = @() ::gui_modal_userCard(getPlayerCardInfoTable(uid, name))
    }
    {
      text = ::loc("mainmenu/btnClanCard")
      show = ::has_feature("Clans") && !u.isEmpty(clanTag) && clanTag != ::clan_get_my_clan_tag()
      action = @() ::showClanPage("", "", clanTag)
    }
  )
//---- </Common> ------------------

//---- <Squad> --------------------
  if (::has_feature("Squad"))
  {
    local meLeader = ::g_squad_manager.isSquadLeader()
    local inMySquad = ::g_squad_manager.isInMySquad(name, false)
    local squadMemberData = params?.squadMemberData
    local hasApplicationInMySquad = ::g_squad_manager.hasApplicationInMySquad(uidInt64, name)
    local canInviteDiffConsole = ::g_squad_manager.canInviteMemberByPlatform(name)

    actions.append(
      {
        text = ::loc("squadAction/openChat")
        show = !isMe && ::g_chat.isSquadRoomJoined() && inMySquad && hasChat
        action = @() ::g_chat.openChatRoom(::g_chat.getMySquadRoomId())
      }
      {
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, hasApplicationInMySquad
            ? ::loc("squad/accept_membership")
            : ::loc("squad/invite_player")
          )
        isVisualDisabled = !canInvite || !canInteractCrossConsole || !canInteractCrossPlatform || !canInviteDiffConsole
        show = ::has_feature("SquadInviteIngame")
               && canInviteToChatRoom
               && !isMe
               && !isBlock
               && ::g_squad_manager.canInviteMember(uid)
               && !::g_squad_manager.isPlayerInvited(uid, name)
               && !squadMemberData?.isApplication
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossNetworkPlayRestrictionMsgBox()
          else if (!canInvite)
            notifyPlayerAboutRestriction(contact, true)
          else if (!canInviteDiffConsole)
            showNoInviteForDiffPlatformPopup()
          else if (hasApplicationInMySquad)
            ::g_squad_manager.acceptMembershipAplication(uidInt64)
          else
            ::g_squad_manager.inviteToSquad(uid, name)
        }
      }
      {
        text = ::loc("squad/revoke_invite")
        show = squadMemberData && meLeader && squadMemberData?.isInvite
        action = @() ::g_squad_manager.revokeSquadInvite(uid)
      }
      {
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("squad/accept_membership"))
        isVisualDisabled = !canInvite || !canInteractCrossConsole || !canInteractCrossPlatform || !canInviteDiffConsole
        show = squadMemberData && meLeader && squadMemberData?.isApplication
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossNetworkPlayRestrictionMsgBox()
          else if (!canInvite)
            notifyPlayerAboutRestriction(contact, true)
          else if (!canInviteDiffConsole)
            showNoInviteForDiffPlatformPopup()
          else
            ::g_squad_manager.acceptMembershipAplication(uidInt64)
        }
      }
      {
        text = ::loc("squad/deny_membership")
        show = squadMemberData && meLeader && squadMemberData?.isApplication
        action = @() ::g_squad_manager.denyMembershipAplication(uidInt64,
          @(response) ::g_squad_manager.removeApplication(uidInt64))
      }
      {
        text = ::loc("squad/remove_player")
        show = ::g_squad_manager.canDismissMember(uid)
        action = @() ::g_squad_manager.dismissFromSquad(uid)
      }
      {
        text = ::loc("squad/tranfer_leadership")
        show = !isMe && ::g_squad_manager.canTransferLeadership(uid)
        action = @() ::g_squad_manager.transferLeadership(uid)
      }
    )
  }
//---- </Squad> -------------------

//---- <XBox Specific> ------------
  if (::is_platform_xboxone && isXBoxOnePlayer)
  {
    local isXboxPlayerMuted = contact.isXboxChatMuted()
    actions.append({
      text = isXboxPlayerMuted? ::loc("mainmenu/btnUnmute") : ::loc("mainmenu/btnMute")
      show = !isMe && ::xbox_is_player_in_chat(uidInt64)
      action = @() ::xbox_mute_chat_player(uidInt64, !isXboxPlayerMuted)
    })
  }
//---- </XBox Specific> -----------

//---- <Clan> ---------------------
  local clanData = params?.clanData
  if (::has_feature("Clans") && clanData)
  {
    local clanId = clanData?.id ?? "-1"
    local myClanId = ::clan_get_my_clan_id()
    local isMyClan = myClanId != "-1" && clanId == myClanId

    local myClanRights = isMyClan? ::g_clans.getMyClanRights() : []
    local isMyRankHigher = ::g_clans.getClanMemberRank(clanData, name) < ::clan_get_role_rank(::clan_get_my_role())
    local isClanAdmin = ::clan_get_admin_editor_mode()

    actions.append(
      {
        text = ::loc("clan/activity")
        show = ::has_feature("ClanActivity")
        action = @() ::gui_start_clan_activity_wnd(uid, clanData)
      }
      {
        text = ::loc("clan/btnChangeRole")
        show = (isMyClan
                && ::isInArray("MEMBER_ROLE_CHANGE", myClanRights)
                && ::g_clans.haveRankToChangeRoles(clanData)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() ::gui_start_change_role_wnd(contact, clanData)
      }
      {
        text = ::loc("clan/btnDismissMember")
        show = (!isMe
                && isMyClan
                && ::isInArray("MEMBER_DISMISS", myClanRights)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() ::g_clans.dismissMember(contact, clanData)
      }
    )
  }
//---- </Clan> ---------------------

//---- <Contacts> ------------------
  if (::has_feature("Friends"))
  {
    local canBlock = !platformModule.isPlatformXboxOne || !isXBoxOnePlayer
    local canRemoveFromList = !platformModule.isPlatformSony || !isPS4Player

    actions.append(
      {
        text = ::loc("contacts/friendlist/add")
        show = !isMe && !isFriend && !isBlock
        isVisualDisabled = !canInteractCrossConsole
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else
            ::editContactMsgBox(contact, ::EPL_FRIENDLIST, true)
        }
      }
      {
        text = ::loc("contacts/friendlist/remove")
        show = isFriend && canRemoveFromList
        action = @() ::editContactMsgBox(contact, ::EPL_FRIENDLIST, false)
      }
      {
        text = ::loc("contacts/facebooklist/remove")
        show = params?.curContactGroup == ::EPL_FACEBOOK && ::isPlayerInContacts(uid, ::EPL_FACEBOOK)
        action = @() ::editContactMsgBox(contact, ::EPL_FACEBOOK, false)
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock && canBlock
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, true)
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock && canBlock && canRemoveFromList
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, false)
      }
    )
  }
//---- </Contacts> ------------------

//---- <MP Lobby> -------------------
  if (isMPLobby)
    actions.append({
      text = ::loc("mainmenu/btnKick")
      show = !isMe && ::SessionLobby.isRoomOwner && !::SessionLobby.isEventRoom
      action = @() ::SessionLobby.kickPlayer(::SessionLobby.getMemberByName(name))
    })
//---- </MP Lobby> ------------------

//---- <In Battle> ------------------
  if (::is_in_flight())
    actions.append({
      text = ::loc(localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/enable" : "mpRadio/disable")
      show = !isMe && !isBlock
      action = function() {
        localDevoice.switchMuted(name, localDevoice.DEVOICE_RADIO)
        local popupLocId = localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/disabled/msg" : "mpRadio/enabled/msg"
        ::g_popups.add(null, ::loc(popupLocId, { player = ::colorize("activeTextColor", platformModule.getPlayerName(name)) }))
      }
    })
//---- </In Battle> -----------------

//---- <Chat> -----------------------
  if (::has_feature("Chat"))
  {
    if (hasChat && canInviteToChatRoom)
    {
      local inviteMenu = ::g_chat.generateInviteMenu(name)
      actions.append({
        text = ::loc("chat/invite_to_room")
        isVisualDisabled = !canChat || !canInteractCrossConsole || !canInteractCrossPlatform || isProfileMuted || isBlock
        show = inviteMenu && inviteMenu.len() > 0
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossNetworkCommunicationsRestrictionMsgBox()
          else if (isProfileMuted)
            showXboxPlayerMuted(name)
          else if (!canChat)
            notifyPlayerAboutRestriction(contact, true)
          else if (isBlock)
            showBlockedPlayerPopup(name)
          else
            ::open_invite_menu(inviteMenu, params?.position)
        }
      })
    }

    if (roomData)
      actions.append(
        {
          text = ::loc("chat/kick_from_room")
          show = !::g_chat.isRoomSquad(roomId) && !::SessionLobby.isLobbyRoom(roomId) && ::g_chat.isImRoomOwner(roomData)
          action = @() ::menu_chat_handler ? ::menu_chat_handler.kickPlayeFromRoom(name) : null
        }
        {
          text = ::loc("contacts/copyNickToEditbox")
          show = !isMe && ::show_console_buttons && ::menu_chat_handler
          action = @() ::menu_chat_handler ? ::menu_chat_handler.addNickToEdit(name) : null
        }
      )

    local canComplain = !isMe && (params?.canComplain ?? false)
    if (!isMe)
    {
      if (roomData) {
        for (local i = 0; i < roomData.mBlocks.len(); i++) {
          if (roomData.mBlocks[i].from == name || roomData.mBlocks[i].uid == uid) {
            canComplain = true
            break
          }
        }
      } else {
        local threadInfo = ::g_chat.getThreadInfo(roomId)
        if (threadInfo && threadInfo.ownerNick == name)
          canComplain = true
      }
    }

    if (canComplain)
      actions.append({
        text = ::loc("mainmenu/btnComplain")
        action = function() {
          local config = {
            userId = uid,
            name = name,
            clanTag = clanTag,
            roomId = roomId,
            roomName = roomData ? roomData.getRoomName() : ""
          }

          if (!isMPChat)
          {
            local threadInfo = ::g_chat.getThreadInfo(roomId)
            if (threadInfo) {
              chatLog = chatLog != null ? chatLog : {}
              chatLog.category   <- threadInfo.category
              chatLog.title      <- threadInfo.title
              chatLog.ownerUid   <- threadInfo.ownerUid
              chatLog.ownerNick  <- threadInfo.ownerNick
              if (!roomData)
                config.roomName = ::g_chat_room_type.THREAD.getRoomName(roomId)
            }
          }

          ::gui_modal_complain(config, chatLog)
        }
      })
  }
//---- </Chat> ----------------------

//---- <Moderator> ------------------
  if (::is_myself_anyof_moderators() && (roomId || isMPChat || isMPLobby))
    actions.append(
      {
        text = ::loc("contacts/moderator_copyname")
        action = @() ::copy_to_clipboard(platformModule.getPlayerName(name))
        hasSeparator = true
      }
      {
        text = ::loc("contacts/moderator_ban")
        show = ::myself_can_devoice() || ::myself_can_ban()
        action = @() ::gui_modal_ban(contact, chatLog)
      }
    )
//---- </Moderator> -----------------

  local buttons = params?.extendButtons ?? []
  buttons.extend(actions)
  return buttons
}

local showMenu = function(_contact, handler, params = {})
{
  local contact = _contact || verifyContact(params)
  local showMenu = ::callee()
  if (contact && contact.needCheckXboxId())
    return contact.getXboxId(@() showMenu(contact, handler, params))

  if (!contact && params?.playerName)
    return ::find_contact_by_name_and_do(params.playerName, @(c) c && showMenu(c, handler, params))

  local menu = getActions(contact, params)
  ::gui_right_click_menu(menu, handler, params?.position, params?.orientation)
}

return {
  getActions = getActions
  showMenu = showMenu
  showXboxPlayerMuted = showXboxPlayerMuted
  notifyPlayerAboutRestriction = notifyPlayerAboutRestriction
}
