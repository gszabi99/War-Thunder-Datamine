let editContactsList = require("scripts/contacts/editContacts.nut")

::no_dump_facebook_friends <- {}

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

::addSocialFriends <- function addSocialFriends(blk, groupName, silent = false)
{
  let players = []

  foreach(userId, info in blk)
  {
    let contact = ::getContact(userId, info.nick)
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

  let inBlk = ::DataBlock()
  foreach(id, block in ::no_dump_facebook_friends)
    inBlk.id <- id.tostring()

  let taskId = ::facebook_find_friends(inBlk, ::EPL_MAX_PLAYERS_IN_LIST)
  if(taskId < 0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }
  else
    ::add_bg_task_cb(taskId, function(){
        let resultBlk = ::facebook_find_friends_result()
        ::addSocialFriends(resultBlk, ::EPL_FACEBOOK)
        ::addContactGroup(::EPL_FACEBOOK)
      })
}
//-------------------- </Facebook> ----------------------------
