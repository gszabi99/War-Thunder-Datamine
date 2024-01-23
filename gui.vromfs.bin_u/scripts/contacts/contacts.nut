//-file:plus-string
from "%scripts/dagui_natives.nut" import get_nicks_find_result_blk, find_nicks_by_prefix
from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/squads/squadsConsts.nut" import squadMemberState

let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { isEqual } = u
let { EPLX_PS4_FRIENDS, contactsPlayers, contactsByGroups
} = require("%scripts/contacts/contactsManager.nut")
let { requestUserInfoData } = require("%scripts/user/usersInfoManager.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { addTask } = require("%scripts/tasker.nut")

::g_contacts <- {
  findContactByPSNId = @(psnId) contactsPlayers.findvalue(@(player) player.psnId == psnId)
}

foreach (fn in [
    "contactPresence.nut"
    "contact.nut"
    "playerStateTypes.nut"
    "contactsHandler.nut"
    "searchForSquadHandler.nut"
  ])
  loadOnce("%scripts/contacts/" + fn)

::g_contacts.onEventUserInfoManagerDataUpdated <- function onEventUserInfoManagerDataUpdated(params) {
  let usersInfoData = getTblValue("usersInfo", params, null)
  if (usersInfoData == null)
    return

  ::update_contacts_by_list(usersInfoData)
}

::g_contacts.onEventUpdateExternalsIDs <- function onEventUpdateExternalsIDs(params) {
  if (!(params?.request?.uid) || !(params?.externalIds))
    return

  let config = params.externalIds
  config.uid <- params.request.uid
  if (params?.request?.afterSuccessUpdateFunc)
    config.afterSuccessUpdateFunc <- params.request.afterSuccessUpdateFunc

  ::updateContact(config)
}

::g_contacts.getPlayerFullName <- function getPlayerFullName(name, clanTag = "", addInfo = "") {
  return nbsp.join([hasFeature("Clans") ? clanTag : "", utf8(name), addInfo], true)
}

::missed_contacts_data <- {}

::getContactsGroupUidList <- function getContactsGroupUidList(groupName) {
  let res = []
  if (!(groupName in contactsByGroups))
    return res
  return contactsByGroups[groupName].keys()
}

::isPlayerInContacts <- function isPlayerInContacts(uid, groupName) {
  if (!(groupName in contactsByGroups) || u.isEmpty(uid))
    return false
  return uid in contactsByGroups[groupName]
}

::isPlayerNickInContacts <- function isPlayerNickInContacts(nick, groupName) {
  if (!(groupName in contactsByGroups))
    return false
  foreach (p in contactsByGroups[groupName])
    if (p.name == nick)
      return true
  return false
}

::can_add_player_to_contacts_list <- function can_add_player_to_contacts_list(groupName) {
  if (contactsByGroups[groupName].len() < EPL_MAX_PLAYERS_IN_LIST)
    return true

  showInfoMsgBox(
    format(loc("msg/cant_add/too_many_contacts"), EPL_MAX_PLAYERS_IN_LIST),
    "cant_add_contact"
  )

  return false
}

::find_contact_by_name_and_do <- function find_contact_by_name_and_do(playerName, func) { //return taskId if delayed.
  let contact = ::Contact.getByName(playerName)
  if (contact && contact?.uid != "") {
    func(contact)
    return null
  }

  let taskCallback = function(result = YU2_OK) {
    if (!func)
      return

    if (result == YU2_OK) {
      local searchRes = DataBlock()
      searchRes = get_nicks_find_result_blk()
      foreach (uid, nick in searchRes)
        if (nick == playerName) {
          func(::getContact(uid, playerName))
          return
        }
    }

    func(null)
    showInfoMsgBox(loc("chat/error/item-not-found", { nick = getPlayerName(playerName) }), "incorrect_user")
  }

  let taskId = find_nicks_by_prefix(playerName, 1, false)
  addTask(taskId, null, taskCallback, taskCallback)
  return taskId
}

::getContact <- function getContact(uid, nick = null, clanTag = null, forceUpdate = false) {
  if (!uid)
    return null

  if (hasFeature("ProfileIconInContact"))
    requestUserInfoData(uid)

  if (!(uid in contactsPlayers)) {
    if (nick != null) {
      let contact = ::Contact({ name = nick, uid = uid })
      contactsPlayers[uid] <- contact
      if (uid in ::missed_contacts_data)
        contact.update(::missed_contacts_data.$rawdelete(uid))
      contact.updateMuteStatus()
    }
    else
      return null
  }

  let contact = contactsPlayers[uid]
  if (nick != null && (forceUpdate || contact.name == ""))
    contact.name = nick

  if (clanTag != null && (forceUpdate || !isEqual(contact.clanTag, clanTag)))
    contact.setClanTag(clanTag)

  return contact
}

::update_contacts_by_list <- function update_contacts_by_list(list, needEvent = true) {
    foreach (config in list)
      ::updateContact(config)

  if (needEvent)
    broadcastEvent(contactEvent.CONTACTS_UPDATED)
}

::updateContact <- function updateContact(config) {
  let configIsContact = u.isInstance(config) && config instanceof ::Contact
  if (u.isInstance(config) && !configIsContact) { //Contact no need update by instances because foreach use function as so constructor
    script_net_assert_once("strange config for contact update", "strange config for contact update")
    return null
  }

  let uid = config.uid
  let contact = ::getContact(uid, config?.name)
  if (!contact)
    return null

  //when config is instance of contact we no need update it to self
  if (!configIsContact) {
    if (config?.needReset ?? false)
      contact.resetMatchingParams()

    contact.update(config)
  }

  //update presence
  local presence = ::g_contact_presence.UNKNOWN
  if (contact.online)
    presence = ::g_contact_presence.ONLINE
  else if (!contact.unknown)
    presence = ::g_contact_presence.OFFLINE

  let squadStatus = ::g_squad_manager.getPlayerStatusInMySquad(uid)
  if (squadStatus == squadMemberState.NOT_IN_SQUAD) {
    if (contact.forceOffline)
      presence = ::g_contact_presence.OFFLINE
    else if (contact.online && contact.gameStatus) {
      if (contact.gameStatus == "in_queue")
        presence = ::g_contact_presence.IN_QUEUE
      else
        presence = ::g_contact_presence.IN_GAME
    }
  }
  else if (squadStatus == squadMemberState.SQUAD_LEADER)
    presence = ::g_contact_presence.SQUAD_LEADER
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_READY)
    presence = ::g_contact_presence.SQUAD_READY
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_OFFLINE)
    presence = ::g_contact_presence.SQUAD_OFFLINE
  else
    presence = ::g_contact_presence.SQUAD_NOT_READY

  contact.presence = presence

  if (squadStatus != squadMemberState.NOT_IN_SQUAD || ::is_in_my_clan(null, uid))
    ::chatUpdatePresence(contact)

  return contact
}

