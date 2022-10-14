from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

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

::Contact <- class
{
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
  facebookName = ""

  pilotIcon = "cardicon_bot"

  afterSuccessUpdateFunc = null

  interactionStatus = null

  isBlockedMe = false

  constructor(contactData)
  {
    let newName = contactData?["name"] ?? ""
    if (newName.len()
        && isEmpty(contactData?.clanTag)
        && ::clanUserTable?[newName])
      contactData.clanTag <- ::clanUserTable[newName]

    update(contactData)

    ::add_event_listener("XboxSystemUIReturn", function(p) {
      interactionStatus = null
    }, this)
  }

  static getByName = @(name) contactsByName?[name]

  function update(contactData)
  {
    foreach (key, val in contactData)
      if (key in this)
        this[key] = val

    uidInt64 = uid != "" ? uid.tointeger() : null

    refreshClanTagsTable()
    if (name.len())
      contactsByName[name] <- this

    if (afterSuccessUpdateFunc)
    {
      afterSuccessUpdateFunc()
      afterSuccessUpdateFunc = null
    }
  }

  function resetMatchingParams()
  {
    presence = ::g_contact_presence.UNKNOWN

    online = null
    unknown = true
    gameStatus = null
    gameConfig = null
    inGameEx = null
  }

  function setClanTag(v_clanTag)
  {
    clanTag = v_clanTag
    refreshClanTagsTable()
  }

  function refreshClanTagsTable()
  {
    //clanTagsTable used in lists where not know userId, so not exist contact.
    //but require to correct work with contacts too
    if (name.len())
      ::clanUserTable[name] <- clanTag
  }

  function getPresenceText()
  {
    local locParams = {}
    if (presence == ::g_contact_presence.IN_QUEUE
        || presence == ::g_contact_presence.IN_GAME)
    {
      let event = ::events.getEvent(getTblValue("eventId", gameConfig))
      locParams = {
        gameMode = event ? ::events.getEventNameText(event) : ""
        country = loc(getTblValue("country", gameConfig, ""))
      }
    }
    return presence.getText(locParams)
  }

  function canOpenXBoxFriendsWindow(groupName)
  {
    return isPlayerFromXboxOne(name) && groupName != EPL_BLOCKLIST
  }

  function openXBoxFriendsEdit()
  {
    updateXboxIdAndDo(@() ::xbox_show_add_remove_friend(xboxId))
  }

  function openXboxProfile() {
    updateXboxIdAndDo(@() ::xbox_show_profile_card(xboxId))
  }

  function getXboxId(afterSuccessCb = null)
  {
    if (xboxId != "")
      return xboxId

    reqPlayerExternalIDsByUserId(uid, {showProgressBox = true}, afterSuccessCb)
    return null
  }

  function updateXboxIdAndDo(cb = null) {
    cb = cb ?? @() null

    if (xboxId != "")
      return cb()

    reqPlayerExternalIDsByUserId(uid, {showProgressBox = true}, cb)
  }

  function canOpenPSNActionWindow() {
    return psnSocial?.open_player_profile != null && isPlayerFromPS4(name)
  }

  function openPSNContactEdit(groupName) {
    if (groupName == EPL_BLOCKLIST)
      openPSNBlockUser()
    else
      openPSNReqFriend()
  }

  function openPSNRequest(action) {
    if (!canOpenPSNActionWindow())
      return

    updatePSNIdAndDo(@() psnSocial?.open_player_profile(
      psnId.tointeger(),
      action,
      "PlayerProfileDialogClosed",
      {}
    ))
  }

  function updatePSNIdAndDo(cb = null) {
    cb = cb ?? @() null

    let finCb = function() {
      verifyPsnId()
      cb()
    }

    if (psnId != "")
      return finCb()

    reqPlayerExternalIDsByUserId(uid, {showProgressBox = true}, finCb)
  }

  function verifyPsnId() {
    //To prevent crash, if psn player wasn't been in game
    // for a long time, instead of int was returning
    // his name

    //No need to do anything
    if (psnId == "")
      return

    if (::to_integer_safe(psnId, -1, false) == -1)
      psnId = "-1"
  }

  openPSNReqFriend = @() openPSNRequest(psnSocial.PlayerAction.REQUEST_FRIENDSHIP)
  openPSNBlockUser = @() openPSNRequest(psnSocial.PlayerAction.BLOCK_PLAYER)
  openPSNProfile   = @() openPSNRequest(psnSocial.PlayerAction.DISPLAY)

  function sendPsnFriendRequest(groupName) {
    if (canOpenPSNActionWindow())
      openPSNContactEdit(groupName)
  }

  function needCheckXboxId()
  {
    return isPlayerFromXboxOne(name) && xboxId == ""
  }

  getName = @() getPlayerName(name)

  function needCheckForceOffline()
  {
    if (isForceOfflineChecked
        || !isInFriendGroup()
        || presence == ::g_contact_presence.UNKNOWN)
      return false

    return isPlayerFromXboxOne(name)
  }

  isSameContact = @(v_uid) isInteger(v_uid)
    ? v_uid == uidInt64
    : v_uid == uid

  function isMe()
  {
    return uidInt64 == ::my_user_id_int64
      || uid == ::my_user_id_str
      || name == ::my_user_name
  }

  function getInteractionStatus(needShowSystemMessage = false)
  {
    if (!is_platform_xbox || isMe())
      return XBOX_COMMUNICATIONS_ALLOWED

    if (xboxId == "")
    {
      let status = getXboxChatEnableStatus(needShowSystemMessage)
      if (status == XBOX_COMMUNICATIONS_ONLY_FRIENDS && !isInFriendGroup())
        return XBOX_COMMUNICATIONS_BLOCKED

      return isChatEnabled()? XBOX_COMMUNICATIONS_ALLOWED : XBOX_COMMUNICATIONS_BLOCKED
    }

    if (!needShowSystemMessage && interactionStatus != null)
      return interactionStatus

    interactionStatus = ::can_use_text_chat_with_target(xboxId, needShowSystemMessage)
    return interactionStatus
  }

  function canChat(needShowSystemMessage = false)
  {
    if (!needShowSystemMessage
      && ((isMultiplayerPrivilegeAvailable.value && !isCrossNetworkMessageAllowed(name))
          || isBlockedMe)
      )
      return false

    let intSt = getInteractionStatus(needShowSystemMessage)
    return intSt == XBOX_COMMUNICATIONS_ALLOWED
  }

  function canInvite(needShowSystemMessage = false)
  {
    if (!needShowSystemMessage
      && (!isMultiplayerPrivilegeAvailable.value
          || !isCrossNetworkMessageAllowed(name))
      )
      return false

    let intSt = getInteractionStatus(needShowSystemMessage)
    return intSt == XBOX_COMMUNICATIONS_ALLOWED || intSt == XBOX_COMMUNICATIONS_MUTED
  }

  function isMuted()
  {
    return getInteractionStatus() == XBOX_COMMUNICATIONS_MUTED
  }

  function isXboxChatMuted()
  {
    return uidInt64 != null && ::xbox_is_chat_player_muted(uidInt64)
  }

  //For now it is for PSN only. For all will be later
  function updateMuteStatus() {
    if (!isPlatformSony)
      return

    let ircName = ::g_string.replace(name, "@", "%40") //!!!Temp hack, *_by_uid will not be working on sony testing build
    ::gchat_voice_mute_peer_by_name(isInBlockGroup() || isBlockedMe, ircName)
  }

  function isInGroup(groupName)
  {
    let userId = uid
    return (::contacts?[groupName] ?? []).findvalue(@(p) p.uid == userId ) != null
  }

  isInFriendGroup = @() isInGroup(EPL_FRIENDLIST)
  isInPSNFriends = @() isInGroup(::EPLX_PS4_FRIENDS)
  isInBlockGroup = @() isInGroup(EPL_BLOCKLIST)
}
