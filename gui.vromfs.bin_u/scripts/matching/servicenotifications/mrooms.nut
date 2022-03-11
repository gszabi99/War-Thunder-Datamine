local crossplayModule = require("scripts/social/crossplay.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local string = require("string")

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
    roomMembers = []
    roomOps = {}

    ::g_script_reloader.registerPersistentData("MRoomsHandlers", this, this[PERSISTENT_DATA_PARAMS])

    foreach (notificationName, callback in
              {
                ["*.on_room_invite"] = onRoomInvite.bindenv(this),
                ["mrooms.on_host_notify"] = onHostNotify.bindenv(this),
                ["mrooms.on_room_member_joined"] = onRoomMemberJoined.bindenv(this),
                ["mrooms.on_room_member_leaved"] = onRoomMemberLeft.bindenv(this),
                ["mrooms.on_room_attributes_changed"] = onRoomAttrChanged.bindenv(this),
                ["mrooms.on_room_member_attributes_changed"] = onRoomMemberAttrChanged.bindenv(this),
                ["mrooms.on_room_destroyed"] = onRoomDestroyed.bindenv(this),
                ["mrooms.on_room_member_kicked"] = onRoomMemberKicked.bindenv(this)
              }
            )
      ::matching_rpc_subscribe(notificationName, callback)
  }

  function getRoomId()
  {
    return roomId
  }

  function hasSession()
  {
    return hostId != null
  }

  function isPlayerRoomOperator(user_id)
  {
    return (user_id in roomOps)
  }

  function __cleanupRoomState()
  {
    if (room == null)
      return

    hostId = null
    roomId = INVALID_ROOM_ID
    room   = null
    roomMembers = []
    roomOps = {}
    isConnectAllowed = false
    isHostReady = false
    isSelfReady = false
    isLeaving = false

    notify_room_destroyed({})
  }

  function __onHostConnectReady()
  {
    isHostReady = true
    if (isSelfReady)
      __connectToHost()
  }

  function __onSelfReady()
  {
    isSelfReady = true
    if (isHostReady)
      __connectToHost()
  }

  function __addRoomMember(member)
  {
    if (getTblValue("operator", member.public))
      roomOps[member.userId] <- true

    if (getTblValue("host", member.public))
    {
      dagor.debug(format("found host %s (%s)", member.name, member.userId.tostring()))
      hostId = member.userId
    }

    local curMember = __getRoomMember(member.userId)
    if (curMember == null)
      roomMembers.append(member)
    __updateMemberAttributes(member, curMember)
  }

  function __getRoomMember(user_id)
  {
    foreach (idx, member in roomMembers)
      if (member.userId == user_id)
        return member
    return null
  }

  function __getMyRoomMember()
  {
    foreach (idx, member in roomMembers)
      if (is_my_userid(member.userId))
        return member
    return null
  }

  function __removeRoomMember(user_id)
  {
    foreach (idx, member in roomMembers)
    {
      if (member.userId == user_id)
      {
        roomMembers.remove(idx)
        break
      }
    }

    if (user_id == hostId)
    {
      hostId = null
      isConnectAllowed = false
      isHostReady = false
    }

    if (user_id in roomOps)
      delete roomOps[user_id]

    if (is_my_userid(user_id))
      __cleanupRoomState()
  }

  function __updateMemberAttributes(member, cur_member = null)
  {
    if (cur_member == null)
      cur_member = __getRoomMember(member.userId)
    if (cur_member == null)
    {
      dagor.debug(format("failed to update member attributes. member not found in room %s",
                          member.userId.tostring()))
      return
    }
    __mergeAttribs(member, cur_member)

    if (member.userId == hostId)
    {
      if (member?.public.connect_ready ?? false)
        __onHostConnectReady()
    }
    else if (is_my_userid(member.userId))
    {
      local readyStatus = member?.public.ready
      if (readyStatus == true)
        __onSelfReady()
      else if (readyStatus == false)
        isSelfReady = false
    }
  }

  function __mergeAttribs(attr_from, attr_to)
  {
    local updateAttribs = function(upd_data, attribs)
    {
      foreach (key, value in upd_data)
      {
        if (value == null && (key in attribs))
          delete attribs[key]
        else
          attribs[key] <- value
      }
    }

    local pub = getTblValue("public", attr_from)
    local priv = getTblValue("private", attr_from)

    if (typeof priv == "table")
    {
      if ("private" in attr_to)
        updateAttribs(priv, attr_to.private)
      else
        attr_to.private <- priv
    }
    if (typeof pub == "table")
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
    return !isLeaving && roomId != INVALID_ROOM_ID && roomId == notify.roomId
  }

  function __connectToHost()
  {
    dagor.debug("__connectToHost")
    if (!hasSession())
      return

    local host = __getRoomMember(hostId)
    if (!host)
    {
      dagor.debug("__connectToHost failed: host is not in the room")
      return
    }

    local me = __getMyRoomMember()
    if (!me)
    {
      dagor.debug("__connectToHost failed: player is not in the room")
      return
    }

    local hostPub = host.public
    local roomPub = room.public

    if (!("room_key" in roomPub))
    {
      local mePub = ::toString(me?.public, 3)          // warning disable: -declared-never-used
      local mePrivate = ::toString(me?.private, 3)     // warning disable: -declared-never-used
      local meStr = ::toString(me, 3)                  // warning disable: -declared-never-used
      local roomStr = ::toString(roomPub, 3)           // warning disable: -declared-never-used
      local roomMission = ::toString(roomPub?.mission) // warning disable: -declared-never-used
      ::script_net_assert("missing room_key in room")

      ::send_error_log("missing room_key in room", false, "log")
      return
    }

    local serverUrls = [];
    if ("serverURLs" in hostPub)
      serverUrls = hostPub.serverURLs
    else if ("ip" in hostPub && "port" in hostPub)
    {
      local ip = hostPub.ip
      local ipStr = string.format("%u.%u.%u.%u:%d", ip&255, (ip>>8)&255, (ip>>16)&255, ip>>24, hostPub.port)
      serverUrls.append(ipStr)
    }

    // for compatibility with old client: after all client will be updated delete check and call connect_to_host
    if ("connect_to_host_list" in ::getroottable())
      ::connect_to_host_list(serverUrls,
                        roomPub.room_key, me.private.auth_key,
                        getTblValue("sessionId", roomPub, roomId))
    else
      ::connect_to_host("ip" in hostPub ? hostPub.ip : 0,
                        "port" in hostPub ? hostPub.port : 0,
                        roomPub.room_key, me.private.auth_key,
                        getTblValue("sessionId", roomPub, roomId))

  }

  // notifications
  function onRoomInvite(notify, send_resp)
  {
    local inviteData = notify.invite_data
    if (!(typeof inviteData == "table"))
      inviteData = {}
    inviteData.roomId <- notify.roomId

    if (notify_room_invite(inviteData))
      send_resp({accept = true})
    else
      send_resp({accept = false})
  }

  function onRoomMemberJoined(member)
  {
    if (!__isNotifyForCurrentRoom(member))
      return

    dagor.debug(format("%s (%s) joined to room", member.name, member.userId.tostring()))
    __addRoomMember(member)

    notify_room_member_joined(member)
  }

  function onRoomMemberLeft(member)
  {
    if (!__isNotifyForCurrentRoom(member))
      return

    dagor.debug(format("%s (%s) left from room", member.name, member.userId.tostring()))
    __removeRoomMember(member.userId)
    notify_room_member_leaved(member)
  }

  function onRoomMemberKicked(member)
  {
    if (!__isNotifyForCurrentRoom(member))
      return

    dagor.debug(format("%s (%s) kicked from room", member.name, member.userId.tostring()))
    __removeRoomMember(member.userId)
    notify_room_member_kicked(member)
  }

  function onRoomAttrChanged(notify)
  {
    if (!__isNotifyForCurrentRoom(notify))
      return

    __mergeAttribs(notify, room)
    notify_room_attribs_changed(notify)
  }

  function onRoomMemberAttrChanged(notify)
  {
    if (!__isNotifyForCurrentRoom(notify))
      return

    __updateMemberAttributes(notify)
    notify_room_member_attribs_changed(notify)
  }

  function onRoomDestroyed(notify)
  {
    if (!__isNotifyForCurrentRoom(notify))
      return
    __cleanupRoomState()
  }

  function onHostNotify(notify)
  {
    debugTableData(notify)
    if (!__isNotifyForCurrentRoom(notify))
      return

    if (notify.hostId != hostId)
    {
      dagor.debug("warning: got host notify from host that is not in current room")
      return
    }

    if (notify.roomId != getRoomId())
    {
      dagor.debug("warning: got host notify for wrong room")
      return
    }

    if (notify.message == "connect-allowed")
    {
      isConnectAllowed = true
      __connectToHost()
    }
  }

  function onRoomJoinCb(resp)
  {
    __cleanupRoomState()

    room = resp
    roomId = room.roomId
    foreach (member in room.members)
      __addRoomMember(member)

    if (getTblValue("connect_on_join", room.public))
    {
      dagor.debug("room with auto-connect feature")
      isSelfReady = true
      __onSelfReady()
    }
  }

  function onRoomLeaveCb()
  {
    __cleanupRoomState()
  }
}

