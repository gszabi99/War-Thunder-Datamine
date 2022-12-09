from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { updateContactsGroups } = require("%scripts/contacts/contactsManager.nut")

let function on_presences_update(params)
{
  let contactsDataList = []
  let { presences = [] } = params
  foreach(p in presences)
  {
    let player = {
      uid = p?.userId
      name = p?.nick
    }
    if (type(player.uid) != "string")
    {
      let errText = "on_presences_update cant update presence of player:\n" + toString(p)
      ::script_net_assert_once(toString(player), errText)
      continue
    }

    if ("online" in p?.presences)
    {
      player.online <- p.presences.online
      player.unknown <- null
    }
    if ("unknown" in p?.presences)
      player.unknown <- p.presences.unknown

    if ("status" in p?.presences)
    {
      player.gameStatus <- null
      foreach(s in ["in_game", "in_queue"])
        if (s in p.presences.status)
        {
          let gameInfo = p.presences.status[s]

          // This is a workaround for a bug when something
          // is setting player presence with no event info.
          if (!("eventId" in gameInfo))
            continue

          player.gameStatus = s
          player.gameConfig <- {
            diff = gameInfo.diff
            country = gameInfo.country
            eventId = gameInfo?.eventId
          }
          break
        }
    }

    if ("in_game_ex" in p?.presences)
      player.inGameEx <- p.presences.in_game_ex

    player.needReset <- !(params?.update ?? true)
    contactsDataList.append(player)
  }

  ::update_contacts_by_list(contactsDataList, false)

  if ("groups" in params)
    updateContactsGroups(params)

  ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = null})
  ::update_gamercards()
}

::reload_contact_list <- function reload_contact_list()
{
  ::matching_api_func("mpresence.reload_contact_list",
                    function(...){})
}

::set_presence <- function set_presence(presence)
{
  ::matching_api_func("mpresence.set_presence", function(...) {}, presence)
}

foreach (notificationName, callback in
          {
            ["mpresence.notify_presence_update"] = on_presences_update,

            ["mpresence.on_added_to_contact_list"] = function (params)
              {
                let userData = getTblValue("user", params)
                if (userData)
                  ::g_invites.addFriendInvite(getTblValue("name", userData, ""), getTblValue("userId", userData, ""))
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
