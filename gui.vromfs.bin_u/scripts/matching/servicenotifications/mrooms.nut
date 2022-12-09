from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { format } = require("string")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

local MRoomsHandlers = class {
  [PERSISTENT_DATA_PARAMS] = [
    "hostId", "roomId", "room", "roomMembers", "isConnectAllowed", "roomOps", "isHostReady", "isSelfReady", "isLeaving"
  ]

  hostId = null //user host id
  roomId = INVALID_ROOM_ID
  room   = null
  roomMembers = null //[]
  isConnectAllowed = false
  roomOps = null //{}
  isHostReady = false
  isSelfReady = false
  isLeaving = false

  constructor()
  {
    this.roomMembers = []
    this.roomOps = {}

    ::g_script_reloader.registerPersistentData("MRoomsHandlers", this, this[PERSISTENT_DATA_PARAMS])

    foreach (notificationName, callback in
              {
                ["*.on_room_invite"] = this.onRoomInvite.bindenv(this),
                ["mrooms.on_host_notify"] = this.onHostNotify.bindenv(this),
                ["mrooms.on_room_member_joined"] = this.onRoomMemberJoined.bindenv(this),
                ["mrooms.on_room_member_leaved"] = this.onRoomMemberLeft.bindenv(this),
                ["mrooms.on_room_attributes_changed"] = this.onRoomAttrChanged.bindenv(this),
                ["mrooms.on_room_member_attributes_changed"] = this.onRoomMemberAttrChanged.bindenv(this),
                ["mrooms.on_room_destroyed"] = this.onRoomDestroyed.bindenv(this),
                ["mrooms.on_room_member_kicked"] = this.onRoomMemberKicked.bindenv(this)
              }
            )
      ::matching_rpc_subscribe(notificationName, callback)
  }

  function getRoomId()
  {
    return this.roomId
  }

  function hasSession()
  {
    return this.hostId != null
  }

  function isPlayerRoomOperator(user_id)
  {
    return (user_id in this.roomOps)
  }

  function __cleanupRoomState()
  {
    if (this.room == null)
      return

    this.hostId = null
    this.roomId = INVALID_ROOM_ID
    this.room   = null
    this.roomMembers = []
    this.roomOps = {}
    this.isConnectAllowed = false
    this.isHostReady = false
    this.isSelfReady = false
    this.isLeaving = false

    ::notify_room_destroyed({})
  }

  function __onHostConnectReady()
  {
    this.isHostReady = true
    if (this.isSelfReady)
      this.__connectToHost()
  }

  function __onSelfReady()
  {
    this.isSelfReady = true
    if (this.isHostReady)
      this.__connectToHost()
  }

  function __addRoomMember(member)
  {
    if (getTblValue("operator", member.public))
      this.roomOps[member.userId] <- true

    if (getTblValue("host", member.public))
    {
      log(format("found host %s (%s)", member.name, member.userId.tostring()))
      this.hostId = member.userId
    }

    let curMember = this.__getRoomMember(member.userId)
    if (curMember == null)
      this.roomMembers.append(member)
    this.__updateMemberAttributes(member, curMember)
  }

  function __getRoomMember(user_id)
  {
    foreach (_idx, member in this.roomMembers)
      if (member.userId == user_id)
        return member
    return null
  }

  function __getMyRoomMember()
  {
    foreach (_idx, member in this.roomMembers)
      if (::is_my_userid(member.userId))
        return member
    return null
  }

  function __removeRoomMember(user_id)
  {
    foreach (idx, member in this.roomMembers)
    {
      if (member.userId == user_id)
      {
        this.roomMembers.remove(idx)
        break
      }
    }

    if (user_id == this.hostId)
    {
      this.hostId = null
      this.isConnectAllowed = false
      this.isHostReady = false
    }

    if (user_id in this.roomOps)
      delete this.roomOps[user_id]

    if (::is_my_userid(user_id))
      this.__cleanupRoomState()
  }

  function __updateMemberAttributes(member, cur_member = null)
  {
    if (cur_member == null)
      cur_member = this.__getRoomMember(member.userId)
    if (cur_member == null)
    {
      log(format("failed to update member attributes. member not found in room %s",
                          member.userId.tostring()))
      return
    }
    this.__mergeAttribs(member, cur_member)

    if (member.userId == this.hostId)
    {
      if (member?.public.connect_ready ?? false)
        this.__onHostConnectReady()
    }
    else if (::is_my_userid(member.userId))
    {
      let readyStatus = member?.public.ready
      if (readyStatus == true)
        this.__onSelfReady()
      else if (readyStatus == false)
        this.isSelfReady = false
    }
  }

  function __mergeAttribs(attr_from, attr_to)
  {
    let updateAttribs = function(upd_data, attribs)
    {
      foreach (key, value in upd_data)
      {
        if (value == null && (key in attribs))
          delete attribs[key]
        else
          attribs[key] <- value
      }
    }

    let pub = getTblValue("public", attr_from)
    let priv = getTblValue("private", attr_from)

    if (type(priv) == "table")
    {
      if ("private" in attr_to)
        updateAttribs(priv, attr_to.private)
      else
        attr_to.private <- priv
    }
    if (type(pub) == "table")
    {
      if ("public" in attr_to)
        updateAttribs(pub, attr_to.public)
      else
        attr_to.public <- pub
    }
  }

  function __isNotifyForCurrentRoom(notify)
  {
    // ignore all room notifcations after leave has been called
    return !this.isLeaving && this.roomId != INVALID_ROOM_ID && this.roomId == notify.roomId
  }

  function __connectToHost()
  {
    log("__connectToHost")
    if (!this.hasSession())
      return

    let host = this.__getRoomMember(this.hostId)
    if (!host)
    {
      log("__connectToHost failed: host is not in the room")
      return
    }

    let me = this.__getMyRoomMember()
    if (!me)
    {
      log("__connectToHost failed: player is not in the room")
      return
    }

    let hostPub = host.public
    let roomPub = this.room.public

    if (!("room_key" in roomPub))
    {
      let mePub = toString(me?.public, 3)          // warning disable: -declared-never-used
      let mePrivate = toString(me?.private, 3)     // warning disable: -declared-never-used
      let meStr = toString(me, 3)                  // warning disable: -declared-never-used
      let roomStr = toString(roomPub, 3)           // warning disable: -declared-never-used
      let roomMission = toString(roomPub?.mission) // warning disable: -declared-never-used
      ::script_net_assert("missing room_key in room")

      ::send_error_log("missing room_key in room", false, "log")
      return
    }

    local serverUrls = [];
    if ("serverURLs" in hostPub)
      serverUrls = hostPub.serverURLs
    else if ("ip" in hostPub && "port" in hostPub)
    {
      let ip = hostPub.ip
      let ipStr = format("%u.%u.%u.%u:%d", ip&255, (ip>>8)&255, (ip>>16)&255, ip>>24, hostPub.port)
      serverUrls.append(ipStr)
    }

    ::connect_to_host_list(serverUrls, roomPub.room_key, me.private.auth_key, getTblValue("sessionId", roomPub, this.roomId))
  }

  // notifications
  function onRoomInvite(notify, send_resp)
  {
    local inviteData = notify.invite_data
    if (!(type(inviteData) == "table"))
      inviteData = {}
    inviteData.roomId <- notify.roomId

    if (::notify_room_invite(inviteData))
      send_resp({accept = true})
    else
      send_resp({accept = false})
  }

  function onRoomMemberJoined(member)
  {
    if (!this.__isNotifyForCurrentRoom(member))
      return

    log(format("%s (%s) joined to room", member.name, member.userId.tostring()))
    this.__addRoomMember(member)

    ::notify_room_member_joined(member)
  }

  function onRoomMemberLeft(member)
  {
    if (!this.__isNotifyForCurrentRoom(member))
      return

    log(format("%s (%s) left from room", member.name, member.userId.tostring()))
    this.__removeRoomMember(member.userId)
    ::notify_room_member_leaved(member)
  }

  function onRoomMemberKicked(member)
  {
    if (!this.__isNotifyForCurrentRoom(member))
      return

    log(format("%s (%s) kicked from room", member.name, member.userId.tostring()))
    this.__removeRoomMember(member.userId)
    ::notify_room_member_kicked(member)
  }

  function onRoomAttrChanged(notify)
  {
    if (!this.__isNotifyForCurrentRoom(notify))
      return

    this.__mergeAttribs(notify, this.room)
    ::notify_room_attribs_changed(notify)
  }

  function onRoomMemberAttrChanged(notify)
  {
    if (!this.__isNotifyForCurrentRoom(notify))
      return

    this.__updateMemberAttributes(notify)
    ::notify_room_member_attribs_changed(notify)
  }

  function onRoomDestroyed(notify)
  {
    if (!this.__isNotifyForCurrentRoom(notify))
      return
    this.__cleanupRoomState()
  }

  function onHostNotify(notify)
  {
    debugTableData(notify)
    if (!this.__isNotifyForCurrentRoom(notify))
      return

    if (notify.hostId != this.hostId)
    {
      log("warning: got host notify from host that is not in current room")
      return
    }

    if (notify.roomId != this.getRoomId())
    {
      log("warning: got host notify for wrong room")
      return
    }

    if (notify.message == "connect-allowed")
    {
      this.isConnectAllowed = true
      this.__connectToHost()
    }
  }

  function onRoomJoinCb(resp)
  {
    this.__cleanupRoomState()

    this.room = resp
    this.roomId = this.room.roomId
    foreach (member in this.room.members)
      this.__addRoomMember(member)

    if (getTblValue("connect_on_join", this.room.public))
    {
      log("room with auto-connect feature")
      this.isSelfReady = true
      this.__onSelfReady()
    }
  }

  function onRoomLeaveCb()
  {
    this.__cleanupRoomState()
  }
}

