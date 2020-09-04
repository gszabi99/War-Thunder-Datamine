local psn = require("sonyLib/webApi.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local editContactsList = require("scripts/contacts/editContacts.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

::no_dump_facebook_friends <- {}
::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS <- 200
::PS4_UPDATE_TIMER_LIMIT <- 300000
::last_update_ps4_friends <- -::PS4_UPDATE_TIMER_LIMIT

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

local isFirstPs4FriendsUpdate = true

::addSocialFriends <- function addSocialFriends(blk, groupName, silent = false)
{
  local players = []

  foreach(userId, info in blk)
  {
    local contact = ::getContact(userId, info.nick)
    if (contact)
      players.append(contact)
  }

  if (players.len())
  {
    ::addContactGroup(groupName)
    editContactsList({[true] = players}, groupName, !silent)
  }

  ::on_facebook_destroy_waitbox()
}

//--------------- <PlayStation> ----------------------
::addPsnFriends <- function addPsnFriends()
{
  if (::ps4_show_friend_list_ex(true, true, false) == 1)
  {
    local taskId = ::ps4_find_friend()
    if (taskId < 0)
      return

    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, (@(progressBox) function () {
      ::destroyMsgBox(progressBox)
      local blk = ::DataBlock()
      blk = ::ps4_find_friends_result()
      if (blk.paramCount() || blk.blockCount())
      {
        ::addSocialFriends(blk, ::EPLX_PS4_FRIENDS)
        foreach(userId, info in blk)
        {
          local friend = {}
          friend["accountId"] <- info.id
          friend["onlineId"] <- info.nick.slice(1)
          ::ps4_console_friends[info.nick] <- friend
        }
      }
      else
        ::scene_msg_box("psn_friends_add", null, ::loc("msgbox/no_psn_friends_added"), [["ok", function() {}]], "ok")
    })(progressBox))
  }
}

::update_ps4_friends <- function update_ps4_friends()
{
  // We MUST do this on first opening, even if it is in battle/respawn
  if (!::isInMenu() && !isFirstPs4FriendsUpdate)
    return

  isFirstPs4FriendsUpdate = false
  if (isPlatformSony && ::dagor.getCurTime() - ::last_update_ps4_friends > ::PS4_UPDATE_TIMER_LIMIT)
  {
    ::last_update_ps4_friends = ::dagor.getCurTime()
    if (::isInArray(::EPLX_PS4_FRIENDS, ::contacts_groups))
      ::resetPS4ContactsGroup()
    ::requestPS4Friends()
  }
}

::requestPS4Friends <- function requestPS4Friends()
{
  local onSomeFriendsReceived = function(response, err) {
    local size = (response?.size || 0) + (response?.start || 0)
    local total = response?.totalResults || size
    ::addContactGroup(::EPLX_PS4_FRIENDS)
    if (!err)
    {
      foreach (idx, playerBlock in (response?.friendList || []))
      {
        local name = "*" + playerBlock.user.onlineId
        ::ps4_console_friends[name] <- playerBlock.user
        ::ps4_console_friends[name].presence <- playerBlock.presence
      }
    }

    if (err || size >= total)
    {
      ::movePS4ContactsToSpecificGroup()
      ::broadcastEvent(contactEvent.CONTACTS_UPDATED)
    }
  }
  psn.fetch(psn.profile.listFriends(), onSomeFriendsReceived, ::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS)
}

::resetPS4ContactsGroup <- function resetPS4ContactsGroup()
{
  ::u.extend(::contacts[::EPL_FRIENDLIST], ::contacts[::EPLX_PS4_FRIENDS])
  ::contacts[::EPL_FRIENDLIST].sort(::sortContacts)
  ::g_contacts.removeContactGroup(::EPLX_PS4_FRIENDS)
  ::ps4_console_friends.clear()
}

::movePS4ContactsToSpecificGroup <- function movePS4ContactsToSpecificGroup()
{
  for (local i = ::contacts[::EPL_FRIENDLIST].len()-1; i >= 0; i--)
  {
    local friendBlock = ::contacts[::EPL_FRIENDLIST][i]
    if (friendBlock.name in ::ps4_console_friends)
    {
      ::contacts[::EPLX_PS4_FRIENDS].append(friendBlock)
      ::contacts[::EPL_FRIENDLIST].remove(i)
      ::dagor.debug(::format("Change contacts group from '%s' to '%s', for '%s', uid %s",
        ::EPL_FRIENDLIST, ::EPLX_PS4_FRIENDS, friendBlock.name, friendBlock.uid))
    }
  }

  ::contacts[::EPLX_PS4_FRIENDS].sort(::sortContacts)
}

::isPlayerPS4Friend <- function isPlayerPS4Friend(playerName)
{
  return isPlatformSony && playerName in ::ps4_console_friends
}

::get_psn_account_id <- function get_psn_account_id(playerName)
{
  if (!isPlatformSony)
    return null

  return ::ps4_console_friends?[playerName]?.accountId
}

::add_psn_account_id <- function add_psn_account_id(onlineId, accountId)
{
  if (isPlatformSony)
    ::ps4_console_friends["*"+onlineId] <- {accountId=accountId}
}

local function initPs4Friends()
{
  isFirstPs4FriendsUpdate = true
}


subscriptions.addListenersWithoutEnv({
  LoginComplete    = @(p) initPs4Friends()
})

//--------------- </PlayStation> ----------------------

//-----------------<Facebook> --------------------------
::on_facebook_friends_loaded <- function on_facebook_friends_loaded(blk)
{
  foreach(id, block in blk)
    ::no_dump_facebook_friends[id] <- block.name

  //TEST ONLY!
  //foreach (id, data in blk)
  //  dagor.debug("FACEBOOK FRIEND: id="+id+" name="+data.name)

  if(::no_dump_facebook_friends.len()==0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
    return
  }

  local inBlk = ::DataBlock()
  foreach(id, block in ::no_dump_facebook_friends)
    inBlk.id <- id.tostring()

  local taskId = ::facebook_find_friends(inBlk, ::EPL_MAX_PLAYERS_IN_LIST)
  if(taskId < 0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }
  else
    ::add_bg_task_cb(taskId, function(){
        local resultBlk = ::facebook_find_friends_result()
        ::addSocialFriends(resultBlk, ::EPL_FACEBOOK)
        ::addContactGroup(::EPL_FACEBOOK)
      })
}
//-------------------- </Facebook> ----------------------------
