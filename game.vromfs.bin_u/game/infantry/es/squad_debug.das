options no_aot
require ecs
require DagorConsole
require Dacoll

require %appGame.wt_events
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.es.net_console_macro
require %appGame.infantry.es.server_debug_common
require PropsManager
require %appGame.infantry.es.hitpoints_common

[net_console_cmd(name="human.debug_hit")]
def human_hit_debug(delta_hp : float = 0.f;
                    @net_hero hero_eid : EntityId)
  sendEvent(hero_eid, CmdApplyDamage(offender = hero_eid, damageType = int(DamageType.DM_PROJECTILE), shellId = props_pack_for_net(PropsId()), gunPropsId = props_pack_for_net(PropsId()), deltaHp = delta_hp, hitPos = float3(0., 0., 0.)))

def spawn_soldiers_at_pos(pos : float3; count, team : int; isAi = true; spawn_template : string; cell_size : float;
                          squad : EntityId = INVALID_ENTITY_ID; player_eid : EntityId = INVALID_ENTITY_ID)
  query() <| $ [es(REQUIRE=devSoldier)] (eid : EntityId) { destroyEntity(eid); }
  var offset = float3(0.f, 0.f, 0.f)
  var soldierEid = INVALID_ENTITY_ID
  for j in range(0, count)
    for i in range(0, count)
      soldierEid = createEntity(spawn_template) <| $(var init : ComponentsInitializer)
        var tm : float3x4
        tm[0] = float3(1., 0., 0.)
        tm[1] = float3(0., 1., 0.)
        tm[2] = float3(0., 0., 1.)
        tm[3] = pos + offset - float3(float(count) * 0.5f, 0.f, float(count) * 0.5f)
        set(init, "transform", tm)
        
        let usedTeam = team == 0 ? (i ^ j) % 2 + 1 : team
        set(init, "team", usedTeam)
        set(init, "spawn_immunity__timer", 0.f)
        set(init, "squad_member__squad", squad)
        set(init, "squad_member__playerEid", player_eid)
        set(init, "beh_tree__node", "soldier")
        set(init, "beh_tree__enabled", isAi)

        offset += float3(0.f, 0.f, cell_size)
    offset += float3(cell_size, 0.f, 0.f)
    offset.z = 0.f
  query(squad) <| $ [es] (var squad__leader : EntityId&; var squad__ownerPlayer : EntityId&)
    if squad__leader == INVALID_ENTITY_ID
      squad__leader = soldierEid
    squad__ownerPlayer = player_eid

[console_cmd(name="squad.spawnMoreSoldiers")]
def squad_spawnMoreSoldiers(count = 1;  team = 0; isAi = true; isAlive = true; cellSize = 1.f)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    var tm : float3x4
    if !camera__active
      return false
    var len = 100.0
    var norm = float3()
    tm = transform
    let dir = tm[2]
    let pos = tm[3]
    traceray_normalized(pos, dir, len, norm)
    let center = pos + dir * len
    if is_server()
      spawn_soldiers_at_pos(center, count, team, isAi, isAlive ? "base_equipped_soldier+dev_soldier_tag" : "dead_base_soldier+dev_soldier_tag", cellSize)
    else
      exec_server_cmd("squad.spawnMoreSoldiersPos {count} {center[0]} {center[1]} {center[2]} {team} {isAi} {isAlive} {cellSize}")
    return true

[console_cmd(name="squad.spawnMoreSoldiersPos")]
def squad_spawnMoreSoldiers(count = 7; x, y, z : float = 0.f; team = 0; isAi = true; isAlive = true;  cellSize = 1.f)
  if is_server()
    spawn_soldiers_at_pos(float3(x, y, z), count, team, isAi, isAlive ? "base_equipped_soldier+dev_soldier_tag" : "dead_base_soldier+dev_soldier_tag", cellSize)
  else
    exec_server_cmd("squad.spawnMoreSoldiersPos {count} {x} {y} {z} {team} {isAi} {isAlive} {cellSize}")

[console_cmd(name="squad.spawn_teammate_soldier")]
def console_spawn_teammate_soldier(isAi = true)
  query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
    squad_spawnMoreSoldiers(1, hero_team, isAi)

[console_cmd(name="squad.spawn_enemy_soldier")]
def console_spawn_enemy_soldier(isAi = true)
  query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
    squad_spawnMoreSoldiers(1, hero_team + 1, isAi)

