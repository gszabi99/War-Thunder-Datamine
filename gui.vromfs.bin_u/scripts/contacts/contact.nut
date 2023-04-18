//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlayerFromXboxOne,
        isPlayerFromPS4,
        getPlayerName,
        isPlatformSony } = require("%scripts/clientState/platform.nut")
let { reqPlayerExternalIDsByUserId } = require("%scripts/user/externalIdsService.nut")
let { getXboxChatEnableStatus,
        isChatEnabled,
        isCrossNetworkMessageAllowed } = require("%scripts/chat/chatStates.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let { isEmpty, isInteger } = require("%sqStdLibs/helpers/u.nut")
let { subscribe } = require("eventbus")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let psnSocial = require("sony.social")

let contactsByName = {}

subscribe("playerProfileDialogClosed", function(r) {
  if (r?.result.wasCanceled)
    return
  updateContacts(true)
})

::Contact <- class {
  name = ""
  uid = ""
  uidInt64 = null
  clanTag = ""
  title = ""

  presence = ::g_contact_presence.UNKNOWN
  forceOffline = false
  isForceOfflineChecked = !is_platform_xbox

  voiceStatus = null

  online = null
  unknown = true
  gameStatus = null
  gameConfig = null
  inGameEx = null

  psnId = ""
  xboxId = ""
  steamName = ""

  pilotIcon = "cardicon_bot"

  afterSuccessUpdateFunc = null

  interactionStatus = null

  isBlockedMe = false

  constructor(contactData) {
    let newName = contactData?["name"] ?? ""
    if (newName.len()
        && isEmpty(contactData?.clanTag)
        && ::clanUserTable?[newName])
      contactData.clanTag <- ::clanUserTable[newName]

    this.update(contactData)

    ::add_event_listener("XboxSystemUIReturn", function(_p) {
      this.interactionStatus = null
    }, this)
  }

  static getByName = @(name) contactsByName?[name]

  function update(contactData) {
    foreach (key, val in contactData)
      if (key in this)
        this[key] = val

    this.uidInt64 = this.uid != "" ? this.uid.tointeger() : null

    this.refreshClanTagsTable()
    if (this.name.len())
      contactsByName[this.name] <- this

    if (this.afterSuccessUpdateFunc) {
      this.afterSuccessUpdateFunc()
      this.afterSuccessUpdateFunc = null
    }
  }

  function resetMatchingParams() {
    this.presence = ::g_contact_presence.UNKNOWN

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
    if (this.presence == ::g_contact_presence.IN_QUEUE
        || this.presence == ::g_contact_presence.IN_GAME) {
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
    this.updateXboxIdAndDo(@() ::xbox_show_add_remove_friend(this.xboxId))
  }

  function openXboxProfile() {
    this.updateXboxIdAndDo(@() ::xbox_show_profile_card(this.xboxId))
  }

  function getXboxId(afterSuccessCb = null) {
    if (this.xboxId != "")
      return this.xboxId

    reqPlayerExternalIDsByUserId(this.uid, { showProgressBox = true }, afterSuccessCb)
    return null
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

    if (::to_integer_safe(this.psnId, -1, false) == -1)
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

  getName = @() getPlayerName(this.name)

  function needCheckForceOffline() {
    if (this.isForceOfflineChecked
        || !this.isInFriendGroup()
        || this.presence == ::g_contact_presence.UNKNOWN)
      return false

    return isPlayerFromXboxOne(this.name)
  }

  isSameContact = @(v_uid) isInteger(v_uid)
    ? v_uid == this.uidInt64
    : v_uid == this.uid

  function isMe() {
    return this.uidInt64 == ::my_user_id_int64
      || this.uid == ::my_user_id_str
      || this.name == ::my_user_name
  }

  function getInteractionStatus(needShowSystemMessage = false) {
    if (!is_platform_xbox || this.isMe())
      return XBOX_COMMUNICATIONS_ALLOWED

    if (this.xboxId == "") {
      let status = getXboxChatEnableStatus(needShowSystemMessage)
      if (status == XBOX_COMMUNICATIONS_ONLY_FRIENDS && !this.isInFriendGroup())
        return XBOX_COMMUNICATIONS_BLOCKED

      return isChatEnabled() ? XBOX_COMMUNICATIONS_ALLOWED : XBOX_COMMUNICATIONS_BLOCKED
    }

    if (!needShowSystemMessage && this.interactionStatus != null)
      return this.interactionStatus

    this.interactionStatus = ::can_use_text_chat_with_target(this.xboxId, needShowSystemMessage)
    return this.interactionStatus
  }

  function canChat(needShowSystemMessage = false) {
    if (!needShowSystemMessage
      && ((isMultiplayerPrivilegeAvailable.value && !isCrossNetworkMessageAllowed(this.name))
          || this.isBlockedMe)
      )
      return false

    if (!isCrossNetworkMessageAllowed(this.name)) {
      if (needShowSystemMessage)
        this.getInteractionStatus(needShowSystemMessage) //just to show overlay message
      return false
    }

    let intSt = this.getInteractionStatus(needShowSystemMessage)
    return intSt == XBOX_COMMUNICATIONS_ALLOWED
      || (intSt == XBOX_COMMUNICATIONS_ONLY_FRIENDS && this.isInFriendGroup())
  }

  function canInvite(needShowSystemMessage = false) {
    if (!needShowSystemMessage
      && (!isMultiplayerPrivilegeAvailable.value
          || !isCrossNetworkMessageAllowed(this.name))
      )
      return false

    let intSt = this.getInteractionStatus(needShowSystemMessage)
    return intSt == XBOX_COMMUNICATIONS_ALLOWED || intSt == XBOX_COMMUNICATIONS_MUTED
  }

  function isMuted() {
    return this.getInteractionStatus() == XBOX_COMMUNICATIONS_MUTED
  }

  //For now it is for PSN only. For all will be later
  function updateMuteStatus() {
    if (!isPlatformSony)
      return

    let ircName = ::g_string.replace(this.name, "@", "%40") //!!!Temp hack, *_by_uid will not be working on sony testing build
    ::gchat_voice_mute_peer_by_name(this.isInBlockGroup() || this.isBlockedMe, ircName)
  }

  function isInGroup(groupName) {
    let userId = this.uid
    return (::contacts?[groupName] ?? []).findvalue(@(p) p.uid == userId) != null
  }

  isInFriendGroup = @() this.isInGroup(EPL_FRIENDLIST)
  isInPSNFriends = @() this.isInGroup(::EPLX_PS4_FRIENDS)
  isInBlockGroup = @() this.isInGroup(EPL_BLOCKLIST)
}
