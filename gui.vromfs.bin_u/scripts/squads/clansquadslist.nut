//checked for plus_string
from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *


let { get_time_msec } = require("dagor.time")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { matchingApiFunc } = require("%scripts/matching/api.nut")

const CLAN_SQUADS_LIST_REFRESH_MIN_TIME = 3000 //ms
const CLAN_SQUADS_LIST_REQUEST_TIME_OUT = 45000 //ms
const CLAN_SQUADS_LIST_TIME_OUT = 180000
const MAX_SQUADS_LIST_LEN = 100

local ClanSquadsList = class {

  clanSquadsList = []
  clanId = ""
  lastUpdateTimeMsec = -CLAN_SQUADS_LIST_TIME_OUT
  lastRequestTimeMsec = -CLAN_SQUADS_LIST_REQUEST_TIME_OUT
  isInUpdate = false

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  function isNewest() {
    return (this.clanId == clan_get_my_clan_id()) && !this.isInUpdate
             && get_time_msec() - this.lastUpdateTimeMsec < CLAN_SQUADS_LIST_REFRESH_MIN_TIME
  }

  function canRequestByTime() {
    let checkTime = this.isInUpdate ? CLAN_SQUADS_LIST_REQUEST_TIME_OUT
      : CLAN_SQUADS_LIST_REFRESH_MIN_TIME
    return  get_time_msec() - this.lastRequestTimeMsec >= checkTime
  }

  function canRequest() {
    return !this.isNewest() && this.canRequestByTime()
  }

  function isListValid() {
    return ((this.clanId == clan_get_my_clan_id())
      && (get_time_msec() - this.lastUpdateTimeMsec < CLAN_SQUADS_LIST_TIME_OUT))
  }

  function validateList() {
    if (!this.isListValid())
      this.clanSquadsList.clear()
  }

  function getList() {
    this.validateList()
    this.requestList()

    return this.clanSquadsList
  }

  function requestList() {
    if (!this.canRequest())
      return false

    this.isInUpdate = true
    this.lastRequestTimeMsec = get_time_msec()

    let requestClanId = clan_get_my_clan_id()
    let cb = Callback(@(resp) this.requestListCb(resp, requestClanId), this)

    matchingApiFunc("msquad.get_squads", cb, { players = this.getClanUidsList() })
    return true
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function getClanUidsList() {
    let clanPlayersUid = []
    foreach (member in ::g_clans.getMyClanMembers()) {
      let memberUid = member?.uid
      if (memberUid)
       clanPlayersUid.append(memberUid.tointeger())
    }
    return clanPlayersUid
  }

  function requestListCb(p, requestClanId) {
    this.isInUpdate = false
    this.clanId = requestClanId

    let squads = ::checkMatchingError(p, false) ? (p?.squads) : null
    if (!squads)
      return

    this.lastUpdateTimeMsec = get_time_msec()
    this.updateClanSquadsList(squads)
    broadcastEvent("ClanSquadsListChanged", { clanSquadsList = this.clanSquadsList })
  }

  function updateClanSquadsList(squads) { //can be called each update
    if (squads.len() > MAX_SQUADS_LIST_LEN) {
      let message = format("Error in clanSquads::updateClanSquadsList:\nToo long clan squads list - %d",
                                squads.len())
      script_net_assert_once("too long clan squads list", message)

      squads.resize(MAX_SQUADS_LIST_LEN)
    }

    this.clanSquadsList.clear()
    foreach (squad in squads)
      this.clanSquadsList.append(squad)
  }

}

return ClanSquadsList()