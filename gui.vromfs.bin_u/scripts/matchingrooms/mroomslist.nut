from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let { checkMatchingError } = require("%scripts/matching/api.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { get_time_msec } = require("dagor.time")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let u = require("%sqstd/underscore.nut")
let { fetchRoomsList } = require("%scripts/matching/serviceNotifications/mroomsApi.nut")
let { getGameModeIdsByEconomicName } = require("%scripts/matching/matchingGameModes.nut")
let { isPlayerInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { getRoomMembersCnt, getRoomCreatorUid } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getMisListType } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")

const ROOM_LIST_REFRESH_MIN_TIME = 3000 
const ROOM_LIST_REQUEST_TIME_OUT = 45000 
const ROOM_LIST_TIME_OUT = 180000
const MAX_SESSIONS_LIST_LEN = 1000
const SKIRMISH_ROOMS_LIST_ID = "skirmish"

local MRoomsList = null
MRoomsList = class {
  id = ""
  roomsList = null
  requestParams = null

  lastUpdateTimeMsec = -ROOM_LIST_TIME_OUT
  lastRequestTimeMsec = -ROOM_LIST_REQUEST_TIME_OUT
  isInUpdate = false
  curRoomsFilter = null
  queuedRoomsFilter = null

  static mRoomsListById = {}





  static function getMRoomsListByRequestParams(requestParams) {
    local roomsListId = SKIRMISH_ROOMS_LIST_ID 
    if ("eventEconomicName" in requestParams)
      roomsListId = $"economicName:{requestParams.eventEconomicName}"

    let listById = MRoomsList.mRoomsListById
    if (!(roomsListId in listById))
      listById[roomsListId] <- MRoomsList(roomsListId, requestParams)
    return listById[roomsListId]
  }

  constructor(roomsListId, request) {
    this.id = roomsListId
    this.roomsList = []
    this.requestParams = request ?? {}
  }


  function isNewest() {
    return !this.isInUpdate && get_time_msec() - this.lastUpdateTimeMsec < ROOM_LIST_REFRESH_MIN_TIME
  }

  function isThrottled(curTime) {
    return ((curTime - this.lastUpdateTimeMsec < ROOM_LIST_REFRESH_MIN_TIME) ||
            (curTime - this.lastRequestTimeMsec < ROOM_LIST_REFRESH_MIN_TIME))
  }

  function isUpdateTimedout(curTime) {
    return curTime - this.lastRequestTimeMsec >= ROOM_LIST_REQUEST_TIME_OUT
  }

  function validateList() {
    if (get_time_msec() - this.lastUpdateTimeMsec >= ROOM_LIST_TIME_OUT)
      this.roomsList.clear()
  }

  function getList() {
    this.validateList()
    return this.roomsList
  }

  function getRoom(roomId) {
    return this.getList().findvalue(@(r) r.roomId == roomId)
  }

  function requestList(filter) {
    let roomsFilter = this.getFetchRoomsParams(filter)
    let curTime = get_time_msec()
    if (this.isUpdateTimedout(curTime))
      this.isInUpdate = false

    if (this.isThrottled(curTime) || this.isInUpdate) {
      if (!u.isEqual(roomsFilter, this.curRoomsFilter)) {
        if (this.isInUpdate) {
          this.queuedRoomsFilter = roomsFilter
          return false
        }
      }
      else
        return false
    }

    this.isInUpdate = true
    this.lastRequestTimeMsec = curTime

    this.curRoomsFilter = roomsFilter
    let hideFullRooms = filter?.hideFullRooms ?? true
    let roomsData = this
    fetchRoomsList(roomsFilter, @(p) roomsData.requestListCb(p, hideFullRooms))
    broadcastEvent("RoomsSearchStarted", { roomsList = this })
    return true
  }





  function requestListCb(p, hideFullRooms) {
    this.isInUpdate = false

    let digest = checkMatchingError(p, false) ? getTblValue("digest", p) : null
    if (!digest)
      return

    this.lastUpdateTimeMsec = get_time_msec()
    this.updateRoomsList(digest, hideFullRooms)
    broadcastEvent("SearchedRoomsChanged", { roomsList = this })

    if (this.queuedRoomsFilter != null) {
      this.requestList(this.queuedRoomsFilter)
      this.queuedRoomsFilter = null
    }
  }

  function setPlatformFilter(filter) {
    if (is_gdk) {
      if (!crossplayModule.isCrossPlayEnabled()) {
        filter["public/platformRestriction"] <- {
          test = "in"
          value = ["xbox", "pc_ms_live"]
        }
      }
      else {
        filter["public/platformRestriction"] <- {
          test = "in"
          value = ["xbox", "pc_ms_live", null]
        }
      }
    }
    else if (isPlatformSony) {
      if (!crossplayModule.isCrossPlayEnabled()) {
        filter["public/platformRestriction"] <- {
          test = "eq"
          value = "ps"
        }
      }
      else {
        filter["public/platformRestriction"] <- {
          test = "in"
          value = ["ps", null]
        }
      }
    }
    else {
      filter["public/platformRestriction"] <- {
        test = "eq"
        value = null 
      }
    }
  }

  function getFetchRoomsParams(ui_filter) {
    let filter = {}
    let res = {
      group = "custom-lobby" 
      filter = filter

      
      cursor = 0
      count = 100
    }

    let diff = ui_filter?.diff
    if (diff != null && diff != -1) {
      filter["public/mission/difficulty"] <- {
        test = "eq"
        value = g_difficulty.getDifficultyByDiffCode(diff).name
      }
    }
    let clusters = ui_filter?.clusters
    if (type(clusters) == "array" && clusters.len() > 0) {
      filter["public/cluster"] <- {
        test = "in"
        value = clusters
      }
    }

    if ("eventEconomicName" in this.requestParams) {
      let economicName = this.requestParams.eventEconomicName
      let modesList = getGameModeIdsByEconomicName(economicName)
      res.group = "matching-lobby"

      if (modesList.len()) {
        filter["public/game_mode_id"] <-
            {
              test = "in"
              value = modesList
            }
      }
      else {
        script_net_assert_once("no gamemodes for mrooms", $"Error: cant find any gamemodes by economic name: {economicName}")
        filter["public/game_mode_name"] <-
            {
              test = "eq"
              value =  economicName
            }
      }
    }
    this.setPlatformFilter(filter)
    return res
  }

  function updateRoomsList(rooms, hideFullRooms) { 
    if (rooms.len() > MAX_SESSIONS_LIST_LEN) {
      let message = format("Error in SessionLobby.updateRoomsList:\nToo long rooms list - %d", rooms.len())
      script_net_assert_once("too long rooms list", message)

      rooms.resize(MAX_SESSIONS_LIST_LEN)
    }

    this.roomsList.clear()
    foreach (room in rooms)
      if (this.isRoomVisible(room, hideFullRooms))
        this.roomsList.append(room)
  }

  function isRoomVisible(room, hideFullRooms) {
    let userUid = getRoomCreatorUid(room)
    if (userUid && isPlayerInContacts(userUid, EPL_BLOCKLIST))
      return false

    if (hideFullRooms) {
      let mission = room?.public.mission ?? {}
      if (getRoomMembersCnt(room) >= (mission?.maxPlayers ?? 0))
        return false
    }
    return getMisListType(room.public).canJoin(GM_SKIRMISH)
  }
}

return MRoomsList