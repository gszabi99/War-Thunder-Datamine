local editContactsList = require("scripts/contacts/editContacts.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

::no_dump_facebook_friends <- {}

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

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

::isPlayerPS4Friend <- function isPlayerPS4Friend(playerName)
{
  return isPlatformSony && playerName in ::ps4_console_friends
}

::get_psn_account_id <- function get_psn_account_id(playerName)
{
  if (!isPlatformSony)
    return null

  return ::ps4_console_friends?[playerName]?.psnId
}

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