::g_mrooms_handlers <- MRoomsHandlers()

::is_my_userid <- function is_my_userid(user_id)
{
  if (typeof user_id == "string")
    return user_id == ::my_user_id_str
  return user_id == ::my_user_id_int64
}

// mrooms API

::is_host_in_room <- function is_host_in_room()
{
  return g_mrooms_handlers.hasSession()
}

::create_room <- function create_room(params, cb)
{
  if ((isPlatformXboxOne || isPlatformSony) &&
      !crossplayModule.isCrossPlayEnabled()) {
    params["crossplayRestricted"] <- true
  }

  matching_api_func("mrooms.create_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        g_mrooms_handlers.onRoomJoinCb(resp)
                      cb(resp)
                    },
                    params)
}

::destroy_room <- function destroy_room(params, cb)
{
  matching_api_func("mrooms.destroy_room", cb, params)
}

::join_room <- function join_room(params, cb)
{
  matching_api_func("mrooms.join_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        g_mrooms_handlers.onRoomJoinCb(resp)
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
  local oldRoomId = g_mrooms_handlers.getRoomId()
  g_mrooms_handlers.isLeaving = true

  matching_api_func("mrooms.leave_room",
                    function(resp)
                    {
                      if (g_mrooms_handlers.getRoomId() == oldRoomId)
                        g_mrooms_handlers.onRoomLeaveCb()
                      cb(resp)
                    },
                    params)
}

::set_member_attributes <- function set_member_attributes(params, cb)
{
  matching_api_func("mrooms.set_member_attributes", cb, params)
}

::set_room_attributes <- function set_room_attributes(params, cb)
{
  ::dagor.debug($"[PSMT] setting room attributes: {params?.public?.psnMatchId}")
  matching_api_func("mrooms.set_attributes", cb, params)
}

::kick_member <- function kick_member(params, cb)
{
  matching_api_func("mrooms.kick_from_room", cb, params)
}

::room_ban_player <- function room_ban_player(params, cb)
{
  matching_api_func("mrooms.ban_player", cb, params)
}

::room_unban_player <- function room_unban_player(params, cb)
{
  matching_api_func("mrooms.unban_player", cb, params)
}

::room_start_session <- function room_start_session(params, cb)
{
  matching_api_func("mrooms.start_session", cb, params)
}

::room_set_password <- function room_set_password(params, cb)
{
  matching_api_func("mrooms.set_password", cb, params)
}

::room_set_ready_state <- function room_set_ready_state(params, cb)
{
  matching_api_func("mrooms.set_ready_state", cb, params)
}

::invite_player_to_room <- function invite_player_to_room(params, cb)
{
  matching_api_func("mrooms.invite_player", cb, params)
}

::fetch_rooms_list <- function fetch_rooms_list(params, cb)
{
  matching_api_func("mrooms.fetch_rooms_digest2",
                    function (resp)
                    {
                      if (::checkMatchingError(resp, false))
                      {
                        foreach (room in getTblValue("digest", resp, []))
                        {
                          local hasPassword = room?.public.hasPassword
                          if (hasPassword != null)
                            room.hasPassword <- hasPassword
                        }
                      }
                      cb(resp)
                    },
                    params)
}

::serialize_dyncampaign <- function serialize_dyncampaign(params, cb)
{
  local priv = {
    dyncamp = {
      data = get_dyncampaign_b64blk()
    }
  }

  matching_api_func("mrooms.set_attributes", cb, {private = priv})
}

::get_current_room <- function get_current_room()
{
  return ::g_mrooms_handlers.getRoomId()
}

::leave_session <- function leave_session()
{
  if (::g_mrooms_handlers.getRoomId() != INVALID_ROOM_ID)
    leave_room({}, function(resp) {})
}

::is_player_room_operator <- function is_player_room_operator(user_id)
{
  return ::g_mrooms_handlers.isPlayerRoomOperator(user_id)
}

