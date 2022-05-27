let u = require("%sqStdLibs/helpers/u.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let localDevoice = require("%scripts/penitentiary/localDevoice.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isChatEnabled, attemptShowOverlayMessage,
  isCrossNetworkMessageAllowed } = require("%scripts/chat/chatStates.nut")
let { updateContactsStatusByContacts } = require("%scripts/contacts/updateContactsStatus.nut")
let { verifyContact } = require("%scripts/contacts/contactsManager.nut")

let { invite } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")

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

let getPlayerCardInfoTable = function(uid, name)
{
  let info = {}
  if (uid)
   info.uid <- uid
  if (name)
   info.name <- name

  return info
}

let showLiveCommunicationsRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableLiveCommunications"))
let showCrossNetworkPlayRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkPlay"))
let showCrossNetworkCommunicationsRestrictionMsgBox = @() ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkCommunications"))
let showNotAvailableActionPopup = @() ::g_popups.add(null, ::loc("xbox/actionNotAvailableDiffPlatform"))
let showBlockedPlayerPopup = @(playerName) ::g_popups.add(null, ::loc("chat/player_blocked", {playerName = platformModule.getPlayerName(playerName)}))
let showNoInviteForDiffPlatformPopup = @() ::g_popups.add(null, ::loc("msg/squad/noPlayersForDiffConsoles"))
let showXboxPlayerMuted = @(playerName) ::g_popups.add(null, ::loc("popup/playerMuted", {playerName = platformModule.getPlayerName(playerName)}))

let notifyPlayerAboutRestriction = function(contact, isInvite = false)
{
  let isCrossNetworkMessagesAllowed = isCrossNetworkMessageAllowed(contact.name)
  let isXBoxOnePlayer = platformModule.isPlayerFromXboxOne(contact.name)
  if (::is_platform_xbox)
  {
    attemptShowOverlayMessage(contact.name, isInvite)
    //There is no system level error message, added custom.
    if (contact.getInteractionStatus() == XBOX_COMMUNICATIONS_BLOCKED && !contact.isInFriendGroup())
      showLiveCommunicationsRestrictionMsgBox()
    else if (!isXBoxOnePlayer && !isCrossNetworkMessagesAllowed) // It is not included in interactionStatus
      showCrossNetworkCommunicationsRestrictionMsgBox()
    return
  }

  if (contact.isBlockedMe)
    return

  if (!isCrossNetworkMessagesAllowed)
    showCrossNetworkCommunicationsRestrictionMsgBox()
  else
    showLiveCommunicationsRestrictionMsgBox()
}

