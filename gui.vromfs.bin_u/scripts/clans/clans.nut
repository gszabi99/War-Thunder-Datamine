from "%scripts/dagui_natives.nut" import clan_get_my_clan_tag, clan_request_my_info, clan_get_my_clan_name, clan_get_exp, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanConsts.nut" import CLAN_SEASON_NUM_IN_YEAR_SHIFT
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/clans/clanState.nut" import is_in_clan, MY_CLAN_UPDATE_DELAY_MSEC, lastUpdateMyClanTime, myClanInfo

let { g_chat } = require("%scripts/chat/chat.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { split_by_chars } = require("string")
let { get_time_msec, unixtime_to_utc_timetbl } = require("dagor.time")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { EPLX_CLAN, contactsPlayers, contactsByGroups, addContact, getContactByName,
  clanUserTable } = require("%scripts/contacts/contactsManager.nut")
let { startsWith, slice } = require("%sqstd/string.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { isPlayerNickInContacts, isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")
let { checkClanTagForDirtyWords, ps4CheckAndReplaceContentDisabledText
} = require("%scripts/clans/clanTextInfo.nut")
let { getMyClanMembers } = require("%scripts/clans/clanInfo.nut")
let { setSeenCandidatesBlk, parseSeenCandidates } = require("%scripts/clans/clanCandidates.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")

const CLAN_ID_NOT_INITED = ""

local get_my_clan_data_free = true

registerPersistentData("ClansGlobals", getroottable(),
  [
    "get_my_clan_data_free"
  ])

::g_clans <- {
  lastClanId = CLAN_ID_NOT_INITED //only for compare about clan id changed
  squadronExp = 0
}

function clearClanTagForRemovedMembers(prevUids, currUids) {
  let uidsToClean = {}
  foreach(prevUid in prevUids)
    uidsToClean[prevUid] <- prevUid

  if (currUids.len())
    foreach(currUid in currUids)
      if (currUid in uidsToClean)
        uidsToClean.rawdelete(currUid)

  if (uidsToClean.len()) {
    foreach(uid in uidsToClean)
      getContact(uid)?.update({ clanTag = "" })

    broadcastEvent(contactEvent.CONTACTS_UPDATED)
  }
}

::g_clans.checkClanChangedEvent <- function checkClanChangedEvent() {
  if (this.lastClanId == clan_get_my_clan_id())
    return

  let needEvent = this.lastClanId != CLAN_ID_NOT_INITED
  this.lastClanId = clan_get_my_clan_id()
  if (needEvent)
    broadcastEvent("MyClanIdChanged")
}

::g_clans.onEventProfileUpdated <- function onEventProfileUpdated(_p) {
  ::requestMyClanData()
}

::g_clans.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  ::requestMyClanData()
}

::g_clans.onEventSignOut <- function onEventSignOut(_p) {
  this.lastClanId = CLAN_ID_NOT_INITED
  setSeenCandidatesBlk(null)
  this.squadronExp = 0
  lastUpdateMyClanTime.set(MY_CLAN_UPDATE_DELAY_MSEC)
}

::g_clans.getClanPlaceRewardLogData <- function getClanPlaceRewardLogData(clanData, maxCount = -1) {
  return this.getRewardLogData(clanData, "rewardLog", maxCount)
}

::g_clans.getRewardLogData <- function getRewardLogData(clanData, rewardId, maxCount) {
  let list = []
  local count = 0

  foreach (seasonReward in clanData[rewardId]) {
    local params = {
      iconStyle  = seasonReward.iconStyle()
      iconConfig = seasonReward.iconConfig()
      iconParams = seasonReward.iconParams()
      name = seasonReward.name()
      desc = seasonReward.desc()
    }

    params = params.__merge({
      bestRewardsConfig = { seasonName = seasonReward.seasonIdx, title = seasonReward.seasonTitle }
    })
    list.append(params)

    if (maxCount != -1 && ++count == maxCount)
      break
  }
  return list
}

::g_clans.checkSquadronExpChangedEvent <- function checkSquadronExpChangedEvent() {
  let curSquadronExp = clan_get_exp()
  if (this.squadronExp == curSquadronExp)
    return

  this.squadronExp = curSquadronExp
  broadcastEvent("SquadronExpChanged")
}

