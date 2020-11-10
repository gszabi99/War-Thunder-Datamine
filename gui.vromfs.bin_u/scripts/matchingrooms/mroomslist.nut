local crossplayModule = require("scripts/social/crossplay.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local u = require("std/underscore.nut")

const ROOM_LIST_REFRESH_MIN_TIME = 3000 //ms
const ROOM_LIST_REQUEST_TIME_OUT = 45000 //ms
const ROOM_LIST_TIME_OUT = 180000
const MAX_SESSIONS_LIST_LEN = 1000
const SKIRMISH_ROOMS_LIST_ID = "skirmish"

::MRoomsList <- class
{
  id = ""
  roomsList = null
  requestParams = null

  lastUpdateTimeMsec = - ROOM_LIST_TIME_OUT
  lastRequestTimeMsec = - ROOM_LIST_REQUEST_TIME_OUT
  isInUpdate = false
  curRoomsFilter = null
  queuedRoomsFilter = null

  static mRoomsListById = {}

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  static function getMRoomsListByRequestParams(requestParams)
  {
    local roomsListId = SKIRMISH_ROOMS_LIST_ID //empty request params is a skirmish
    if ("eventEconomicName" in requestParams)
      roomsListId = "economicName:" + requestParams.eventEconomicName

    local listById = ::MRoomsList.mRoomsListById
    if (!(roomsListId in listById))
      listById[roomsListId] <- ::MRoomsList(roomsListId, requestParams)
    return listById[roomsListId]
  }

  constructor(roomsListId, request)
  {
    id = roomsListId
    roomsList = []
    requestParams = request || {}
  }


  function isNewest() {
    return !isInUpdate && ::dagor.getCurTime() - lastUpdateTimeMsec < ROOM_LIST_REFRESH_MIN_TIME
  }

  function isThrottled(curTime) {
    return ((curTime - lastUpdateTimeMsec < ROOM_LIST_REFRESH_MIN_TIME) ||
            (curTime - lastRequestTimeMsec < ROOM_LIST_REFRESH_MIN_TIME))
  }

  function isUpdateTimedout(curTime) {
    return curTime - lastRequestTimeMsec >= ROOM_LIST_REQUEST_TIME_OUT
  }

  function validateList()
  {
    if (::dagor.getCurTime() - lastUpdateTimeMsec >= ROOM_LIST_TIME_OUT)
      roomsList.clear()
  }

  function getList()
  {
    validateList()
    return roomsList
  }

  function getRoom(roomId)
  {
    return ::u.search(getList(), (@(roomId) function(r) { return r.roomId == roomId })(roomId))
  }

  function requestList(filter)
  {
    local roomsFilter = getFetchRoomsParams(filter)
    local curTime = ::dagor.getCurTime()
    if (isUpdateTimedout(curTime))
      isInUpdate = false

    if (isThrottled(curTime) || isInUpdate) {
      if (!u.isEqual(roomsFilter, curRoomsFilter)) {
        if (isInUpdate) {
          queuedRoomsFilter = roomsFilter
          return false
        }
      }
      else
        return false
    }

    isInUpdate = true
    lastRequestTimeMsec = curTime

    curRoomsFilter = roomsFilter
    local hideFullRooms = filter?.hideFullRooms ?? true
    local roomsData = this
    ::fetch_rooms_list(roomsFilter, @(p) roomsData.requestListCb(p, hideFullRooms))
    ::broadcastEvent("RoomsSearchStarted", { roomsList = this })
    return true
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function requestListCb(p, hideFullRooms)
  {
    isInUpdate = false

    local digest = ::checkMatchingError(p, false) ? ::getTblValue("digest", p) : null
    if (!digest)
      return

    lastUpdateTimeMsec = ::dagor.getCurTime()
    updateRoomsList(digest, hideFullRooms)
    ::broadcastEvent("SearchedRoomsChanged", { roomsList = this })

    if (queuedRoomsFilter != null) {
      requestList(queuedRoomsFilter)
      queuedRoomsFilter = null
    }
  }

  function setPlatformFilter(filter) {
    if (isPlatformXboxOne) {
      if (!crossplayModule.isCrossPlayEnabled()) {
        filter["public/platformRestriction"] <- {
          test = "eq"
          value = "xboxOne"
        }
      }
      else {
        filter["public/platformRestriction"] <- {
          test = "in"
          value = ["xboxOne", null]
        }
      }
    }
    else if (isPlatformSony) {
      if (!crossplayModule.isCrossPlayEnabled()) {
        filter["public/platformRestriction"] <- {
          test = "eq"
          value = "ps4"
        }
      }
      else {
        filter["public/platformRestriction"] <- {
          test = "in"
          value = ["ps4", null]
        }
      }
    }
    else {
      filter["public/platformRestriction"] <- {
        test = "eq"
        value = null // only non-restricted rooms will be passed
      }
    }
  }

  function getFetchRoomsParams(ui_filter)
  {
    local filter = {}
    local res = {
      group = "custom-lobby" // "xbox-lobby" for xbox
      filter = filter

      // TODO: implement paging in client
      cursor = 0
      count = 100
    }

    local diff = ui_filter?.diff
    if (diff != null && diff != -1) {
      filter["public/mission/difficulty"] <- {
        test = "eq"
        value = ::g_difficulty.getDifficultyByDiffCode(diff).name
      }
    }
    local clusters = ui_filter?.clusters
    if (typeof(clusters) == "array" && clusters.len() > 0) {
      filter["public/cluster"] <- {
        test = "in"
        value = clusters
      }
    }

    if ("eventEconomicName" in requestParams) {
      local economicName = requestParams.eventEconomicName
      local modesList = ::g_matching_game_modes.getGameModeIdsByEconomicName(economicName)
      res.group = "matching-lobby"

      if (modesList.len()) {
        filter["public/game_mode_id"] <-
            {
              test = "in"
              value = modesList
            }
      }
      else {
        ::assertf_once("no gamemodes for mrooms", "Error: cant find any gamemodes by economic name: " + economicName)
        filter["public/game_mode_name"] <-
            {
              test = "eq"
              value =  economicName
            }
      }
    }
    setPlatformFilter(filter)
    return res
  }

  function updateRoomsList(rooms, hideFullRooms) //can be called each update
  {
    if (rooms.len() > MAX_SESSIONS_LIST_LEN)
    {
      local message = ::format("Error in SessionLobby::updateRoomsList:\nToo long rooms list - %d", rooms.len())
      ::script_net_assert_once("too long rooms list", message)

      rooms.resize(MAX_SESSIONS_LIST_LEN)
    }

    roomsList.clear()
    foreach(room in rooms)
      if (isRoomVisible(room, hideFullRooms))
        roomsList.append(room)
  }

  function isRoomVisible(room, hideFullRooms)
  {
    local userUid = ::SessionLobby.getRoomCreatorUid(room)
    if (userUid && ::isPlayerInContacts(userUid, ::EPL_BLOCKLIST))
      return false

    if (hideFullRooms) {
      local mission = room?.public.mission ?? {}
      if (::SessionLobby.getRoomMembersCnt(room) >= (mission?.maxPlayers ?? 0))
        return false
    }
    return ::SessionLobby.getMisListType(room.public).canJoin(::GM_SKIRMISH)
  }
}
