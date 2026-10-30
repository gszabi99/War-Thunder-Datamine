from "%appGlobals/clientState/platform.nut" import isPlayerFromXboxOne, isPlayerFromPS4
from "%sqstd/platform.nut" import isSony, isXbox
import "%scripts/penitentiary/localDevoice.nut" as localDevoice
from "%scripts/social/crossplay.nut" import isCrossPlayEnabled, needShowCrossPlayInfo, getTextWithCrossplayIcon,
  canInteractCrossConsole
import "%scripts/clans/showClanPageModal.nut" as showClanPageModal
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/events/eventsManager.nut" import events
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/chat/chatStates.nut" import isChatEnabled, attemptShowOverlayMessage, hasMenuChat, isCrossNetworkMessageAllowed
from "%scripts/contacts/contactsManager.nut" import verifyContact
from "%scripts/contacts/contactsState.nut" import addContact, removeContact
from "%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut" import invite
from "%scripts/user/xboxFeatures.nut" import checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning, isMultiplayerPrivilegeAvailable
from "%scripts/user/matchingFeature.nut" import hasMenuChatPrivate
from "%scripts/user/balanceFeatures.nut" import isShowGoldBalanceWarning
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionLobbyEventRoom, isMeSessionLobbyRoomOwner, getMemberByName, getExternalSessionId
from "%scripts/events/eventInfo.nut" import isEnableFriendsJoin
from "%scripts/clans/clanChangeRoleModal.nut" import guiStartChangeRoleWnd
from "%scripts/clans/clanActivityModal.nut" import guiStartClanActivityWnd
from "%scripts/contacts/customNicknames.nut" import openNickEditBox
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/wishlist/friendsWishlistManager.nut" import tryOpenFriendWishlist
from "%scripts/globalWorldWarScripts.nut" import isWorldWarEnabled, isWwOperationInviteEnable
from "%scripts/user/complaints.nut" import checkCanComplainAndProceed
from "%scripts/chat/chatRooms.nut" import generateInviteMenu, isRoomSquad, isImRoomOwner
from "%scripts/chat/squadChatRoom.nut" import isSquadRoomJoined
from "%scripts/chat/openChat.nut" import openChatRoom, openChatPrivate
from "%scripts/globalWorldwarUtils.nut" import inviteToWwOperation
from "%scripts/contacts/contactsActions.nut" import find_contact_by_name_and_do
from "%scripts/user/userCard/userCardView.nut" import gui_modal_userCard
from "%scripts/clans/clanTextInfo.nut" import getClanMemberRank
from "%scripts/clans/clanActions.nut" import dismissMember
from "%scripts/clans/clanInfo.nut" import getMyClanRights, haveRankToChangeRoles
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import invitePlayerToSessionRoom, kickPlayerFromRoom
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import canInvitePlayerToSessionRoom
from "%scripts/queue/queueManager.nut" import joinFriendsQueue
from "%scripts/wndLib/rightClickMenu.nut" import openRightClickMenu
from "%scripts/penitentiary/banhammer.nut" import gui_modal_ban, gui_modal_complain
from "%scripts/chat/chatStorage.nut" import getRoomById, getThreadInfo
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "gameplayBinding" import isInFlight
from "%sqstd/platform.nut" import is_console, is_gdk
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_get_role_rank, myself_can_devoice, ps4_is_chat_enabled, clan_get_my_role, myself_can_ban, copy_to_clipboard
  , clan_get_my_clan_id, clan_get_admin_editor_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_myself_anyof_moderators

let { g_chat_room_type } = require("%scripts/chat/chatRoomType.nut")


















let getPlayerCardInfoTable = function(uid, name) {
  let info = {}
  if (uid)
   info.uid <- uid
  if (name)
   info.name <- name

  return info
}

let showLiveCommunicationsRestrictionMsgBox = @() showInfoMsgBox(locByVendor("xbox/actionNotAvailableLiveCommunications"))
let showCrossNetworkCommunicationsRestrictionMsgBox = @() showInfoMsgBox(locByVendor("xbox/actionNotAvailableCrossNetworkCommunications"))
let showNotAvailableActionPopup = @() addPopup(null, loc("xbox/actionNotAvailableDiffPlatform"))
let showBlockedPlayerPopup = @(playerName) addPopup(null, loc("chat/player_blocked", { playerName = getPlayerName(playerName) }))
let showNoInviteForDiffPlatformPopup = @() addPopup(null, loc("msg/squad/noPlayersForDiffConsoles"))
let showXboxPlayerMuted = @(playerName) addPopup(null, loc("popup/playerMuted", { playerName = getPlayerName(playerName) }))

