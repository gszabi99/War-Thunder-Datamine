from "%scripts/dagui_natives.nut" import get_dyncampaign_b64blk
from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { checkMatchingError, matchingApiFunc } = require("%scripts/matching/api.nut")
let { roomState, cleanupRoomState, addRoomMember, onSelfReady } = require("%scripts/matching/serviceNotifications/mroomsState.nut")

function onRoomJoinCb(resp) {
  cleanupRoomState()

  roomState.room = resp
  roomState.roomId = roomState.room?.roomId
  foreach (member in (roomState.room?.members ?? []))
    addRoomMember(member)

  if (getTblValue("connect_on_join", roomState.room?.public)) {
    log("room with auto-connect feature")
    roomState.isSelfReady = true
    onSelfReady()
  }
}

function onRoomLeaveCb() {
  cleanupRoomState()
}

function requestCreateRoom(params, cb) {
  if ((is_gdk || isPlatformSony)
      && !crossplayModule.isCrossPlayEnabled()) {
    params["crossplayRestricted"] <- true
  }

  matchingApiFunc("mrooms.create_room",
    function(resp) {
      if (checkMatchingError(resp, false))
        onRoomJoinCb(resp)
      cb(resp)
    },
    params)
}

function requestDestroyRoom(params, cb) {
  matchingApiFunc("mrooms.destroy_room", cb, params)
}

function requestJoinRoom(params, cb) {
  matchingApiFunc("mrooms.join_room",
    function(resp) {
      if (checkMatchingError(resp, false))
        onRoomJoinCb(resp)
      else {
        resp.roomId <- params?.roomId
        resp.password <- params?.password
      }
      cb(resp)
    },
    params)
}

function requestLeaveRoom(params, cb) {
  let oldRoomId = roomState.roomId
  roomState.isLeaving = true

  matchingApiFunc("mrooms.leave_room",
    function(resp) {
      if (roomState.roomId == oldRoomId)
        onRoomLeaveCb()
      cb(resp)
    },
    params)
}

function setMemberAttributes(params, cb) {
  matchingApiFunc("mrooms.set_member_attributes", cb, params)
}

function setRoomAttributes(params, cb) {
  log($"[PSMT] setting room attributes: {params?.public.psnMatchId}")
  matchingApiFunc("mrooms.set_attributes", cb, params)
}

function kickMember(params, cb) {
  matchingApiFunc("mrooms.kick_from_room", cb, params)
}

function roomStartSession(params, cb) {
  matchingApiFunc("mrooms.start_session", cb, params)
}

function roomSetPassword(params, cb) {
  matchingApiFunc("mrooms.set_password", cb, params)
}

function roomSetReadyState(params, cb) {
  matchingApiFunc("mrooms.set_ready_state", cb, params)
}

function invitePlayerToRoom(params, cb) {
  matchingApiFunc("mrooms.invite_player", cb, params)
}

function fetchRoomsList(params, cb) {
  matchingApiFunc("mrooms.fetch_rooms_digest2",
    function (resp) {
      if (checkMatchingError(resp, false)) {
        foreach (room in getTblValue("digest", resp, [])) {
          let hasPassword = room?.public.hasPassword
          if (hasPassword != null)
            room.hasPassword <- hasPassword
        }
      }
      cb(resp)
    },
    params)
}

function serializeDyncampaign(cb) {
  let priv = {
    dyncamp = {
      data = get_dyncampaign_b64blk()
    }
  }

  matchingApiFunc("mrooms.set_attributes", cb, { private = priv })
}

return {
  requestCreateRoom
  requestDestroyRoom
  requestJoinRoom
  requestLeaveRoom
  setMemberAttributes
  setRoomAttributes
  kickMember
  roomStartSession
  roomSetPassword
  roomSetReadyState
  invitePlayerToRoom
  fetchRoomsList
  serializeDyncampaign
}