::getFriendsOnlineNum <- function getFriendsOnlineNum() {
  if (contactsByGroups.len() == 0)
    return 0
  local online = 0
  foreach (groupName in [EPL_FRIENDLIST, EPLX_PS4_FRIENDS]) {
    if (!(groupName in contactsByGroups))
      continue

    foreach (f in contactsByGroups[groupName])
      if (f.online && !f.forceOffline)
        online++
  }
  return online
}

::findContactByXboxId <- function findContactByXboxId(xboxId) {
  foreach (_uid, player in contactsPlayers)
    if (player.xboxId == xboxId)
      return player
  return null
}

::fillContactTooltip <- function fillContactTooltip(obj, contact, handler) {
  let fullName = hasFeature("Clans") && contact.clanTag != ""
    ? $"{contact.clanTag} {contact.getName()}"
    : contact.getName()

  let title = contact.title != "" && contact.title != null
    ? loc($"title/{contact.title}")
    : ""

  let view = {
    name = fullName
    presenceText = colorize(contact.presence.getIconColor(), contact.getPresenceText())
    icon = contact.pilotIcon
    hasUnitList = false
    title = title
  }

  let squadStatus = ::g_squad_manager.getPlayerStatusInMySquad(contact.uid)
  if (squadStatus != squadMemberState.NOT_IN_SQUAD && squadStatus != squadMemberState.SQUAD_MEMBER_OFFLINE) {
    let memberData = ::g_squad_manager.getMemberData(contact.uid)
    if (memberData) {
      let memberDataAirs = memberData?.crewAirs[memberData.country] ?? []
      let gameModeId = ::g_squad_manager.getLeaderGameModeId()
      let event = ::events.getEvent(gameModeId)
      let difficulty = ::events.getEventDifficulty(event)
      let ediff = difficulty.getEdiff()
      view.unitList <- []
      view.hasUnitList = memberDataAirs.len() != 0

      if (memberData?.country != null && ::checkCountry(memberData.country, $"memberData of contact = {contact.uid}")
          && memberDataAirs.len() != 0) {
        view.unitList.append({ header = loc("conditions/playerTag") })
        if (!event?.multiSlot) {
          let unitName = memberData.selAirs[memberData.country]
          let unit = getAircraftByName(unitName)
          view.unitList.append({
            rank = format("%.1f", unit.getBattleRating(ediff))
            unit = unitName
            icon = ::getUnitClassIco(unit)
          })
        }
        else {
          foreach (id, unitName in memberDataAirs) {
            let unit = getAircraftByName(unitName)
            view.unitList.append({
              rank = format("%.1f", unit.getBattleRating(ediff))
              unit = unitName
              icon = ::getUnitClassIco(unit)
              even = id % 2 == 0
            })
          }
        }
        if (memberDataAirs.len() != 0)
          view.hint <- $"{loc("shop/all_info_relevant_to_current_game_mode")}: {difficulty.getLocName()}"
      }
    }
  }

  let blk = handyman.renderCached("%gui/contacts/contactTooltip.tpl", view)
  let guiScene = obj.getScene()
  guiScene.replaceContentFromText(obj, blk, blk.len(), handler)

  if (!view.hasUnitList)
    return

  guiScene.applyPendingChanges(false)
  let contactObj = obj.findObject("contact_tooltip")
  let contactAircraftsObj = contactObj.findObject("contact-aircrafts")
  contactAircraftsObj.size = $"{contactObj.getSize()[0]}, {contactAircraftsObj.getSize()[1]}"
}

::collectMissedContactData <- function collectMissedContactData (uid, key, val) {
  if (!(uid in ::missed_contacts_data))
    ::missed_contacts_data[uid] <- {}
  ::missed_contacts_data[uid][key] <- val
}

::isPlayerInFriendsGroup <- function isPlayerInFriendsGroup(uid, searchByUid = true, playerNick = "") {
  if (u.isEmpty(uid))
    searchByUid = false

  local isFriend = false
  if (searchByUid)
    isFriend = ::isPlayerInContacts(uid, EPL_FRIENDLIST) || ::isPlayerInContacts(uid, EPLX_PS4_FRIENDS)
  else if (playerNick != "")
    isFriend = ::isPlayerNickInContacts(playerNick, EPL_FRIENDLIST) || ::isPlayerNickInContacts(playerNick, EPLX_PS4_FRIENDS)

  return isFriend
}

subscribe_handler(::g_contacts, ::g_listener_priority.DEFAULT_HANDLER)
