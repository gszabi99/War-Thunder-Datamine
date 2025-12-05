require ecs
require net
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.riextra_damage_common
require %appGame.infantry.es.team_common
require RiDestr
require RendInst


[es(tag=server)]
def riextra_request_damage_server_es(evt : RequestRendinstDamage; eid : EntityId)
  damage_ri_on_server(evt.handle, evt.damage, evt.pos, evt.impulse, evt.time, eid)

[es(tag=server)]
def riextra_ent_request_damage_server_es(evt : RequestRendinstEntityDamage; eid : EntityId)
  query(evt.eid) <| $ [es] (ri_extra : RiExtraComponent)
    damage_ri_on_server(ri_extra.handle, evt.damage, evt.pos, evt.impulse, evt.time, eid)

[es(tag=server, REQUIRE_NOT=override__riextraDamage)]
def riextra_damage_server_es(evt : CmdRendinstDamage; eid : EntityId; possessedByPlr : EntityId = INVALID_ENTITY_ID; beh_tree__enabled = false)
  if is_bot_or_local(possessedByPlr, beh_tree__enabled)
    damage_ri_on_server(evt.handle, evt.damage, evt.pos, evt.impulse, evt.time, eid)



[es(tag=netClient, REQUIRE_NOT=override__riextraDamage)]
def riextra_damage_client_es(evt : CmdRendinstDamage; eid : EntityId; possessedByPlr : EntityId)
  query(possessedByPlr) <| $ [es] (is_local : bool)
    if is_local
      let poolId = handle_to_ri_type(evt.handle)
      if poolId < rendinst_getRiGenExtraResCount()
        if riex_isImmortal(poolId)
          return
      let riExtraEid = find_ri_extra_eid(evt.handle)
      if riExtraEid != INVALID_ENTITY_ID
        send_net_event(eid, RequestRendinstEntityDamage(eid = riExtraEid, damage = evt.damage, pos = evt.pos, impulse = evt.impulse, time = evt.time))
      else
        send_net_event(eid, RequestRendinstDamage(handle = evt.handle, damage = evt.damage, pos = evt.pos, impulse = evt.impulse, time = evt.time))

[es(tag=server, REQUIRE=override__riextraDamage)]
def loc_riextra_damage_server_es(evt : CmdRendinstDamage;
                                 eid : EntityId;
                                 team : int = TEAM_UNASSIGNED;
                                 possessedByPlr : EntityId = INVALID_ENTITY_ID;
                                 beh_tree__enabled = false)
  if !is_ri_extra_can_be_damaged_by_team(evt.handle, team)
    return

  if is_bot_or_local(possessedByPlr, beh_tree__enabled)
    damage_ri_on_server(evt.handle, evt.damage, evt.pos, evt.impulse, evt.time, eid)



[es(tag=netClient, REQUIRE=override__riextraDamage)]
def loc_riextra_damage_client_es(evt : CmdRendinstDamage;
                                 eid : EntityId;
                                 possessedByPlr : EntityId;
                                 team : int = TEAM_UNASSIGNED)
  if !is_ri_extra_can_be_damaged_by_team(evt.handle, team)
    return

  query(possessedByPlr) <| $ [es] (is_local : bool)
    if !is_local
      return

    let poolId = handle_to_ri_type(evt.handle)
    if poolId < rendinst_getRiGenExtraResCount()
      if riex_isImmortal(poolId)
        return

    let riExtraEid = find_ri_extra_eid(evt.handle)
    if riExtraEid != INVALID_ENTITY_ID
      send_net_event(eid, RequestRendinstEntityDamage(eid = riExtraEid, damage = evt.damage, pos = evt.pos, impulse = evt.impulse, time = evt.time))
    else
      send_net_event(eid, RequestRendinstDamage(handle = evt.handle, damage = evt.damage, pos = evt.pos, impulse = evt.impulse, time = evt.time))
