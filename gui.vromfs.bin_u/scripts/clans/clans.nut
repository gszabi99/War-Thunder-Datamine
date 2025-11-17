from "%scripts/dagui_natives.nut" import clan_request_my_info, clan_get_exp, clan_get_my_clan_id, clan_get_my_clan_name
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanConsts.nut" import CLAN_SEASON_NUM_IN_YEAR_SHIFT
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/clans/clanState.nut" import is_in_clan, MY_CLAN_UPDATE_DELAY_MSEC, lastUpdateMyClanTime, myClanInfo

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { checkClanTagForDirtyWords, amendUGCText } = require("%scripts/clans/clanTextInfo.nut")
let { getMyClanMembers } = require("%scripts/clans/clanInfo.nut")
let { setSeenCandidatesBlk, parseSeenCandidates } = require("%scripts/clans/clanCandidates.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { handleNewMyClanData } = require("%scripts/clans/clanActions.nut")
let { getMyClanTag, getMyClanName } = require("%scripts/user/clanName.nut")

const CLAN_ID_NOT_INITED = ""

let clansPersistent = persist("clansPersistent", @() { isInRequestMyClanData  = false })
local lastClanId = CLAN_ID_NOT_INITED 
local cacheSquadronExp = 0

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

function checkClanChangedEvent() {
  if (lastClanId == clan_get_my_clan_id())
    return

  let needEvent = lastClanId != CLAN_ID_NOT_INITED
  lastClanId = clan_get_my_clan_id()
  if (needEvent)
    broadcastEvent("MyClanIdChanged")
}

function checkSquadronExpChangedEvent() {
  let curSquadronExp = clan_get_exp()
  if (cacheSquadronExp == curSquadronExp)
    return

  cacheSquadronExp = curSquadronExp
  broadcastEvent("SquadronExpChanged")
}

::requestMyClanData <- function requestMyClanData(forceUpdate = false) {
  let myClanPrevMembersUid = getMyClanMembers().map(@(m) m.uid)
  if (clansPersistent.isInRequestMyClanData)
    return

  checkClanChangedEvent()
  checkSquadronExpChangedEvent()

  let myClanId = clan_get_my_clan_id()
  if (myClanId == "-1") {
    if (myClanInfo.get()) {
      myClanInfo.set(null)
      parseSeenCandidates()
      clearClanTagForRemovedMembers(myClanPrevMembersUid, [])
      broadcastEvent("ClanInfoUpdate")
      broadcastEvent("ClanChanged") 
      updateGamercards()
    }
    return
  }

  if (!forceUpdate && (myClanInfo.get()?.id ?? "-1") == myClanId)
    if (get_time_msec() - lastUpdateMyClanTime.get() < -MY_CLAN_UPDATE_DELAY_MSEC)
      return

  lastUpdateMyClanTime.set(get_time_msec())
  let taskId = clan_request_my_info()
  clansPersistent.isInRequestMyClanData = true
  addBgTaskCb(taskId, function() {
    let wasCreated = !myClanInfo.get()
    myClanInfo.set(get_clan_info_table(true)) 

    let myClanCurrMembersUid = getMyClanMembers().map(@(m) m.uid)
    if (myClanCurrMembersUid.len() < myClanPrevMembersUid.len())
      clearClanTagForRemovedMembers(myClanPrevMembersUid, myClanCurrMembersUid)

    handleNewMyClanData()
    clansPersistent.isInRequestMyClanData = false
    broadcastEvent("ClanInfoUpdate")
    updateGamercards()
    if (wasCreated)
      broadcastEvent("ClanChanged") 
  })
}


::getFilteredClanData <- function getFilteredClanData(clanData, isUgcAllowed, author = "") {
  if (clanData?.name == clan_get_my_clan_name()) {
    clanData.name = getMyClanName()
    clanData.tag <- getMyClanTag()
  }

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
      clanData[key] = amendUGCText(clanData[key], !isUgcAllowed || isPlayerBlocked)

  return clanData
}

addListenersWithoutEnv({
  ProfileUpdated             = @(_) ::requestMyClanData()
  ScriptsReloaded            = @(_) ::requestMyClanData()

  function SignOut(_) {
    lastClanId = CLAN_ID_NOT_INITED
    setSeenCandidatesBlk(null)
    cacheSquadronExp = 0
    lastUpdateMyClanTime.set(MY_CLAN_UPDATE_DELAY_MSEC)
  }
}, g_listener_priority.DEFAULT_HANDLER)
