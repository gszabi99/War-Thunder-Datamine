require ecs
require ecs.common
require app
require math
require math.base
require net
require Mission
require MPlayer
require Unit
require %game.unit.unit_events
require %appGame.wt_events

let supplyTransportSubTemplates = "+unit_init_params+requested_vehicle+supply_transport"

[es(tag=server)]
def vehicle_spawn_request_es(evt : RequestSpawnVehicle;
                             eid aka requester_eid : EntityId;
                             transform aka requester_transform : float3x4;
                             team aka requester_team : int;
                             isAlive : bool;
                             possessedByPlr : EntityId;
                             human_vehicle__occupiedSeatEid : EntityId)
  if !isAlive || human_vehicle__occupiedSeatEid != INVALID_ENTITY_ID
    return
  var player = player_get_by_eid(possessedByPlr)
  if player == null
    return
  let requesterPos = requester_transform[3].xz
  var laptopTeam = -1
  var nodeEid = INVALID_ENTITY_ID
  query(evt.supplyLaptopEid) <| $ [es] (supply_laptop__team : int; supply_laptop__nodeEid : EntityId)
    laptopTeam = supply_laptop__team
    nodeEid = supply_laptop__nodeEid
  if laptopTeam != requester_team
    return
  query(nodeEid) <| $ [es] (supply_graph__name : string;
                            @shared_comp supply_terminal__transports : Array;
                            supply_terminal__transportSpawnTm : float3x4;
                            supply_terminal__transportSpawnFreeRadius : float)
    let areaId = get_area_id(supply_graph__name)
    if areaId < 0 || !is_in_area(areaId, requesterPos)
      return

    let transportIdx = evt.transportIdx
    if transportIdx < 0 || transportIdx >= length(supply_terminal__transports)
      return
    let offer = get_ecs_object(supply_terminal__transports[transportIdx])
    let templatePtr = get_ecs_string(offer, "entityTemplate")
    let unitClassPtr = get_ecs_string(offer, "unitClass")
    if templatePtr == null || unitClassPtr == null
      return
    let templateName = string(*templatePtr)
    let unitClass = string(*unitClassPtr)
    let cost = get_int(offer, "cost") ?? 0
    if empty(templateName) || empty(unitClass)
      return
    let spawnTm = supply_terminal__transportSpawnTm
    let spawnFreeRadiusSq = square(supply_terminal__transportSpawnFreeRadius)
    let spawnPos = spawnTm[3].xz
    let spawnBlocked = find_query() <| $ [es(REQUIRE_NOT=unit_tag__human)] (transform aka unit_transform : float3x4; unit__ref : UnitRef)
      return unit__ref.unit != null && !unit__ref.unit.isDelayed && length_sq(unit_transform[3].xz - spawnPos) < spawnFreeRadiusSq
    if spawnBlocked
      send_net_event(requester_eid, CmdHeroLogEvent(event = "supply", text = "supply/spawn_blocked"))
      return
    if !spend_player_spawn_score(*player, cost)
      send_net_event(requester_eid, CmdHeroLogEvent(event = "supply", text = "supply/not_enough_score"))
      return
    createEntity(templateName + supplyTransportSubTemplates) <| $(init)
      init |> set("unit__className", unitClass)
      init |> set("transform", spawnTm)
      init |> set("team", int(MultiplayerTeam.MP_TEAM_NEUTRAL))
      init |> set("unit__ownsUnitId", true)
      init |> set("setting__toGround", true)
      init |> set("supply_transport__team", laptopTeam)

[es(tag=server)]
def requested_vehicle_dead_es(evt : EventUnitBecameDead;
                              requested_vehicle__wreckLifetime : float;
                              var requested_vehicle__destroyAtTime : float&)
  requested_vehicle__destroyAtTime = get_sync_time() + requested_vehicle__wreckLifetime

[es(tag=server, no_order)]
def requested_vehicle_cleanup_es(info : UpdateStageInfoAct;
                                 eid : EntityId;
                                 requested_vehicle__destroyAtTime : float)
  if requested_vehicle__destroyAtTime < 0. || get_sync_time() < requested_vehicle__destroyAtTime
    return
  destroyEntity(eid)
