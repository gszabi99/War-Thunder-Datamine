require ecs
require app


[es(tag=gameClient, on_appear)]
def player_components_init_client(evt : Event; squad__ownerPlayer : EntityId)
  let localPlayerEid = get_local_player_eid()
  if squad__ownerPlayer == localPlayerEid
    query(localPlayerEid) <| $ [es(REQUIRE_NOT=squad_members_ui__watchedSquadEid)] ()
      addSubTemplate(localPlayerEid, "squad_members_ui+local_player_human_context")

[es(tag=server, on_appear)]
def player_components_init_server(evt : Event; squad__ownerPlayer : EntityId)
  query(squad__ownerPlayer) <| $ [es(REQUIRE_NOT=covers__coversCheckInterval)] ()
    addSubTemplate(squad__ownerPlayer, "covers_interval_check")
