require ecs
require DagorMath
require DagorSystem
require DagorConsole
require Mission
require Level
require DagorDebug3D
require Unit
require HeroManager
require soundEvent
require soundSystem

def add_area(var grid : FloatList&;
             aid : int;
             bounds : float4;
             step : float;
             stride : int)
  for i in range(0, length(grid))
    let y = int(i / stride)
    let x = i % stride
    let point = float2(x, y) * step + float2(bounds.x, bounds.y)
    if is_in_area(aid, point)
      grid[i] = 1.f

def smoothern_grid(var grid : FloatList&;
                   stride : int)
  var lastVal = 0.

  for i in range(0, length(grid))
    if grid[i] > 0. && lastVal == 0.
      grid[i] = 0.5 // smooth left

    if i > 0 && grid[i] <= 0. && lastVal > 0.
      grid[i - 1] = 0.5// smooth right

    if i <= stride && grid[i] > 0. || (i > stride && grid[i] > 0. && grid[i - stride] <= 0.)
      grid[i] = 0.5 // smooth top

    if i + stride < length(grid) && grid[i] > 0. && grid[i + stride] <= 0.
      grid[i] = 0.5 // smooth bottom

    lastVal = grid[i]

def get_grid_idx(pos : float2;
                 bounds : float4;
                 stride : int;
                 step : float) : int
  if pos.x > bounds.x && pos.x < bounds.z && pos.y > bounds.y && pos.y < bounds.w
    return int(floor(pos.x - bounds.x) / step + floor(floor(pos.y - bounds.y) / step) * float(stride))
  else
    return -1

def get_grid_value(pos : float2;
                   grid : FloatList;
                   bounds : float4;
                   stride : int;
                   step : float) : float
  let i = get_grid_idx(pos, bounds, stride, step)
  return (i >= 0) ? grid[i] : 0.

def init_grid(var grid : FloatList&;
              bounds : float4;
              step : float;
              var out_stride : int&)
  let len = int(((bounds.z - bounds.x) * (bounds.w - bounds.y)) / step)
  out_stride = int((bounds.z - bounds.x) / step)
  grid |> resize(len)

[es(on_appear, on_event = EventSoundAreaInit, tag=gameClient, tag=sound)]
def sound_area_init(evt : Event;
                    sound_area__area_names : StringList;
                    sound_area__grid_step : float;
                    var sound_area__grid_stride : int&;
                    var sound_area__grid : FloatList&;
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
      else
        print("sound_area {areaName} not found")
    if sound_area__bounds.x > sound_area__bounds.z || sound_area__bounds.y > sound_area__bounds.w
      return
    init_grid(sound_area__grid, sound_area__bounds, sound_area__grid_step, sound_area__grid_stride)

    for aid in sound_area__area_ids
      add_area(sound_area__grid, aid, sound_area__bounds, sound_area__grid_step, sound_area__grid_stride)

    smoothern_grid(sound_area__grid, sound_area__grid_stride)

[es(tag=gameClient, tag=sound)]
def sound_area_update_es(act : UpdateStageInfoAct;
                         sound_area__event_name : string;
                         var sound_area__event : SoundEvent&;
                         sound_area__grid : FloatList;
                         sound_area__grid_stride : int;
                         sound_area__grid_step : float;
                         sound_area__bounds : float4)
  let hero = get_controlled_hero()
  if hero != null && !hero.isFlightModelWrap && !hero.isDelayed
    let gridVal = get_grid_value(float2(hero.pos.x, hero.pos.z), sound_area__grid, sound_area__bounds, sound_area__grid_stride, sound_area__grid_step)
    if gridVal > 0. && sound_area__event_name != ""
      if !is_playing(sound_area__event.handle)
        sound_area__event |> play(sound_area__event_name)
      sound_area__event.handle |> set_var("intensity", gridVal)
    else
      sound_area__event.handle |> abandon()

def draw_debug_mark(pos : float3;
                    height : float;
                    color : E3DCOLOR)
  let dbgpoint0 = pos
  let dbgpoint1 = pos + float3(0., height, 0.)
  draw_cached_debug_line(dbgpoint0, dbgpoint1, color)


[es(tag=gameClient, tag=sound, REQUIRE = renderDebug)]
def sound_area_debug_update_es(act : UpdateStageInfoAct;
                               sound_area__grid_stride : int;
                               sound_area__grid_step : float;
                               sound_area__grid : FloatList;
                               sound_area__bounds : float4)
  let hero = get_controlled_hero()

  var inIdx = 0
  if hero != null && !hero.isDelayed
    inIdx = get_grid_idx(float2(hero.pos.x, hero.pos.z), sound_area__bounds, sound_area__grid_stride, sound_area__grid_step)

  let testPoint = float3(sound_area__bounds.x, 0.f, sound_area__bounds.y)
  let height = get_scene_height(testPoint, false)
  for i in range(0, length(sound_area__grid))
    if sound_area__grid[i] <= 0.
      continue

    let y = int(i / sound_area__grid_stride)
    let x = i % sound_area__grid_stride
    let point = float2(x, y) * sound_area__grid_step + float2(sound_area__bounds.x, sound_area__bounds.y)
    draw_debug_mark(float3(point.x, height, point.y), sound_area__grid[i] * 30.0, i == inIdx ? E3DCOLOR(0xFFFF0000) : sound_area__grid[i] > 0.5 ? E3DCOLOR(0xFF0000FF) : E3DCOLOR(0xFF3333FF))

  draw_debug_mark(float3(sound_area__bounds.x, height, sound_area__bounds.y), 40., E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.x, height, sound_area__bounds.w), 40., E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.z, height, sound_area__bounds.y), 40., E3DCOLOR(0xFFFF0000))
  draw_debug_mark(float3(sound_area__bounds.z, height, sound_area__bounds.w), 40., E3DCOLOR(0xFFFF0000))
