module ai_team_danger_zones_common shared

require ecs


let
  CUSTOMNAV_TAG_TURRETDANGER = 0
  CUSTOMNAV_TAG_DEATH = 1

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
