local avatars = ::require("scripts/user/avatars.nut")
local { isPs4XboxOneInteractionAvailable,
        isPlatformSony } = require("scripts/clientState/platform.nut")
local editContactsList = require("scripts/contacts/editContacts.nut")

::on_presences_update <- function on_presences_update(params)
{
  local contactsDataList = []
  if ("presences" in params)
  {
    foreach(p in params.presences)
    {
      local player = {
        uid = ::getTblValue("userId", p)
        name = ::getTblValue("nick", p)
      }
      if (!::u.isString(player.uid) || !::u.isString(player.name))
      {
        local errText = "on_presences_update cant update presence of player:\n" + ::toString(p)
        ::script_net_assert_once(::toString(player), errText)
        continue
      }

      if ("presences" in p)
      {
        if ("online" in p.presences)
        {
          player.online <- p.presences.online
          player.unknown <- null
        }
        if ("unknown" in p.presences)
          player.unknown <- p.presences.unknown

        if ("status" in p.presences)
        {
          player.gameStatus <- null
          foreach(s in ["in_game", "in_queue"])
            if (s in p.presences.status)
            {
              local gameInfo = p.presences.status[s]

              // This is a workaround for a bug when something
              // is setting player presence with no event info.
              if (!("eventId" in gameInfo))
                continue

              player.gameStatus = s
              player.gameConfig <- {
                diff = gameInfo.diff
                country = gameInfo.country
                eventId = ::getTblValue("eventId", gameInfo, null)
              }
              break
            }
        }

        if("clanTag" in p.presences)
        {
          if (typeof(p.presences.clanTag) == "string")
            player.clanTag <- p.presences.clanTag
          else
          {
            if (typeof(p.presences.clanTag) == "array")
              debugTableData(p.presences.clanTag)
            ::dagor.assertf(false, "Error: presences: incorrect type of clantag = " + p.presences.clanTag + ", for user " + player.name + ", " + player.uid)
          }
        }

        if ("profile" in p.presences)
        {
          player.pilotIcon <- avatars.getIconById(p.presences.profile?.pilotId ?? -1)
          player.wins <- p.presences.profile?.wins ?? 0
          player.expTotal <- p.presences.profile?.expTotal ?? -1
        }

        if ("in_game_ex" in p.presences)
        {
          player.inGameEx <- p.presences.in_game_ex
        }
      }
      player.needReset <- ("update" in p) ? !p.update : false
      contactsDataList.append(player)
    }
  }

  ::update_contacts_by_list(contactsDataList, false)

  if ("groups" in params)
  {
    ::clear_contacts()

    local friendsToRemove = []
    foreach(listName, list in params.groups)
    {
      if (list == null
          || (
              ::contacts_groups_default.findvalue(@(gr) gr == listName) == null
              && (
                  (listName == ::EPLX_PS4_FRIENDS && !isPlatformSony)
                  || list.len() == 0
                )
            )
         )
        continue

      foreach (p in list)
      {
        local playerUid = p?.userId
        local playerName = p?.nick
        local playerClanTag = p?.clanTag

        local player = ::g_contacts.addContact(null, listName, {
          uid = playerUid
          playerName = playerName
          clanTag = playerClanTag
        })

        if (!player)
        {
          local myUserId = ::my_user_id_int64 // warning disable: -declared-never-used
          local errText = playerUid ? "player not found" : "not valid data"
          ::script_net_assert_once("not found contact for group", errText)
          continue
        }

        if (listName == ::EPL_FRIENDLIST && !isPs4XboxOneInteractionAvailable(playerName))
        {
          friendsToRemove.append(player)
          continue
        }
      }
    }

    if (friendsToRemove.len())
      editContactsList({[false] = friendsToRemove}, ::EPL_FRIENDLIST)
  }

  ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = null})
  ::update_gamercards()
}

::reload_contact_list <- function reload_contact_list()
{
  matching_api_func("mpresence.reload_contact_list",
                    function(...){})
}

::set_presence <- function set_presence(presence)
{
  matching_api_func("mpresence.set_presence", function(...) {}, presence)
}

foreach (notificationName, callback in
          {
            ["mpresence.notify_presence_update"] = on_presences_update,

            ["mpresence.on_added_to_contact_list"] = function (params)
              {
                local userData = ::getTblValue("user", params)
                if (userData)
                  ::g_invites.addFriendInvite(::getTblValue("name", userData, ""), ::getTblValue("userId", userData, ""))
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