::g_mrooms_handlers <- MRoomsHandlers()

::is_my_userid <- function is_my_userid(user_id)
{
  if (type(user_id) == "string")
    return user_id == ::my_user_id_str
  return user_id == ::my_user_id_int64
}

// mrooms API

::is_host_in_room <- function is_host_in_room()
{
  return ::g_mrooms_handlers.hasSession()
}

::create_room <- function create_room(params, cb)
{
  if ((isPlatformXboxOne || isPlatformSony) &&
      !crossplayModule.isCrossPlayEnabled()) {
    params["crossplayRestricted"] <- true
  }

  ::matching_api_func("mrooms.create_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        ::g_mrooms_handlers.onRoomJoinCb(resp)
                      cb(resp)
                    },
                    params)
}

::destroy_room <- function destroy_room(params, cb)
{
  ::matching_api_func("mrooms.destroy_room", cb, params)
}

::join_room <- function join_room(params, cb)
{
  ::matching_api_func("mrooms.join_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        ::g_mrooms_handlers.onRoomJoinCb(resp)
                      else
                      {
                        resp.roomId <- params?.roomId
                        resp.password <- params?.password
                      }
                      cb(resp)
                    },
                    params)
}

::leave_room <- function leave_room(params, cb)
{
  let oldRoomId = ::g_mrooms_handlers.getRoomId()
  ::g_mrooms_handlers.isLeaving = true

  ::matching_api_func("mrooms.leave_room",
                    function(resp)
                    {
                      if (::g_mrooms_handlers.getRoomId() == oldRoomId)
                        ::g_mrooms_handlers.onRoomLeaveCb()
                      cb(resp)
                    },
                    params)
}