function handleNewMyClanData() {
  parseSeenCandidates()
  contactsByGroups[EPLX_CLAN] <- {}
  let myClanInfoV = myClanInfo.get()
  if ("members" not in myClanInfoV)
    return

  let res = {}
  foreach (_mem, block in myClanInfoV.members) {
    if (!(block.uid in contactsPlayers))
      getContact(block.uid, block.nick)

    let contact = contactsPlayers[block.uid]
    if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
      contact.presence = ::getMyClanMemberPresence(block.nick)

    if (userIdStr.value != block.uid)
      addContact(contact, EPLX_CLAN)

    res[block.nick] <- myClanInfoV.tag
  }

  if (res.len() > 0)
    clanUserTable.mutate(@(v) v.__update(res))
}

::requestMyClanData <- function requestMyClanData(forceUpdate = false) {
  let myClanPrevMembersUid = getMyClanMembers().map(@(m) m.uid)
  if (!get_my_clan_data_free)
    return

  ::g_clans.checkClanChangedEvent()
  ::g_clans.checkSquadronExpChangedEvent()

  let myClanId = clan_get_my_clan_id()
  if (myClanId == "-1") {
    if (myClanInfo.get()) {
      myClanInfo.set(null)
      parseSeenCandidates()
      clearClanTagForRemovedMembers(myClanPrevMembersUid, [])
      broadcastEvent("ClanInfoUpdate")
      broadcastEvent("ClanChanged") //i.e. dismissed
      ::update_gamercards()
    }
    return
  }

  if (!forceUpdate && (myClanInfo.get()?.id ?? "-1") == myClanId)
    if (get_time_msec() - lastUpdateMyClanTime.get() < -MY_CLAN_UPDATE_DELAY_MSEC)
      return

  lastUpdateMyClanTime.set(get_time_msec())
  let taskId = clan_request_my_info()
  get_my_clan_data_free = false
  addBgTaskCb(taskId, function() {
    let wasCreated = !myClanInfo.get()
    myClanInfo.set(get_clan_info_table())

    let myClanCurrMembersUid = getMyClanMembers().map(@(m) m.uid)
    if (myClanCurrMembersUid.len() < myClanPrevMembersUid.len())
      clearClanTagForRemovedMembers(myClanPrevMembersUid, myClanCurrMembersUid)

    handleNewMyClanData()
    get_my_clan_data_free = true
    broadcastEvent("ClanInfoUpdate")
    ::update_gamercards()
    if (wasCreated)
      broadcastEvent("ClanChanged") //i.e created
  })
}