[console_cmd(name="squad.spawnMoreSoldiersInSquad")]
def squad_spawnMoreSoldiersInSquad(count = 1; player_squad = false; team = 1; cellSize = 1.f)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    var tm : float3x4
    if !camera__active
      return false
    var len = 100.0
    var norm = float3()
    tm = transform
    let dir = tm[2]
    let pos = tm[3]
    traceray_normalized(pos, dir, len, norm)
    let center = pos + dir * len

    var playerEid = INVALID_ENTITY_ID
    var squadEid = INVALID_ENTITY_ID
    var soldierTeam = team
    if player_squad
      query() <| $ [es(REQUIRE=controlledHero)] (eid aka hero_eid : EntityId; team aka hero_team : int;
                                                 squad_member__squad : EntityId = INVALID_ENTITY_ID)
        query(squad_member__squad) <| $ [es] (squad__ownerPlayer : EntityId)
          playerEid = squad__ownerPlayer
          squadEid = squad_member__squad
          soldierTeam = hero_team
        if playerEid == INVALID_ENTITY_ID
          playerEid = createEntity("sync_player") <| $(var init : ComponentsInitializer)
            set(init, "team", hero_team)
            set(init, "possessed", hero_eid)
        if squadEid == INVALID_ENTITY_ID
          using() <| $(var soldiersList : EidList)
            soldiersList |> push(hero_eid)
            squadEid = createEntitySync("squad") <| $(var init : ComponentsInitializer)
              set(init, "squad__ownerPlayer", playerEid)
              set(init, "squad__leader", hero_eid)
              set(init, "squad__allMembers", soldiersList)
    else
      playerEid = createEntity("bot_player") <| $(var init : ComponentsInitializer)
        set(init, "team", team)
      squadEid =  createEntitySync("squad+dev_squad") <| $(var init : ComponentsInitializer)
        set(init, "squad__ownerPlayer", playerEid)

    spawn_soldiers_at_pos(center, count, soldierTeam, true, "base_equipped_soldier+dev_soldier_tag", cellSize, squadEid, playerEid)
    return true

[es(tag=(dev, server), on_disappear, REQUIRE=dev_squad)]
def squad_cleanup_bot_player(evt : Event; squad__ownerPlayer : EntityId)
  query(squad__ownerPlayer) <| $ [es(REQUIRE=playerIsBot)] ()
    destroyEntity(squad__ownerPlayer)

[console_cmd(name="squad.suicide_controlled")]
def squad_suicide_controlled_debug()
  let hero_eid = get_controlled_hero_eid()
  suicide_kill(hero_eid)

[net_console_cmd(name="squad.suicide")]
def squad_suicide_debug(@net_hero hero_eid : EntityId)
  let squadEid = get_Eid(hero_eid, "squad_member__squad") ?? INVALID_ENTITY_ID
  kill_squad(squadEid)

[net_console_cmd(name="squad.kill")]
def squad_kill_debug(index : int; @net_hero hero_eid : EntityId)
  let squadEid = get_Eid(hero_eid, "squad_member__squad") ?? INVALID_ENTITY_ID
  query(squadEid) <| $ [es] (squad__allMembers : EidList)
    if uint(index) < uint(length(squad__allMembers))
      suicide_kill(squad__allMembers[index])

def suicideBots(squad_eid : EntityId)
  let squadLeaderEid = get_squad_leader(squad_eid)
  kill_squad(squad_eid) <| $(memberEid)
    return squadLeaderEid != memberEid

[net_console_cmd(name="squad.suicide_bots")]
def squad_suicide_bots_debug(@net_hero hero_eid : EntityId)
  let squadEid = get_Eid(hero_eid, "squad_member__squad") ?? INVALID_ENTITY_ID
  suicideBots(squadEid)

[console_cmd(name="squad.personal_order_grenade")]
def squad_orderPersonalGrenadeThrow(grenade_type : string)
  let hero_eid = get_controlled_hero_eid()
  query(hero_eid) <| $ [es] (var human_context_command__menuCtxPos : float3&;
                             var human_context_command__menuCtxType : das_string&;
                             var human_context_command__menuCtxEid : EntityId&;
                             var human_context_command__menuCtxTracePos : float3&;
                             var human_context_command__menuCtxTraceDir : float3&)
    human_context_command__menuCtxPos = float3()
    human_context_command__menuCtxType := "" 
    human_context_command__menuCtxEid = INVALID_ENTITY_ID
    human_context_command__menuCtxTracePos = float3()
    human_context_command__menuCtxTraceDir = float3()

    if !human_point_get_trace_pos_dir(hero_eid, human_context_command__menuCtxTracePos, human_context_command__menuCtxTraceDir)
      return

    var traced = HumanPointOrderTraced()
    if human_point_order_trace_spot(hero_eid, int(HumanPointOrderType.POINT_DETECT_CONTEXT), traced)
      human_context_command__menuCtxPos = traced.pos
      human_context_command__menuCtxEid = traced.eid

    if grenade_type == "frag"
      sendEvent(hero_eid, RqContextCommandPointOrder(pointOrderStrID = "frag_grenade_ctx"))
    if grenade_type == "smoke"
      sendEvent(hero_eid, RqContextCommandPointOrder(pointOrderStrID = "smoke_grenade_ctx"))
    if grenade_type == "flash"
      sendEvent(hero_eid, RqContextCommandPointOrder(pointOrderStrID = "flash_grenade_ctx"))

[console_cmd(name="squad.cancel_context_command")]
def squad_cancelContextCommand()
  let hero_eid = get_controlled_hero_eid()
  sendEvent(hero_eid, RqCancelContextCommand(include_personal_orders = true))
