from "%scripts/dagui_natives.nut" import gchat_voice_mute_peer_by_name
from "%scripts/dagui_library.nut" import *
let { isPlayerFromXboxOne, isPlayerFromPS4, isPlatformSony
} = require("%scripts/clientState/platform.nut")
let { reqPlayerExternalIDsByUserId } = require("%scripts/user/externalIdsService.nut")
let { getXboxChatEnableStatus, isChatEnabled, isCrossNetworkMessageAllowed
} = require("%scripts/chat/chatStates.nut")
let { isEmpty, isInteger } = require("%sqStdLibs/helpers/u.nut")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let psnSocial = require("sony.social")
let { EPLX_PS4_FRIENDS, contactsByGroups, blockedMeUids, cacheContactByName
} = require("%scripts/contacts/contactsManager.nut")
let { replace, utf8ToLower } = require("%sqstd/string.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { show_profile_card } = require("%xboxLib/impl/user.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { userName, userIdStr, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { can_we_text_user, CommunicationState } = require("%scripts/xbox/permissions.nut")

class Contact {
  name = ""
  uid = ""
  uidInt64 = null
  clanTag = ""
  title = ""

  presence = contactPresence.UNKNOWN
  forceOffline = false
  isForceOfflineChecked = !is_platform_xbox

  voiceStatus = null

  online = null
  unknown = true
  gameStatus = null
  gameConfig = null
  inGameEx = null
  isSteamOnline = false

  psnId = ""
  xboxId = ""
  steamName = null
  steamId = null
  steamAvatar = null

  pilotIcon = "cardicon_bot"

  afterSuccessUpdateFunc = null

  interactionStatus = null

  contactServiceGroup = ""
  lowerName = ""

  constructor(contactData) {
    let newName = contactData?["name"] ?? ""
    if (newName.len()
        && isEmpty(contactData?.clanTag)
        && ::clanUserTable?[newName])
      contactData.clanTag <- ::clanUserTable[newName]

    this.update(contactData)

    add_event_listener("XboxSystemUIReturn", function(_p) {
      this.interactionStatus = null
    }, this)
  }

  function update(contactData) {
    let isChangedName = (("name" in contactData) && contactData.name != this.name)
      || (("steamName" in contactData) && contactData.steamName != this.steamName)
    foreach (key, val in contactData)
      if (key in this)
        this[key] = val

    this.uidInt64 = this.uid != "" ? this.uid.tointeger() : null
    if (isChangedName)
      this.lowerName = utf8ToLower(this.steamName ?? this.name)

    this.refreshClanTagsTable()
    if (this.name.len())
      cacheContactByName(this)

    if (this.afterSuccessUpdateFunc) {
      this.afterSuccessUpdateFunc()
      this.afterSuccessUpdateFunc = null
    }
  }

  function resetMatchingParams() {
    this.presence = contactPresence.UNKNOWN

    this.online = null
    this.unknown = true
    this.gameStatus = null
    this.gameConfig = null
    this.inGameEx = null
  }

  function setClanTag(v_clanTag) {
    this.clanTag = v_clanTag
    this.refreshClanTagsTable()
  }

  function refreshClanTagsTable() {
    //clanTagsTable used in lists where not know userId, so not exist contact.
    //but require to correct work with contacts too
    if (this.name.len())
      ::clanUserTable[this.name] <- this.clanTag
  }

  function getPresenceText() {
    local locParams = {}
    if (this.presence == contactPresence.IN_QUEUE
        || this.presence == contactPresence.IN_GAME) {
      let event = ::events.getEvent(getTblValue("eventId", this.gameConfig))
      locParams = {
        gameMode = event ? ::events.getEventNameText(event) : ""
        country = loc(getTblValue("country", this.gameConfig, ""))
      }
    }
    return this.presence.getText(locParams)
  }

  function canOpenXBoxFriendsWindow(groupName) {
    return isPlayerFromXboxOne(this.name) && groupName != EPL_BLOCKLIST
  }

  function openXBoxFriendsEdit() {
    this.updateXboxIdAndDo(function() {
      if (this.xboxId != "")
        show_profile_card(this.xboxId.tointeger(), null)
    })
  }

  function openXboxProfile() {
    this.updateXboxIdAndDo(function() {
      if (this.xboxId != "")
        show_profile_card(this.xboxId.tointeger(), null)
    })
  }

  function updateXboxIdAndDo(cb = null) {
    cb = cb ?? @() null

    if (this.xboxId != "")
      return cb()

    reqPlayerExternalIDsByUserId(this.uid, { showProgressBox = true }, cb)
  }

  function canOpenPSNActionWindow() {
    return psnSocial?.open_player_profile != null && isPlayerFromPS4(this.name)
  }

  function openPSNContactEdit(groupName) {
    if (groupName == EPL_BLOCKLIST)
      this.openPSNBlockUser()
    else
      this.openPSNReqFriend()
  }

  function openPSNRequest(action) {
    if (!this.canOpenPSNActionWindow())
      return

    this.updatePSNIdAndDo(@() psnSocial?.open_player_profile(
      this.psnId.tointeger(),
      action,
      "PlayerProfileDialogClosed",
      {}
    ))
  }

  function updatePSNIdAndDo(cb = null) {
    cb = cb ?? @() null

    let finCb = function() {
      this.verifyPsnId()
      cb()
    }

    if (this.psnId != "")
      return finCb()

    reqPlayerExternalIDsByUserId(this.uid, { showProgressBox = true }, finCb)
  }

  function verifyPsnId() {
    //To prevent crash, if psn player wasn't been in game
    // for a long time, instead of int was returning
    // his name

    //No need to do anything
    if (this.psnId == "")
      return

    if (to_integer_safe(this.psnId, -1, false) == -1)
      this.psnId = "-1"
  }

  openPSNReqFriend = @() this.openPSNRequest(psnSocial.PlayerAction.REQUEST_FRIENDSHIP)
  openPSNBlockUser = @() this.openPSNRequest(psnSocial.PlayerAction.BLOCK_PLAYER)
  openPSNProfile   = @() this.openPSNRequest(psnSocial.PlayerAction.DISPLAY)

  function sendPsnFriendRequest(groupName) {
    if (this.canOpenPSNActionWindow())
      this.openPSNContactEdit(groupName)
  }

  function needCheckXboxId() {
    return isPlayerFromXboxOne(this.name) && this.xboxId == ""
  }

  getName = @() this.steamName ?? getPlayerName(this.name)

  function needCheckForceOffline() {
    if (this.isForceOfflineChecked
        || !this.isInFriendGroup()
        || this.presence == contactPresence.UNKNOWN)
      return false

    return isPlayerFromXboxOne(this.name)
  }

  isSameContact = @(v_uid) isInteger(v_uid)
    ? v_uid == this.uidInt64
    : v_uid == this.uid

  function isMe() {
    return this.uidInt64 == userIdInt64.value
      || this.uid == userIdStr.value
      || this.name == userName.value
  }

  function checkInteractionStatus(callback) {
    if (!is_platform_xbox || this.isMe()) {
      callback?(CommunicationState.Allowed)
      return
    }

    if (this.xboxId == "") {
      local result = CommunicationState.Blocked
      let status = getXboxChatEnableStatus()
      if (status == CommunicationState.FriendsOnly && !this.isInFriendGroup())
        result = CommunicationState.Blocked
      else
        result = isChatEnabled() ? CommunicationState.Allowed : CommunicationState.Blocked
      callback?(result)
      return
    }

    if (this.interactionStatus == null) {
      local thisCapture = this
      can_we_text_user(this.xboxId.tointeger(), function(status) {
        thisCapture.interactionStatus = status
        callback?(thisCapture.interactionStatus)
      })
    }
    else
      callback?(this.interactionStatus)
  }

  function checkCanChat(callback) {
    if (((isMultiplayerPrivilegeAvailable.value && !isCrossNetworkMessageAllowed(this.name)) || this.isBlockedMe())) {
      callback?(false)
      return
    }

    if (!isCrossNetworkMessageAllowed(this.name)) {
      callback?(false)
      return
    }

    this.checkInteractionStatus(function(status) {
      let result = status == CommunicationState.Allowed || (status == CommunicationState.FriendsOnly && this.isInFriendGroup())
      callback?(result)
    })
  }

  function canChat(comms_state) {
    if (((isMultiplayerPrivilegeAvailable.value && !isCrossNetworkMessageAllowed(this.name)) || this.isBlockedMe()))
      return false

    if (!isCrossNetworkMessageAllowed(this.name)) {
      return false
    }

    return comms_state == CommunicationState.Allowed || (comms_state == CommunicationState.FriendsOnly && this.isInFriendGroup())
  }

  function checkCanInvite(callback) {
    if ((!isMultiplayerPrivilegeAvailable.value || !isCrossNetworkMessageAllowed(this.name))) {
      callback?(false)
      return
    }

    this.checkInteractionStatus(function(status) {
      let result = status == CommunicationState.Allowed || status == CommunicationState.Muted
      callback?(result)
    })
  }

  function canInvite(comms_state) {
    if ((!isMultiplayerPrivilegeAvailable.value || !isCrossNetworkMessageAllowed(this.name)))
      return false

    return comms_state == CommunicationState.Allowed || comms_state == CommunicationState.Muted
  }

  function checkIsMuted(callback) {
    this.checkInteractionStatus(function(status) {
      callback?(status == CommunicationState.Muted)
    })
  }

  function isMuted(comms_state) {
    return comms_state == CommunicationState.Muted
  }

  //For now it is for PSN only. For all will be later
  function updateMuteStatus() {
    if (!isPlatformSony)
      return

    let ircName = replace(this.name, "@", "%40") //!!!Temp hack, *_by_uid will not be working on sony testing build
    gchat_voice_mute_peer_by_name(this.isInBlockGroup() || this.isBlockedMe(), ircName)
  }

  isBlockedMe = @() this.uid in blockedMeUids.value
  isInGroup = @(groupName) this.uid in (contactsByGroups?[groupName] ?? {})
  isInFriendGroup = @() this.isInGroup(EPL_FRIENDLIST)
  isInPSNFriends = @() this.isInGroup(EPLX_PS4_FRIENDS)
  isInBlockGroup = @() this.isInGroup(EPL_BLOCKLIST)
  setContactServiceGroup = @(grp_name) this.contactServiceGroup = grp_name
}

return Contact
