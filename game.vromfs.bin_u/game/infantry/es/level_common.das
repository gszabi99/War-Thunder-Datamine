module level_common shared
require math.maybe_pos public
require math.base
require ecs
require DagorMath
require gameObject


def is_pos_indoor(pos : float3; search_threshold = 0.5f) : bool
  var indoor = false
  find_query() <| $ [es] (game_objects : GameObjects)
    indoor = is_pos_indoor(game_objects, pos, search_threshold)
    return true
  return indoor


def is_pos_indoor(game_objects : GameObjects; pos : float3; search_threshold = 0.5f) : bool
  let box = BBox3(pos, search_threshold)
  var indoor = false
  game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    indoor ||= IDENT_BBOX & (inverse(tm) * pos)
  return indoor


def get_nearest_indoor_pos(pos : float3; radius : float) : MaybePos
  var result = MaybePos()
  find_query() <| $ [es] (game_objects : GameObjects)
    result = get_nearest_indoor_pos(game_objects, pos, radius)
    return true
  return result


def get_nearest_indoor_pos(game_objects : GameObjects; pos : float3; radius : float) : MaybePos
  let box = BBox3(pos, radius * 2f)
  var result = MaybePos()
  var maxDistanceSq = square(radius)
  game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    let distSq = distance_sq(pos, tm[3])
    if distSq < maxDistanceSq
      maxDistanceSq = distSq
      result = MaybePos(tm[3])
  return result


def find_random_game_object(game_objects : GameObjects; obj_type : string; box : BBox3; is_valid : block<(pos : float3x4#) : variant<pos : auto(T); invalid : bool>>) : variant<pos : T; invalid : bool>
  var positions : array<T>
  game_objects |> get_scene_game_objects_by_name(obj_type) |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
    let res = invoke(is_valid, tm)
    if res is pos
      positions |> push(res as pos)
  return length(positions) == 0 ? variant<pos : T; invalid : bool>(invalid = true) : variant<pos : T; invalid : bool>(pos = positions[grnd() % length(positions)])


def find_random_game_object_in_tm(game_objects : GameObjects; obj_type : string; transform : float3x4;
                                  is_valid : block<(pos : float3x4#) : variant<pos : auto(T); invalid : bool>>) : variant<pos : T; invalid : bool> const
  let zoneBox = transform * IDENT_BBOX
  let invTm = inverse(transform)
  let res = find_random_game_object(game_objects, obj_type, zoneBox) <| $(pos : float3x4#)
    if IDENT_BBOX & (invTm * pos[3])
      return invoke(is_valid, pos)
    return variant<pos : T; invalid : bool>(invalid = true)
  return res





















