from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { appendOnce, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { get_time_msec } = require("dagor.time")

let UPDATE_DELAY_MSEC = isPlatformSony? 60000 : 1800000 //60 sec for psn, 30 minutes for others
let lastUpdate = persist("lastUpdate", @() Watched(0))
let saveLastUpdate = function() { lastUpdate(get_time_msec()) }
let canUpdate = @() get_time_msec() - lastUpdate.value >= UPDATE_DELAY_MSEC

local afterUpdateCb = @() null
let callCbOnce = function() {
  afterUpdateCb()
  afterUpdateCb = @() null
}

let cachedUids = persist("cachedUids", @() Watched({}))
let pendingUids = persist("pendingUids", @() Watched([]))

let updateBlocklist = function() {
  if (isEmpty(pendingUids.value) || !canUpdate()) {
    callCbOnce()
    return
  }

  //While we waiting response, we can collect new uids list
  let waitingUids = pendingUids.value
  pendingUids([])
  saveLastUpdate()

  let blk = ::DataBlock()
  blk.addBlock("body")
  blk.body.addStr("groupName", EPL_BLOCKLIST)
  foreach (uid in waitingUids)
    blk.body.addInt("uid", uid.tointeger())

  ::g_tasker.charRequestBlk(
    "cln_check_me_in_contacts",
    blk,
    null,
    Callback(function(response) {
      log("[UCS] Success update blocked list")
      debugTableData(response)

      for (local i = 0; i < response.paramCount(); i++) {
        let uid = response.getParamName(i)

        cachedUids.mutate(@(v) v[uid.tostring()] <- get_time_msec())
        let contact = ::getContact(uid)
        if (!contact)
        {
          log($"[UCS]: Fail updating {uid}. Contact not found")
          continue
        }

        contact.update({ isBlockedMe = response.getParamValue(i) })
        contact.updateMuteStatus()
      }

      ::broadcastEvent("ContactsBlockStatusUpdated")
      callCbOnce()
    }, this),
    Callback(function(err) {
      log($"[UCS] Get Block Users: Error receieved: {toString(err, 4)}")
      debugTableData(waitingUids)

      //Save to pending ids, so we will try again in next call
      pendingUids.mutate(@(v) v.extend(waitingUids))
      callCbOnce()
    }, this)
  )
}

let updateContactsStatusByUids = function(uids) {
  foreach (uid in uids) {
    if (uid && (cachedUids.value?[uid.tostring()] == null) && !::is_my_userid(uid))
      appendOnce(uid, pendingUids.value)
  }

  updateBlocklist()
}

let invalidateCache = function() {
  lastUpdate(0)
  cachedUids({})
  pendingUids([])
}

let updateContactsStatusByContacts = function(arr, cb = @() null) {
  afterUpdateCb = cb
  updateContactsStatusByUids(arr.map(@(c) c?.uidInt64))
}

let checkInRoomMembers = function() {
  let playersList = ::SessionLobby.getMembersInfoList()
  let list = playersList.filter(
    @(p) !p.isBot && !::is_my_userid(p.userId)
  ).map(
    @(p) ::getContact(p.userId, p.name, p.clanTag) //Need to create contact, so it will be updated later
  )
  updateContactsStatusByContacts(list)
}

addListenersWithoutEnv({
  ScriptsReloaded = function(_p) { invalidateCache() }
  SignOut = function(_p) { invalidateCache() }
  LobbyMembersChanged = function(_p) { checkInRoomMembers() }
  RoomJoined = function(_p) { checkInRoomMembers() }
  ChatLatestThreadsUpdate = function(_p) {
    let arr = []
    foreach (thread in ::g_chat_latest_threads.getList()) {
      if (::is_my_userid(thread.ownerUid))
        continue

      arr.append(::getContact(thread.ownerUid, thread.ownerNick, thread.ownerClanTag))
    }
    updateContactsStatusByContacts(arr)
  }
  ContactsGroupUpdate = function(_p) {
    let arr = []
    foreach (_uid, contact in ::contacts_players)
      arr.append(contact)

    updateContactsStatusByContacts(arr)
  }
})

return {
  updateContactsStatusByContacts
  checkInRoomMembers
  cachedUids
}