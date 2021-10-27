local { addListenersWithoutEnv } = require("sqStdlibs/helpers/subscriptions.nut")
local { appendOnce, isEmpty } = require("sqStdLibs/helpers/u.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

local UPDATE_DELAY_MSEC = isPlatformSony? 60000 : 1800000 //60 sec for psn, 30 minutes for others
local lastUpdate = persist("lastUpdate", @() ::Watched(0))
local saveLastUpdate = function() { lastUpdate(::dagor.getCurTime()) }
local canUpdate = @() ::dagor.getCurTime() - lastUpdate.value >= UPDATE_DELAY_MSEC

local afterUpdateCb = @() null
local callCbOnce = function() {
  afterUpdateCb()
  afterUpdateCb = @() null
}

local cachedUids = persist("cachedUids", @() ::Watched({}))
local pendingUids = persist("pendingUids", @() ::Watched([]))

local updateBlocklist = function() {
  if (isEmpty(pendingUids.value) || !canUpdate()) {
    callCbOnce()
    return
  }

  //While we waiting response, we can collect new uids list
  local waitingUids = pendingUids.value
  pendingUids([])
  saveLastUpdate()

  local blk = ::DataBlock()
  blk.addBlock("body")
  blk.body.addStr("groupName", ::EPL_BLOCKLIST)
  foreach (uid in waitingUids)
    blk.body.addInt("uid", uid.tointeger())

  ::g_tasker.charRequestBlk(
    "cln_check_me_in_contacts",
    blk,
    null,
    ::Callback(function(response) {
      ::dagor.debug("[UCS] Success update blocked list")
      ::debugTableData(response)

      for (local i = 0; i < response.paramCount(); i++) {
        local uid = response.getParamName(i)

        cachedUids.update(@(v) v[uid.tostring()] <- ::dagor.getCurTime())
        local contact = ::getContact(uid)
        if (!contact)
        {
          ::dagor.debug($"[UCS]: Fail updating {uid}. Contact not found")
          continue
        }

        contact.update({ isBlockedMe = response.getParamValue(i) })
        contact.updateMuteStatus()
      }

      ::broadcastEvent("ContactsBlockStatusUpdated")
      callCbOnce()
    }, this),
    ::Callback(function(err) {
      ::dagor.debug($"[UCS] Get Block Users: Error receieved: {::toString(err, 4)}")
      ::debugTableData(waitingUids)

      //Save to pending ids, so we will try again in next call
      pendingUids.update(@(v) v.extend(waitingUids))
      callCbOnce()
    }, this)
  )
}

local updateContactsStatusByUids = function(uids) {
  foreach (uid in uids) {
    if (uid && (cachedUids.value?[uid.tostring()] == null) && !::is_my_userid(uid))
      appendOnce(uid, pendingUids.value)
  }

  updateBlocklist()
}

local invalidateCache = function() {
  lastUpdate(0)
  cachedUids({})
  pendingUids([])
}

local updateContactsStatusByContacts = function(arr, cb = @() null) {
  afterUpdateCb = cb
  updateContactsStatusByUids(arr.map(@(c) c?.uidInt64))
}

local checkInRoomMembers = function() {
  local playersList = ::SessionLobby.getMembersInfoList()
  local list = playersList.filter(
    @(p) !p.isBot && !::is_my_userid(p.userId)
  ).map(
    @(p) ::getContact(p.userId, p.name, p.clanTag) //Need to create contact, so it will be updated later
  )
  updateContactsStatusByContacts(list)
}

addListenersWithoutEnv({
  ScriptsReloaded = function(p) { invalidateCache() }
  SignOut = function(p) { invalidateCache() }
  LobbyMembersChanged = function(p) { checkInRoomMembers() }
  RoomJoined = function(p) { checkInRoomMembers() }
  ChatLatestThreadsUpdate = function(p) {
    local arr = []
    foreach (thread in ::g_chat_latest_threads.getList()) {
      if (::is_my_userid(thread.ownerUid))
        continue

      arr.append(::getContact(thread.ownerUid, thread.ownerNick, thread.ownerClanTag))
    }
    updateContactsStatusByContacts(arr)
  }
  ContactsGroupUpdate = function(p) {
    local arr = []
    foreach (uid, contact in ::contacts_players)
      arr.append(contact)

    updateContactsStatusByContacts(arr)
  }
})

return {
  updateContactsStatusByContacts
  checkInRoomMembers
  cachedUids
}