::set_member_attributes <- function set_member_attributes(params, cb)
{
  ::matching_api_func("mrooms.set_member_attributes", cb, params)
}

::set_room_attributes <- function set_room_attributes(params, cb)
{
  log($"[PSMT] setting room attributes: {params?.public?.psnMatchId}")
  ::matching_api_func("mrooms.set_attributes", cb, params)
}

::kick_member <- function kick_member(params, cb)
{
  ::matching_api_func("mrooms.kick_from_room", cb, params)
}

::room_ban_player <- function room_ban_player(params, cb)
{
  ::matching_api_func("mrooms.ban_player", cb, params)
}

::room_unban_player <- function room_unban_player(params, cb)
{
  ::matching_api_func("mrooms.unban_player", cb, params)
}

::room_start_session <- function room_start_session(params, cb)
{
  ::matching_api_func("mrooms.start_session", cb, params)
}

::room_set_password <- function room_set_password(params, cb)
{
  ::matching_api_func("mrooms.set_password", cb, params)
}

::room_set_ready_state <- function room_set_ready_state(params, cb)
{
  ::matching_api_func("mrooms.set_ready_state", cb, params)
}

::invite_player_to_room <- function invite_player_to_room(params, cb)
{
  ::matching_api_func("mrooms.invite_player", cb, params)
}

::fetch_rooms_list <- function fetch_rooms_list(params, cb)
{
  ::matching_api_func("mrooms.fetch_rooms_digest2",
                    function (resp)
                    {
                      if (::checkMatchingError(resp, false))
                      {
                        foreach (room in getTblValue("digest", resp, []))
                        {
                          let hasPassword = room?.public.hasPassword
                          if (hasPassword != null)
                            room.hasPassword <- hasPassword
                        }
                      }
                      cb(resp)
                    },
                    params)
}

::serialize_dyncampaign <- function serialize_dyncampaign(_params, cb)
{
  let priv = {
    dyncamp = {
      data = ::get_dyncampaign_b64blk()
    }
  }

  ::matching_api_func("mrooms.set_attributes", cb, {private = priv})
}

::get_current_room <- function get_current_room()
{
  return ::g_mrooms_handlers.getRoomId()
}

::leave_session <- function leave_session()
{
  if (::g_mrooms_handlers.getRoomId() != INVALID_ROOM_ID)
    ::leave_room({}, function(_resp) {})
}

::is_player_room_operator <- function is_player_room_operator(user_id)
{
  return ::g_mrooms_handlers.isPlayerRoomOperator(user_id)
}

