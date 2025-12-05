require ecs
require strings


[es(tag=gameClient, REQUIRE=watchedSquad, on_appear, track=itemContainer)]
def track_squad_members_grenade_types(evt : Event;
                                      itemContainer : EidList;
                                      var squad_member_ui__grenadeTypes : StringList&)
  squad_member_ui__grenadeTypes |> clear()
  for eid in itemContainer
    query(eid) <| $ [es] (item__grenadeType : string)
      if !empty(item__grenadeType) && item__grenadeType != "shell"
        squad_member_ui__grenadeTypes |> push(item__grenadeType)


[es(tag=gameClient, REQUIRE=watchedSquad, on_appear, track=itemContainer, after=track_squad_members_grenade_types)]
def track_squad_members_tnt_block(evt : Event;
                                  itemContainer : EidList;
                                  var squad_member_ui__grenadeTypes : StringList&)
  for eid in itemContainer
    query(eid) <| $ [es] (item__grenadeLikeType : string)
      if !empty(item__grenadeLikeType)
        squad_member_ui__grenadeTypes |> push(item__grenadeLikeType)


[es(tag=gameClient, REQUIRE=watchedSquad, on_appear, track=itemContainer)]
def track_squad_members_mine_types(evt : Event;
                                   itemContainer : EidList;
                                   var squad_member_ui__mineTypes : StringList&)
  squad_member_ui__mineTypes |> clear()
  for eid in itemContainer
    query(eid) <| $ [es] (item__mineType : string)
      if !empty(item__mineType)
        squad_member_ui__mineTypes |> push(item__mineType)