function isLobbyRoom(roomId) {
  return g_chat_room_type.MP_LOBBY.checkRoomId(roomId)
}

let notifyPlayerAboutRestriction = function(contact) {
  if (is_gdk) {
    attemptShowOverlayMessage()
    return
  }

  if (contact.isBlockedMe())
    return

  if (!isCrossNetworkMessageAllowed(contact.name))
    showCrossNetworkCommunicationsRestrictionMsgBox()
  else
    showLiveCommunicationsRestrictionMsgBox()
}

let retrieveActions = function(contact, params, comms_state, callback) {
  let uid = contact.uid
  let uidInt64 = contact.uidInt64
  let name = contact.name
  let clanTag = contact.clanTag
  let isMe = contact.isMe()
  let isFriend = contact.isInFriendGroup()
  let isBlock = contact.isInBlockGroup()

  let isXBoxOnePlayer = isPlayerFromXboxOne(name)
  let isPS4Player = isPlayerFromPS4(name)

  let canChat = contact.canChat(comms_state)
  let canInvite = contact.canInvite(comms_state)
  let isProfileMuted = contact.isMuted(comms_state)
  let canInteractCrossConsoleValue = canInteractCrossConsole(name)
  let canInteractCrossPlatform = isPS4Player || isXBoxOnePlayer || isCrossPlayEnabled()
  let showCrossPlayIcon = canInteractCrossConsoleValue && needShowCrossPlayInfo() && (!isXBoxOnePlayer || !isPS4Player)
  let hasChatEnable = isChatEnabled()

  let roomId = params?.roomId
  let roomData = roomId ? getRoomById(roomId) : null

  let isMPChat = params?.isMPChat ?? false
  let isMPLobby = params?.isMPLobby ?? false
  let canInviteToChatRoom = params?.canInviteToChatRoom ?? true

  local chatLog = params?.chatLog ?? roomData?.getLogForBanhammer()
  let isInPsnBlockList = isSony && contact.isInBlockGroup()
  let canInviteToSesson = (isXBoxOnePlayer == is_gdk) && !isInPsnBlockList

  local canComplain = !isMe && (params?.canComplain ?? false)

  let actions = []

  actions.append({
    text = getTextWithCrossplayIcon(showCrossPlayIcon, loc("multiplayer/invite_to_session"))
    show = canInviteToChatRoom && canInvitePlayerToSessionRoom(uid) && canInviteToSesson
    isVisualDisabled = !canInteractCrossConsoleValue || !canInteractCrossPlatform || !canInvite
    action = function () {
      if (!canInteractCrossConsoleValue)
        return showNotAvailableActionPopup()
      if (!canInteractCrossPlatform)
        return checkAndShowCrossplayWarning()
      if (!canInvite)
        return notifyPlayerAboutRestriction(contact)

      if (isPS4Player && !u.isEmpty(getExternalSessionId()))
        contact.updatePSNIdAndDo(@() invite(
          getExternalSessionId(),
          contact.psnId
        ))

      invitePlayerToSessionRoom(uid)
    }
  })

  if (contact.inGameEx && contact.online && isInMenu.get()) {
    let eventId = contact.gameConfig?.eventId
    let event = events.getEvent(eventId)
    if (event && isEnableFriendsJoin(event)) {
      actions.append({
        text = getTextWithCrossplayIcon(showCrossPlayIcon, loc("contacts/join_team"))
        show = canInviteToSesson
        isVisualDisabled = !canInteractCrossConsoleValue || !canInteractCrossPlatform
        action = function() {
          if (!canInteractCrossConsoleValue)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            checkAndShowCrossplayWarning()
          else
            joinFriendsQueue(contact.inGameEx, eventId)
        }
      })
    }
  }



  actions.append(
    {
      text = loc("contacts/message")
      show = !isMe && ps4_is_chat_enabled() && hasMenuChat.get() && !u.isEmpty(name) && hasMenuChatPrivate.get()
      isVisualDisabled = !canChat || isBlock || isProfileMuted
      action = function() {
        if (isBlock)
          return showBlockedPlayerPopup(name)

        if (isProfileMuted) 
          return showXboxPlayerMuted(name)

        if (!canChat)
          return notifyPlayerAboutRestriction(contact)

        openChatPrivate(name)
      }
    }
    {
      text = locByVendor("mainmenu/btnProfile")
      show = getPlayerCardInfoTable(uid, name).len() > 0
      action = @() gui_modal_userCard(getPlayerCardInfoTable(uid, name))
    }
    {
      text = loc("mainmenu/btnPsnProfile")
      show = !isMe && contact.canOpenPSNActionWindow()
      action = @() contact.openPSNProfile()
    }
    {
      text = loc("mainmenu/btnXboxProfile")
      show = isXBoxOnePlayer && !isMe
      action = @() contact.openXboxProfile()
    }
    {
      text = loc("mainmenu/btnClanCard")
      show = !u.isEmpty(clanTag) && clanTag != clan_get_my_clan_tag()
      action = @() showClanPageModal("", "", clanTag)
    }
    {
      text = loc("worldwar/inviteToOperation")
      show = isWorldWarEnabled() && isWwOperationInviteEnable()
      action = @() inviteToWwOperation(contact.uid)
    }
    {
      text = loc("mainmenu/go_to_wishlist")
      show = !isMe && isFriend && hasFeature("Wishlist") && !is_console && isInMenu.get()
      action = @() tryOpenFriendWishlist(contact.uid)
    }
  )



  let meLeader = g_squad_manager.isSquadLeader()
  let inMySquad = g_squad_manager.isInMySquadById(uidInt64, false)
  let squadMemberData = params?.squadMemberData
  let hasApplicationInMySquad = g_squad_manager.hasApplicationInMySquad(uidInt64, name)
  let canInviteDiffConsole = g_squad_manager.canInviteMemberByPlatform(name)

  actions.append(
    {
      text = loc("squadAction/openChat")
      show = !isMe && isSquadRoomJoined(g_squad_manager.getSquadRoomName()) && inMySquad && hasChatEnable
      action = @() openChatRoom(g_chat_room_type.getMySquadRoomId())
    }
    {
      text = getTextWithCrossplayIcon(showCrossPlayIcon, hasApplicationInMySquad
          ? loc("squad/accept_membership")
          : loc("squad/invite_player")
        )
      isVisualDisabled = !canInvite || !canInteractCrossConsoleValue || !canInteractCrossPlatform || !canInviteDiffConsole
      show = canInviteToChatRoom
             && !isMe
             && !isBlock
             && g_squad_manager.canInviteMember(uid)
             && !g_squad_manager.isPlayerInvited(uid, name)
             && !squadMemberData?.isApplication
      action = function() {
        if (!canInteractCrossConsoleValue)
          showNotAvailableActionPopup()
        else if (!isMultiplayerPrivilegeAvailable.get())
          checkAndShowMultiplayerPrivilegeWarning()
        else if (!isShowGoldBalanceWarning() && !canInteractCrossPlatform)
          checkAndShowCrossplayWarning()
        else if (!canInvite)
          notifyPlayerAboutRestriction(contact)
        else if (!canInviteDiffConsole)
          showNoInviteForDiffPlatformPopup()
        else if (hasApplicationInMySquad)
          g_squad_manager.acceptMembershipAplication(uidInt64)
        else
          g_squad_manager.inviteToSquad(uid, name)
      }
    }
    {
      text = loc("squad/revoke_invite")
      show = squadMemberData && meLeader && squadMemberData?.isInvite
      action = @() g_squad_manager.revokeSquadInvite(uid)
    }
    {
      text = getTextWithCrossplayIcon(showCrossPlayIcon, loc("squad/accept_membership"))
      isVisualDisabled = !canInvite || !canInteractCrossConsoleValue || !canInteractCrossPlatform || !canInviteDiffConsole
      show = squadMemberData && meLeader && squadMemberData?.isApplication
      action = function() {
        if (!canInteractCrossConsoleValue)
          showNotAvailableActionPopup()
        else if (!canInteractCrossPlatform)
          checkAndShowCrossplayWarning()
        else if (!canInvite)
          notifyPlayerAboutRestriction(contact)
        else if (!canInviteDiffConsole)
          showNoInviteForDiffPlatformPopup()
        else
          g_squad_manager.acceptMembershipAplication(uidInt64)
      }
    }
    {
      text = loc("squad/deny_membership")
      show = squadMemberData && meLeader && squadMemberData?.isApplication
      action = @() g_squad_manager.denyMembershipAplication(uidInt64,
        @(_response) g_squad_manager.removeApplication(uidInt64))
    }
    {
      text = loc("squad/remove_player")
      show = g_squad_manager.canDismissMember(uid)
      action = @() g_squad_manager.dismissFromSquad(uid)
    }
    {
      text = loc("squad/tranfer_leadership")
      show = !isMe && g_squad_manager.canTransferLeadership(uid)
      action = @() g_squad_manager.transferLeadership(uid)
    }
  )



  let clanData = params?.clanData
  if (clanData) {
    let clanId = clanData?.id ?? "-1"
    let myClanId = clan_get_my_clan_id()
    let isMyClan = myClanId != "-1" && clanId == myClanId

    let myClanRights = isMyClan ? getMyClanRights() : []
    let isMyRankHigher = getClanMemberRank(clanData, name) < clan_get_role_rank(clan_get_my_role())
    let isClanAdmin = clan_get_admin_editor_mode()

    actions.append(
      {
        text = loc("clan/activity")
        action = @() guiStartClanActivityWnd(uid, clanData)
      }
      {
        text = loc("clan/btnChangeRole")
        show = (isMyClan
                && isInArray("MEMBER_ROLE_CHANGE", myClanRights)
                && haveRankToChangeRoles(clanData)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() guiStartChangeRoleWnd(contact, clanData)
      }
      {
        text = loc("clan/btnDismissMember")
        show = (!isMe
                && isMyClan
                && isInArray("MEMBER_DISMISS", myClanRights)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() dismissMember(contact, clanData)
      }
    )
  }



  let canBlock = !isXbox || !isXBoxOnePlayer

  actions.append(
    {
      text = locByVendor("contacts/friendlist/add")
      show = !isMe && !isFriend && !isBlock
      isVisualDisabled = !canInteractCrossConsoleValue
      action = function() {
        if (!canInteractCrossConsoleValue)
          showNotAvailableActionPopup()
        else
          addContact(contact, EPL_FRIENDLIST)
      }
    }
    {
      text = locByVendor("contacts/friendlist/remove")
      show = isFriend && contact.isInFriendGroup()
      action = @() removeContact(contact, EPL_FRIENDLIST)
    }
    {
      text = loc("contacts/psn/friends/request")
      show = !isMe && isPS4Player && !isBlock && !contact.isInPSNFriends()
      action = @() contact.sendPsnFriendRequest(EPL_FRIENDLIST)
    }
    {
      text = loc("contacts/blacklist/add")
      show = !isMe && !isFriend && !isBlock && canBlock && !isPS4Player
      action = @() addContact(contact, EPL_BLOCKLIST)
    }
    {
      text = loc("contacts/blacklist/remove")
      show = isBlock && canBlock && (!isPS4Player || (isPS4Player && contact.isInPSNFriends()))
      action = @() removeContact(contact, EPL_BLOCKLIST)
    }
    {
      text = loc("contacts/psn/blacklist/request")
      show = !isMe && isPS4Player && !isBlock
      action = @() contact.sendPsnFriendRequest(EPL_BLOCKLIST)
    }
    {
      text = loc("mainmenu/addCustomNick")
      show = hasFeature("CustomNicks") && !isMe
      action = @() openNickEditBox(contact)
    }
  )



  if (isMPLobby)
    actions.append({
      text = loc("mainmenu/btnKick")
      show = !isMe && isMeSessionLobbyRoomOwner.get() && !isInSessionLobbyEventRoom.get()
      action = @() kickPlayerFromRoom(getMemberByName(name))
    })



  if (isInFlight())
    actions.append({
      text = loc(localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/enable" : "mpRadio/disable")
      show = !isMe && !isBlock
      action = function() {
        localDevoice.switchMuted(name, localDevoice.DEVOICE_RADIO)
        let popupLocId = localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/disabled/msg" : "mpRadio/enabled/msg"
        addPopup(null, loc(popupLocId, { player = colorize("activeTextColor", getPlayerName(name)) }))
      }
    })



  if (hasMenuChat.get()) {
    if (hasChatEnable && canInviteToChatRoom) {
      let inviteMenu = generateInviteMenu(name)
      actions.append({
        text = loc("chat/invite_to_room")
        isVisualDisabled = !canChat || !canInteractCrossConsoleValue || !canInteractCrossPlatform || isProfileMuted || isBlock
        show = inviteMenu && inviteMenu.len() > 0
        action = function() {
          if (!canInteractCrossConsoleValue)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossNetworkCommunicationsRestrictionMsgBox()
          else if (isProfileMuted)
            showXboxPlayerMuted(name)
          else if (!canChat)
            notifyPlayerAboutRestriction(contact)
          else if (isBlock)
            showBlockedPlayerPopup(name)
          else
            broadcastEvent("ChatOpenInviteMenu", { menu = inviteMenu, position = params?.position })
        }
      })
    }

    if (roomData)
      actions.append(
        {
          text = loc("chat/kick_from_room")
          show = !isRoomSquad(roomId) && !isLobbyRoom(roomId) && isImRoomOwner(roomData)
          action = @() broadcastEvent("ChatKickPlayerFromRoom", { playerName = name })
        }
        {
          text = loc("contacts/copyNickToEditbox")
          show = !isMe && showConsoleButtons.get()
          action = @() broadcastEvent("ChatAddNickToEdit", { playerName = name })
        }
      )

    if (!isMe) {
      if (roomData) {
        for (local i = 0; i < roomData.mBlocks.len(); i++) {
          if (roomData.mBlocks[i].from == name || roomData.mBlocks[i].uid == uid) {
            canComplain = true
            break
          }
        }
      }
      else {
        let threadInfo = getThreadInfo(roomId)
        if (threadInfo && threadInfo.ownerNick == name)
          canComplain = true
      }
    }
  }



  if (canComplain)
    actions.append({
      text = loc("mainmenu/btnComplain")
      action = function() {
        let config = {
          userId = uid,
          name = name,
          playerName = params.playerName,
          clanTag = clanTag,
          roomId = roomId,
          roomName = roomData ? roomData.getRoomName() : ""
        }

        if (!isMPChat) {
          let threadInfo = getThreadInfo(roomId)
          if (threadInfo) {
            chatLog = chatLog != null ? chatLog : {}
            chatLog.category   <- threadInfo.category
            chatLog.title      <- threadInfo.title
            chatLog.ownerUid   <- threadInfo.ownerUid
            chatLog.ownerNick  <- threadInfo.ownerNick
            if (!roomData)
              config.roomName = g_chat_room_type.THREAD.getRoomName(roomId)
          }
        }

        checkCanComplainAndProceed(uid, @() gui_modal_complain(config, chatLog))
      }
    })



  if (is_myself_anyof_moderators() && (roomId || isMPChat || isMPLobby))
    actions.append(
      {
        text = loc("contacts/moderator_copyname")
        action = @() copy_to_clipboard(getPlayerName(name))
        hasSeparator = true
      }
      {
        text = loc("contacts/moderator_ban")
        show = myself_can_devoice() || myself_can_ban()
        action = @() gui_modal_ban(contact, chatLog)
      }
    )


  let buttons = params?.extendButtons ?? []
  buttons.extend(actions)
  callback?(buttons)
}

function showMenuImpl(contact, handler, params) {
  contact.checkInteractionStatus(function(status) {
    retrieveActions(contact, params, status, function(menu) {
      openRightClickMenu(menu, handler, params?.position, params?.orientation, params?.onClose)
    })
  })
}

function showMenu(v_contact, handler, params = {}) {
  let contact = v_contact ?? verifyContact(params)
  if (!contact && params?.playerName) {
    let showMenu_ = callee()
    find_contact_by_name_and_do(params.playerName, @(c) c && showMenu_(c, handler, params))
    return
  }

  if (!contact)
    return

  if (contact.needCheckXboxId())
    return contact.updateXboxIdAndDo(@() showMenuImpl(contact, handler, params))

  showMenuImpl(contact, handler, params)
}

function showSquadMemberMenu(obj) {
  if (!checkObj(obj))
    return

  let member = obj.getUserData()
  if (member == null)
    return

  let position = obj.getPosRC()
  showMenu(null, null, {
    playerName = member.name
    uid = member.uid
    clanTag = member.clanTag
    squadMemberData = member
    position = position
  })
}

function showChatPlayerRClickMenu(playerName, roomId = null, contact = null, position = null) {
  showMenu(contact, this, {
    position = position
    roomId = roomId
    playerName = playerName
    canComplain = true
  })
}

function showSessionPlayerRClickMenu(handler, player, chatLog = null, position = null, orientation = null) {
  if (!player || player.isBot || !("userId" in player) || !isLoggedIn.get())
    return

  showMenu(null, handler, {
    playerName = player.name
    uid = player.userId.tostring()
    clanTag = player.clanTag
    position = position
    orientation = orientation
    chatLog = chatLog
    isMPLobby = true
    canComplain = true
  })
}

return freeze({
  showMenu = showMenu
  showXboxPlayerMuted = showXboxPlayerMuted
  notifyPlayerAboutRestriction = notifyPlayerAboutRestriction
  showBlockedPlayerPopup = showBlockedPlayerPopup
  showSquadMemberMenu
  showChatPlayerRClickMenu
  showSessionPlayerRClickMenu
})