let getActions = function(contact, params)
{
  let uid = contact.uid
  let uidInt64 = contact.uidInt64
  let name = contact.name
  let clanTag = contact.clanTag
  let isMe = contact.isMe()
  let isFriend = contact.isInFriendGroup()
  let isBlock = contact.isInBlockGroup()

  let isXBoxOnePlayer = platformModule.isPlayerFromXboxOne(name)
  let isPS4Player = platformModule.isPlayerFromPS4(name)

  let canChat = contact.canChat()
  let canInvite = contact.canInvite()
  let isProfileMuted = contact.isMuted()
  let canInteractCrossConsole = platformModule.canInteractCrossConsole(name)
  let canInteractCrossPlatform = isPS4Player || isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
  let showCrossPlayIcon = canInteractCrossConsole && crossplayModule.needShowCrossPlayInfo() && (!isXBoxOnePlayer || !isPS4Player)
  let hasChat = isChatEnabled()

  let roomId = params?.roomId
  let roomData = roomId? ::g_chat.getRoomById(roomId) : null

  let isMPChat = params?.isMPChat ?? false
  let isMPLobby = params?.isMPLobby ?? false
  let canInviteToChatRoom = params?.canInviteToChatRoom ?? true

  local chatLog = params?.chatLog ?? roomData?.getLogForBanhammer()
  let isInPsnBlockList = platformModule.isPlatformSony && contact.isInBlockGroup()
  let canInviteToSesson = (isXBoxOnePlayer == ::is_platform_xbox) && !isInPsnBlockList

  local canComplain = !isMe && (params?.canComplain ?? false)

  let actions = []
//---- <Session Join> ---------
  actions.append({
    text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("multiplayer/invite_to_session"))
    show = canInviteToChatRoom && ::SessionLobby.canInvitePlayer(uid) && canInviteToSesson
    isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
    action = function () {
      if (!canInteractCrossConsole)
        return showNotAvailableActionPopup()
      if (!canInteractCrossPlatform) {
        if (!::xbox_try_show_crossnetwork_message())
          showCrossNetworkPlayRestrictionMsgBox()
        return
      }

      if (isPS4Player && !u.isEmpty(::SessionLobby.getExternalId()))
        contact.updatePSNIdAndDo(@() invite(
          ::SessionLobby.getExternalId(),
          contact.psnId
        ))

      ::SessionLobby.invitePlayer(uid)
    }
  })

  if (contact.inGameEx && contact.online && ::isInMenu())
  {
    let eventId = contact.gameConfig?.eventId
    let event = ::events.getEvent(eventId)
    if (event && ::events.isEnableFriendsJoin(event))
    {
      actions.append({
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("contacts/join_team"))
        show = canInviteToSesson
        isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform) {
            if (!::xbox_try_show_crossnetwork_message())
              showCrossNetworkPlayRestrictionMsgBox()
            return
          }
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
      text = ::loc("mainmenu/btnPsnProfile")
      show = !isMe && contact.canOpenPSNActionWindow()
      action = @() contact.openPSNProfile()
    }
    {
      text = ::loc("mainmenu/btnXboxProfile")
      show = isXBoxOnePlayer && !isMe
      action = @() contact.openXboxProfile()
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
    let meLeader = ::g_squad_manager.isSquadLeader()
    let inMySquad = ::g_squad_manager.isInMySquad(name, false)
    let squadMemberData = params?.squadMemberData
    let hasApplicationInMySquad = ::g_squad_manager.hasApplicationInMySquad(uidInt64, name)
    let canInviteDiffConsole = ::g_squad_manager.canInviteMemberByPlatform(name)

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
          else if (!canInteractCrossPlatform) {
            if (!::xbox_try_show_crossnetwork_message())
              showCrossNetworkPlayRestrictionMsgBox()
            return
          }
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
          else if (!canInteractCrossPlatform) {
            if (!::xbox_try_show_crossnetwork_message())
              showCrossNetworkPlayRestrictionMsgBox()
            return
          }
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
  if (::is_platform_xbox && isXBoxOnePlayer)
  {
    let isXboxPlayerMuted = contact.isXboxChatMuted()
    actions.append({
      text = isXboxPlayerMuted? ::loc("mainmenu/btnUnmute") : ::loc("mainmenu/btnMute")
      show = !isMe && ::xbox_is_player_in_chat(uidInt64)
      action = @() ::xbox_mute_chat_player(uidInt64, !isXboxPlayerMuted)
    })
  }
//---- </XBox Specific> -----------

//---- <Clan> ---------------------
  let clanData = params?.clanData
  if (::has_feature("Clans") && clanData)
  {
    let clanId = clanData?.id ?? "-1"
    let myClanId = ::clan_get_my_clan_id()
    let isMyClan = myClanId != "-1" && clanId == myClanId

    let myClanRights = isMyClan? ::g_clans.getMyClanRights() : []
    let isMyRankHigher = ::g_clans.getClanMemberRank(clanData, name) < ::clan_get_role_rank(::clan_get_my_role())
    let isClanAdmin = ::clan_get_admin_editor_mode()

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
    let canBlock = !platformModule.isPlatformXboxOne || !isXBoxOnePlayer

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
        show = isFriend && contact.isInFriendGroup()
        action = @() ::editContactMsgBox(contact, ::EPL_FRIENDLIST, false)
      }
      {
        text = ::loc("contacts/psn/friends/request")
        show = !isMe && isPS4Player && !isBlock && !contact.isInPSNFriends()
        action = @() contact.sendPsnFriendRequest(::EPL_FRIENDLIST)
      }
      {
        text = ::loc("contacts/facebooklist/remove")
        show = params?.curContactGroup == ::EPL_FACEBOOK && ::isPlayerInContacts(uid, ::EPL_FACEBOOK)
        action = @() ::editContactMsgBox(contact, ::EPL_FACEBOOK, false)
      }
      {
        text = ::loc("contacts/steamlist/remove")
        show = params?.curContactGroup == ::EPL_STEAM && ::isPlayerInContacts(uid, ::EPL_STEAM)
        action = @() ::editContactMsgBox(contact, ::EPL_STEAM, false)
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock && canBlock && !isPS4Player
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, true)
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock && canBlock && (!isPS4Player || (isPS4Player && contact.isInPSNFriends()))
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, false)
      }
      {
        text = ::loc("contacts/psn/blacklist/request")
        show = !isMe && isPS4Player && !isBlock
        action = @() contact.sendPsnFriendRequest(::EPL_BLOCKLIST)
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
        let popupLocId = localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/disabled/msg" : "mpRadio/enabled/msg"
        ::g_popups.add(null, ::loc(popupLocId, { player = ::colorize("activeTextColor", platformModule.getPlayerName(name)) }))
      }
    })
//---- </In Battle> -----------------

//---- <Chat> -----------------------
  if (::has_feature("Chat"))
  {
    if (hasChat && canInviteToChatRoom)
    {
      let inviteMenu = ::g_chat.generateInviteMenu(name)
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
        let threadInfo = ::g_chat.getThreadInfo(roomId)
        if (threadInfo && threadInfo.ownerNick == name)
          canComplain = true
      }
    }
  }
//---- </Chat> ----------------------

//---- <Complain> ------------------
  if (canComplain)
    actions.append({
      text = ::loc("mainmenu/btnComplain")
      action = function() {
        let config = {
          userId = uid,
          name = name,
          clanTag = clanTag,
          roomId = roomId,
          roomName = roomData ? roomData.getRoomName() : ""
        }

        if (!isMPChat)
        {
          let threadInfo = ::g_chat.getThreadInfo(roomId)
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
//---- </Complain> ------------------

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

  let buttons = params?.extendButtons ?? []
  buttons.extend(actions)
  return buttons
}

let showMenu = function(v_contact, handler, params = {})
{
  let contact = v_contact || verifyContact(params)
  let showMenu = ::callee()
  if (contact && contact.needCheckXboxId())
    return contact.getXboxId(@() showMenu(contact, handler, params))

  if (!contact && params?.playerName)
    return ::find_contact_by_name_and_do(params.playerName, @(c) c && showMenu(c, handler, params))

  updateContactsStatusByContacts([contact], ::Callback(function() {
    let menu = getActions(contact, params)
    ::gui_right_click_menu(menu, handler, params?.position, params?.orientation, params?.onClose)
  }, this))
}

return {
  getActions = getActions
  showMenu = showMenu
  showXboxPlayerMuted = showXboxPlayerMuted
  notifyPlayerAboutRestriction = notifyPlayerAboutRestriction
}