function getSeasonName(blk) {
  local name = ""
  if (blk?.type == "worldWar")
    name = loc($"worldwar/season_name/{split_by_chars(blk.titles, "@")?[2] ?? ""}")
  else {
    let year = unixtime_to_utc_timetbl(blk?.seasonStartTimestamp ?? 0).year.tostring()
    let num  = get_roman_numeral(to_integer_safe(blk?.numInYear ?? 0)
      + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    name = loc("clan/battle_season/name", { year = year, num = num })
  }
  return name
}

class ClanSeasonTitle {
  clanTag = ""
  clanName = ""
  seasonName = ""
  seasonTime = 0
  difficultyName = ""


  constructor (...) {
    assert(false, "Error: attempt to instantiate ClanSeasonTitle intreface class.")
  }

  function getBattleTypeTitle() {
    let difficulty = g_difficulty.getDifficultyByEgdLowercaseName(this.difficultyName)
    return loc(difficulty.abbreviation)
  }

  function getUpdatedClanInfo(unlockBlk) {
    local isMyClan = is_in_clan() && (unlockBlk?.clanId ?? "").tostring() == clan_get_my_clan_id()
    return {
      clanTag  = isMyClan ? clan_get_my_clan_tag()  : unlockBlk?.clanTag
      clanName = isMyClan ? clan_get_my_clan_name() : unlockBlk?.clanName
    }
  }

  function name() {}
  function desc() {}
  function iconStyle() {}
  function iconParams() {}
}


::ClanSeasonPlaceTitle <- class (ClanSeasonTitle) {
  place = ""
  seasonType = ""
  seasonTag = null
  seasonIdx = ""
  seasonTitle = ""

  static function createFromClanReward (titleString, sIdx, season, clanData) {
    let titleParts = split_by_chars(titleString, "@")
    let place = getTblValue(0, titleParts, "")
    let difficultyName = getTblValue(1, titleParts, "")
    let sTag = titleParts?[2]
    return ::ClanSeasonPlaceTitle(
      season?.t,
      season?.type,
      sTag,
      difficultyName,
      place,
      getSeasonName(season),
      clanData.tag,
      clanData.name,
      sIdx,
      titleString
    )
  }


  static function createFromUnlockBlk (unlockBlk) {
    let idParts = split_by_chars(unlockBlk.id, "_")
    let info = ::ClanSeasonPlaceTitle.getUpdatedClanInfo(unlockBlk)
    return ::ClanSeasonPlaceTitle(
      unlockBlk?.t,
      "",
      null,
      unlockBlk?.rewardForDiff,
      idParts[0],
      getSeasonName(unlockBlk),
      info.clanTag,
      info.clanName,
      "",
      ""
    )
  }


  constructor (
    v_seasonTime,
    v_seasonType,
    v_seasonTag,
    v_difficlutyName,
    v_place,
    v_seasonName,
    v_clanTag,
    v_clanName,
    v_seasonIdx,
    v_seasonTitle
  ) {
    this.seasonTime = v_seasonTime
    this.seasonType = v_seasonType
    this.seasonTag = v_seasonTag
    this.difficultyName = v_difficlutyName
    this.place = v_place
    this.seasonName = v_seasonName
    this.clanTag = v_clanTag
    this.clanName = v_clanName
    this.seasonIdx = v_seasonIdx
    this.seasonTitle = v_seasonTitle
  }

  function isWinner() {
    return startsWith(this.place, "place")
  }

  function getPlaceTitle() {
    if (this.isWinner())
      return loc($"clan/season_award/place/{this.place}")
    else
      return loc("clan/season_award/place/top", { top = slice(this.place, 3) })
  }

  function name() {
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/title" : "clan/season_award/title"
    return loc(
      path,
      {
        achievement = this.getPlaceTitle()
        battleType = this.getBattleTypeTitle()
        season = this.seasonName
      }
    )
  }

  function desc() {
    let placeTitleColored = colorize("activeTextColor", this.getPlaceTitle())
    let params = {
      place = placeTitleColored
      top = placeTitleColored
      squadron = colorize("activeTextColor", nbsp.concat(this.clanTag, this.clanName))
      season = colorize("activeTextColor", this.seasonName)
    }
    let winner = this.isWinner() ? "place" : "top"
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/desc/" : "clan/season_award/desc/"

    return loc("".concat(path, winner), this.seasonType == "worldWar"
      ? params
      : params.__merge({ battleType = colorize("activeTextColor", this.getBattleTypeTitle()) }))
  }

  function iconStyle() {
    return $"clan_medal_{this.place}_{this.difficultyName}"
  }

  function iconConfig() {
    if (this.seasonType != "worldWar" || !this.seasonTag)
      return null

    let bg_img = "clan_medal_ww_bg"
    let path = this.isWinner() ? this.place : "rating"
    let bin_img = $"clan_medal_ww_{this.seasonTag}_bin_{path}"
    local place_img =$"clan_medal_ww_{this.place}"
    return ";".join([bg_img, bin_img, place_img], true)
  }

  function iconParams() {
    return { season_title = { text = this.seasonName } }
  }
}

// Warning! getFilteredClanData() actualy mutates its parameter and returns it back
::getFilteredClanData <- function getFilteredClanData(clanData, author = "") {
  if ("tag" in clanData)
    clanData.tag = checkClanTagForDirtyWords(clanData.tag)

  let textFields = [
    "name"
    "desc"
    "slogan"
    "announcement"
    "region"
  ]

  local isPlayerBlocked = false
  if (isPlatformSony) {
    //Try get author of changes from incomming clanData
    if (author == "") {
      author = clanData?.changedByNick ?? ""
      if (author == "") {
        let uid = clanData?.creator_uid ?? clanData?.changed_by_uid ?? clanData?.changedByUid ?? ""
        if (uid != "")
          author = getContact(uid)?.name ?? ""
      }
    }

    isPlayerBlocked = isPlayerNickInContacts(author, EPL_BLOCKLIST)
    if (isPlayerBlocked)
      textFields.append("tag")
  }

  foreach (key in textFields)
    if (key in clanData)
      clanData[key] = ps4CheckAndReplaceContentDisabledText(clanData[key], isPlayerBlocked)

  return clanData
}

::getMyClanMemberPresence <- function getMyClanMemberPresence(nick) {
  let clanActiveUsers = []

  foreach (roomData in g_chat.rooms)
    if (g_chat.isRoomClan(roomData.id) && roomData.users.len() > 0) {
      foreach (user in roomData.users)
        clanActiveUsers.append(user.name)
      break
    }

  if (isInArray(nick, clanActiveUsers)) {
    let contact = getContactByName(nick)
    if (!(contact?.forceOffline ?? false))
      return contactPresence.ONLINE
  }
  return contactPresence.OFFLINE
}

subscribe_handler(::g_clans, g_listener_priority.DEFAULT_HANDLER)