module ai_team_nav_zones_common shared

require ecs
require math.base


let
  CUSTOMNAV_TAG_TURRETDANGER = 0
  CUSTOMNAV_TAG_DEATH = 1
  CUSTOMNAV_TAG_GROUPING = 2

def danger_zones_list_init(capacity : int;
                           var list : int3&;
                           var prev_next_list : IPoint2List&;
                           var areas_data  : IntList&;
                           var areas_times : FloatList&)
  if length(prev_next_list) > 0
    return

  assume head_node = list.x
  assume tail_node = list.y
  assume free_node = list.z

  resize(areas_data, capacity)
  resize(areas_times, capacity)
  resize(prev_next_list, capacity)

  for i in range(capacity)
    prev_next_list[i] = int2(-1, i + 1)
  prev_next_list[capacity - 1].y = -1

  free_node = 0
  head_node = -1
  tail_node = -1

def danger_zones_list_grow(var list : int3&;
                           var prev_next_list : IPoint2List&;
                           var areas_data  : IntList&;
                           var areas_times : FloatList&)
  assume free_node = list.z

  let oldCapacity = length(prev_next_list)
  let newCapacity = oldCapacity * 2

  resize(prev_next_list, newCapacity)
  resize(areas_data, newCapacity)
  resize(areas_times, newCapacity)

  for i in oldCapacity..newCapacity
    prev_next_list[i] = int2(-1, i + 1)
  prev_next_list[newCapacity - 1].y = free_node

  free_node = oldCapacity

def danger_zones_list_insertBefore(at : int; idx : int;
                                   var head_node : int&;
                                   var prev_next_list : IPoint2List&)
  let prev = prev_next_list[at].x
  prev_next_list[idx] = int2(prev, at)
  prev_next_list[at].x = idx
  if prev != -1
    prev_next_list[prev].y = idx
  else
    head_node = idx

def danger_zones_list_insertAfter(at : int; idx : int;
                                  var tail_node : int&;
                                  var prev_next_list : IPoint2List&)
  let next = prev_next_list[at].y
  prev_next_list[idx] = int2(at, next)
  prev_next_list[at].y = idx
  if next != -1
    prev_next_list[next].x = idx
  else
    tail_node = idx

def danger_zones_list_insertSorted(area_id : int;
                                   area_time : float;
                                   var list : int3&;
                                   var prev_next_list : IPoint2List&;
                                   var areas_data  : IntList&;
                                   var areas_times : FloatList&)
  assume head_node = list.x
  assume tail_node = list.y
  assume free_node = list.z

  if free_node == -1
    danger_zones_list_grow(list, prev_next_list, areas_data, areas_times)

  let i = free_node
  free_node = prev_next_list[i].y

  areas_data[i] = area_id
  areas_times[i] = area_time
  prev_next_list[i] = int2(-1, -1)

  if head_node == -1
    head_node = i
    tail_node = i
    return i

  var cur = tail_node
  while cur != -1
    if areas_times[cur] <= area_time
      danger_zones_list_insertAfter(cur, i, tail_node, prev_next_list)
      return i
    cur = prev_next_list[cur].x

  danger_zones_list_insertBefore(head_node, i, head_node, prev_next_list)
  return i

def danger_zones_list_remove(idx : int;
                             var list : int3&;
                             var prev_next_list : IPoint2List&)
  assume head_node = list.x
  assume tail_node = list.y
  assume free_node = list.z

  let prev = prev_next_list[idx].x
  let next = prev_next_list[idx].y

  if prev != -1
    prev_next_list[prev].y = next
  else
    head_node = next

  if next != -1
    prev_next_list[next].x = prev
  else
    tail_node = prev

  prev_next_list[idx] = int2(-1, free_node)
  free_node = idx

  return next


let
  MAX_NAV_GROUPS_PER_TEAM = 30

def team_nav_grouping_zones_usage_team_mask(team : int)
  if team < 1 || team > 2
    return 0
  return (1 << MAX_NAV_GROUPS_PER_TEAM) - 1

def team_nav_grouping_zones_usage_mask(team : int; zone_idx : int)
  if team < 1 || team > 2 || zone_idx < 0 || zone_idx >= MAX_NAV_GROUPS_PER_TEAM
    return 0
  return 1 << zone_idx


def is_point_in_nav_grouping_zone(pos : float3; zone_pos_rad : float4; zone_heights : float2)
  return distance_sq(pos.xz, zone_pos_rad.xz) < square(zone_pos_rad.w) && pos.y >= zone_heights.x && pos.y <= zone_heights.y

def is_point_in_nav_grouping_zone(pos : float3; agent_team : int; agent_team_eid : EntityId;
                                  agent_grouping_team : int; agent_grouping_zone : int)
  var result = false
  let agentSelfGroupingZoneIdx = agent_team == agent_grouping_team ? agent_grouping_zone : -1
  query(agent_team_eid) <| $ [es] (team_grouping_zones__commonData : IPoint3List;
                                   team_grouping_zones__lastPosRads : Point4List;
                                   team_grouping_zones__lastHeights : Point2List)
    let numZones = length(team_grouping_zones__lastPosRads)
    for zoneIdx in range(numZones)
      if zoneIdx == agentSelfGroupingZoneIdx
        continue
      if team_grouping_zones__commonData[zoneIdx].y > 0
        let posRad = team_grouping_zones__lastPosRads[zoneIdx]
        let heights = team_grouping_zones__lastHeights[zoneIdx]
        if is_point_in_nav_grouping_zone(pos, posRad, heights)
          result = true
          break
  return result
