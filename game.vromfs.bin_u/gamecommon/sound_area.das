require ecs
require DagorMath
require DagorSystem
require DagorConsole
require Mission
require level
require DagorDebug3D
require Unit
require HeroManager
require soundEvent
require soundSystem

def add_area(var bgrid : BoolList&;
             aid : int;
             bounds : float4;
             step : float;
             stride : int)
  for i in range(0, length(bgrid))
    let y = int(i / stride)
    let x = i % stride
    let point = float2(x, y) * step + float2(bounds.x, bounds.y)
    if is_in_area(aid, point)
      bgrid[i] = true

def get_grid_idx(pos : float2;
                 bounds : float4;
                 stride : int;
                 step : float) : int
  if pos.x > bounds.x && pos.x < bounds.z && pos.y > bounds.y && pos.y < bounds.w
    return int(floor(pos.x - bounds.x) / step + floor(floor(pos.y - bounds.y) / step) * float(stride))
  else
    return -1

def get_grid_value(pos : float2;
                   bgrid : BoolList;
                   bounds : float4;
                   stride : int;
                   step : float) : bool
  let i = get_grid_idx(pos, bounds, stride, step)
  return (i >= 0) ? bgrid[i] : false

def init_grid(var bgrid : BoolList&;
              bounds : float4;
              step : float;
              var out_stride : int&)
  let len = int(((bounds.z - bounds.x) * (bounds.w - bounds.y)) / step)
  out_stride = int((bounds.z - bounds.x) / step)
  bgrid |> resize(len)

[es(on_appear, on_event = EventSoundAreaInit, tag=gameClient, tag=sound)]
def sound_area_init(evt : Event;
                    sound_area__area_names : StringList;
                    sound_area__grid_step : float;
                    var sound_area__grid_stride : int&;
                    var sound_area__bgrid : BoolList&;
                    sound_area__use_height : bool;
                    var sound_area__bounds_y : float2&;
                    var sound_area__bounds : float4&)
  sound_area__bounds.x = FLT_MAX
  sound_area__bounds.y = FLT_MAX
  using() <| $(var sound_area__area_ids : IntList)
    for areaName in sound_area__area_names
      let aid = get_area_id(string(areaName))
      if (aid >= 0)
        sound_area__area_ids |> push(aid)
        let limits = get_area_limits_xz(aid)
        sound_area__bounds.x = min(sound_area__bounds.x, limits.x)
        sound_area__bounds.y = min(sound_area__bounds.y, limits.y)
        sound_area__bounds.z = max(sound_area__bounds.z, limits.z)
        sound_area__bounds.w = max(sound_area__bounds.w, limits.w)
        if sound_area__use_height
          let limitsY = get_area_limits_y(aid)
          sound_area__bounds_y.x = min(sound_area__bounds_y.x, limitsY.x)
          sound_area__bounds_y.y = max(sound_area__bounds_y.y, limitsY.y)
      else
        print("sound_area {areaName} not found")
    if sound_area__bounds.x > sound_area__bounds.z || sound_area__bounds.y > sound_area__bounds.w
      return
    init_grid(sound_area__bgrid, sound_area__bounds, sound_area__grid_step, sound_area__grid_stride)

    for aid in sound_area__area_ids
      add_area(sound_area__bgrid, aid, sound_area__bounds, sound_area__grid_step, sound_area__grid_stride)

def is_on_edge(bgrid : BoolList;
               stride : int;
               idx : int) : bool
  if idx - stride < 0 || !bgrid[idx - stride]
    return true
  if idx + stride >= length(bgrid) || !bgrid[idx + stride]
    return true
  if idx - 1 < 0 || !bgrid[idx - 1]
    return true
  if idx + 1 >= length(bgrid) || !bgrid[idx + 1]
    return true
  return false

[es(tag=gameClient, tag=sound, no_order)]
def sound_area_update_es(act : UpdateStageInfoAct;
                         sound_area__event_name : string;
                         var sound_area__event : SoundEvent&;
                         sound_area__bgrid : BoolList;
                         sound_area__grid_stride : int;
                         sound_area__grid_step : float;
                         sound_area__use_height : bool;
                         sound_area__bounds_y : float2;
                         sound_area__bounds : float4)
  let hero = get_controlled_hero()
  if hero != null && !hero.isFlightModelWrap && !hero.isDelayed
    let pos = get_listener_pos()
    if sound_area__use_height
      if pos.y < sound_area__bounds_y.x || pos.y > sound_area__bounds_y.y
        sound_area__event |> abandon()
        return
    let idx = get_grid_idx(float2(pos.x, pos.z), sound_area__bounds, sound_area__grid_stride, sound_area__grid_step)
    let isIn = idx >= 0 ? sound_area__bgrid[idx] : false
    if isIn && sound_area__event_name != ""
      if !is_playing(sound_area__event)
        sound_area__event |> play(sound_area__event_name)
      let intensity = is_on_edge(sound_area__bgrid, sound_area__grid_stride, idx) ? 0.5 : 1.
      sound_area__event |> set_var("intensity", intensity)
      sound_area__event |> set_pos(pos)
    else
      sound_area__event |> abandon()

def draw_debug_mark(pos : float3;
                    height : float;
                    color : E3DCOLOR)
  let dbgpoint0 = pos
  let dbgpoint1 = pos + float3(0., height, 0.)
  draw_cached_debug_line(dbgpoint0, dbgpoint1, color)


[es(tag=gameClient, tag=sound, REQUIRE = renderDebug, no_order)]
def sound_area_debug_update_es(act : UpdateStageInfoAct;
                               sound_area__grid_stride : int;
                               sound_area__grid_step : float;
                               sound_area__bgrid : BoolList;
                               sound_area__use_height : bool;
                               sound_area__bounds_y : float2;
                               sound_area__bounds : float4)
  var inIdx = 0
  let pos = get_listener_pos()
  inIdx = get_grid_idx(float2(pos.x, pos.z), sound_area__bounds, sound_area__grid_stride, sound_area__grid_step)

  let testPoint = float3(sound_area__bounds.x, 0.f, sound_area__bounds.y)
  let start_y = sound_area__use_height ? sound_area__bounds_y.x : get_scene_height(testPoint, false)
  let height = sound_area__use_height ? max(sound_area__bounds_y.y, 1.) : 40.

  for i in range(0, length(sound_area__bgrid))
    if !sound_area__bgrid[i]
      continue

    let y = int(i / sound_area__grid_stride)
    let x = i % sound_area__grid_stride
    let point = float2(x, y) * sound_area__grid_step + float2(sound_area__bounds.x, sound_area__bounds.y)
    let intensity = i == inIdx && is_on_edge(sound_area__bgrid, sound_area__grid_stride, inIdx) ? 0.5 : 1.
    draw_debug_mark(float3(point.x, start_y, point.y), intensity * height, i == inIdx ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFF0000FF))

  draw_debug_mark(float3(sound_area__bounds.x, start_y, sound_area__bounds.y), height, E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.x, start_y, sound_area__bounds.w), height, E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.z, start_y, sound_area__bounds.y), height, E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.z, start_y, sound_area__bounds.w), height, E3DCOLOR(0xFFFF0000))
