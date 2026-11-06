require ecs
require ecs.common
require app
require math
require Grid
require net
require Mission
require MPlayer
require Unit
require %game.unit.unit_events
require %appGame.wt_events

let supplyTransportSubTemplates = "+unit_init_params+requested_vehicle+supply_transport"

def private find_transport_spawn_pos(area_name : string; free_radius : float; var spawn_tm : float3x4&) : bool
  let areaId = get_area_id(area_name)
  let limits = get_area_limits_xz(areaId)
  let limitsY = get_area_limits_y(areaId)
  let center = spawn_tm[3]
  let step = 2. * free_radius
  let cellsPerSide = int(length(max(abs(limits.xy - center.xz), abs(limits.zw - center.xz))) / step)
  var cells : array<int2>
  for i in range(-cellsPerSide, cellsPerSide + 1)
    for j in range(-cellsPerSide, cellsPerSide + 1)
      cells |> push(int2(i, j))
  sort(cells) <| $(a, b)
    return a.x * a.x + a.y * a.y < b.x * b.x + b.y * b.y
  for cell in cells
    let pos = center + (float(cell.x) * spawn_tm[0] + float(cell.y) * spawn_tm[2]) * step
    let pos2 = pos.xz
    if !is_in_area(areaId, pos2)
      continue
    let top = float3(pos.x, limitsY.y, pos.z)
    if !is_entity_found_in_grid(fixed_array(ecs_hash("vehicles"), ecs_hash("humans")), top, float3(0., -1., 0.), limitsY.y - limitsY.x, free_radius, GridEntCheck.BOUNDING)
      spawn_tm[3] = pos
      return true
  return false

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
                            supply_terminal__transportSpawnArea : string;
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
    var spawnTm = supply_terminal__transportSpawnTm
    if !find_transport_spawn_pos(supply_terminal__transportSpawnArea, supply_terminal__transportSpawnFreeRadius, spawnTm)
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
