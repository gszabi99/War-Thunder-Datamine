module ai_recons_common shared

require ecs
require math.base
require DagorMath
require Covers


enum ReconType : int
  FREE     = 0
  CORNER   = 1
  COLUMN   = 2
  DOWNHOLE = 3
  NICHE    = 4
  STANDUP  = 5
  JUMPDOWN = 6
  CLIMBUP  = 7

let
  RECON_RADIUS = 0.4
  RECON_HSPH_2 = 1.2 
  RECON_HSPH_1 = 0.7 
  RECON_HEIGHT = 1.6 
  RECON_TRACEH = 1.5 


let 
  RCXI_FLAG_CONTAINS   = 0x00010000 
  RCXI_FLAG_PROCESSED  = 0x00020000 
  RCXI_FLAG_IMPORTANT  = 0x00040000 
  RCXI_FLAG_SAFECACHED = 0x00080000 
  RCXI_FLAG_SAFE_L     = 0x00100000 
  RCXI_FLAG_SAFE_R     = 0x00200000 
  RCXI_FLAG_SAFE_B     = 0x00400000 
  RCXI_FLAG_SAFE_U     = 0x00800000 

  RCXI_TYPE_SHIFT      = 24
  RCXI_TYPE_MASK       = 0x7F000000
  RCXI_ARG1_MASK       = 0x000000FF
  RCXI_ARG2_MASK       = 0x0000FF00
  RCXI_ARG2_SHIFT      = 8
  RCXI_FLAGS_MASK      = 0x00FF0000

def recon_type(info : int)
  return info >> RCXI_TYPE_SHIFT
def recon_arg1(info : int)
  return info & int(RCXI_ARG1_MASK)
def recon_arg2(info : int)
  return (info & int(RCXI_ARG2_MASK)) >> RCXI_ARG2_SHIFT
def recon_flag(info : int; flag : uint)
  return (info & int(flag)) != 0

def recon_ang_to_dir(val : int)
  let rad = float(val) * (TWOPI / 256.0)
  var dirSin, dirCos : float
  sincos(rad, dirSin, dirCos)
  return float3(dirCos, 0.0, dirSin)


def get_recon_corner_trace_pos(var out_pos : float3&; base_pos : float3; info : int; look_from_pos : float3)
  let ang1 = recon_arg1(info)
  let ang2 = recon_arg2(info)
  if ang1 == 0 && ang2 == 255
    return false

  out_pos = base_pos
  out_pos.y += RECON_TRACEH

  var lookDir = look_from_pos - out_pos
  lookDir.y = 0.0
  lookDir = normalize(lookDir)
  let alongDir = float3(lookDir.z, 0.0, -lookDir.x)

  let dir1 = recon_ang_to_dir(ang1)
  let dir2 = recon_ang_to_dir(ang2)
  let dot1 = dot(dir1, alongDir) > 0.0
  let dot2 = dot(dir2, alongDir) > 0.0
  if dot1 != dot2
    return false

  if !dot1
    out_pos += alongDir * 0.5
  else
    out_pos -= alongDir * 0.5
  return true

def get_recon_corner_dirs_packed(info : int)
  let ang1 = recon_arg1(info)
  let ang2 = recon_arg2(info)
  let dir1 = recon_ang_to_dir(ang1)
  let dir2 = recon_ang_to_dir(ang2)
  return float4(dir1.x, dir1.z, dir2.x, dir2.z)

def scan_recons_corners(pos : float3; radius : float; out_recons_cb : block<(pos : float3; dir1 : float3; dir2 : float3) : void>)
  query() <| $ [es] (var covers : CoversComponent&)
    if length(covers.coverExtra) != length(covers.list)
      return
    var box : bbox3f
    let boxCenter = pos
    box.bmax.xyz = boxCenter + float3(radius, 3.5, radius)
    box.bmin.xyz = boxCenter + float3(-radius, -3.5, -radius)
    covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int; tm : mat44f#)
      assume extra = covers.coverExtra[id]
      let reconType = recon_type(extra.info)
      if !recon_flag(extra.info, RCXI_FLAG_CONTAINS) || reconType != int(ReconType.CORNER)
        return
      let ang1 = recon_arg1(extra.info)
      let ang2 = recon_arg2(extra.info)
      let dir1 = recon_ang_to_dir(ang1)
      let dir2 = recon_ang_to_dir(ang2)
      out_recons_cb(extra.pos, dir1, dir2)


def calc_recon_threat(t : float; t0 : float; v0 : float)
  if v0 < 1.0
    return clamp(v0 + cvt(t, t0, t0 + 15.0, 0.0, 1.0), 0.0, 1.0)
  return clamp(v0 - cvt(t, t0, t0 + 15.0, 0.0, v0 - 1.0), 1.0, v0)

def is_recon_in_fov(trace_pos : float3; look_from_pos : float3; look_by_dir : float3)
  return dot(normalize(trace_pos - look_from_pos), look_by_dir) > 0.85

def fade_recon_threat(cur_time : float; var t0 : float&; var v0 : float&)
  let threat = calc_recon_threat(cur_time, t0, v0)
  if threat <= 0.001
    return false
  let newValue = threat * 0.97
  t0 = cur_time
  v0 = newValue
  return true

def calc_recon_hash(key : int)
  return key

def try_load_recon_threat(team_eid : EntityId; key : int; t : float)
  var threat = -1.0
  query(team_eid) <| $ [es] (recon_team__memoryRecons : IntList;
                             recon_team__memoryThreats : Point2List)
    if recon_team__memoryRecons |> empty()
      return
    let memIdx = calc_recon_hash(key) % length(recon_team__memoryRecons)
    if recon_team__memoryRecons[memIdx] == key
      let memThreat = recon_team__memoryThreats[memIdx]
      threat = calc_recon_threat(t, memThreat.x, memThreat.y)
  return threat

def try_save_recon_threat(team_eid : EntityId; key : int; t : float; t0 : float; v0 : float)
  var result = false
  query(team_eid) <| $ [es] (var recon_team__memoryRecons : IntList&;
                             var recon_team__memoryThreats : Point2List&)
    if recon_team__memoryRecons |> empty()
      return
    let saveThreat = float2(t, calc_recon_threat(t, t0, v0))
    let memIdx = calc_recon_hash(key) % length(recon_team__memoryRecons)
    if recon_team__memoryRecons[memIdx] < 0
      recon_team__memoryRecons[memIdx] = key
      recon_team__memoryThreats[memIdx] = saveThreat
      result = true
    else
      let thatThreat = recon_team__memoryThreats[memIdx]
      let thatValue = calc_recon_threat(t, thatThreat.x, thatThreat.y)
      if abs(thatValue - 1.0) < 0.001 || thatValue > saveThreat.y
        recon_team__memoryRecons[memIdx] = key
        recon_team__memoryThreats[memIdx] = saveThreat
        result = true
  return result


def has_recons_manager()
  var result = false
  query() <| $ [es(REQUIRE=aiReconsManager)] ()
    result = true
  return result

def is_generating_recons()
  var result = false
  query() <| $ [es(REQUIRE=aiReconsManager)] (recons__genRunActive : bool)
    result = recons__genRunActive
  return result

def is_recons_generated_for_whole_scene()
  var result = false
  query() <| $ [es(REQUIRE=aiReconsManager)] (recons__generated : bool)
    result = recons__generated
  return result

let
  RECON_GENCMD_STOP = -1
  RECON_GENCMD_NONE = 0
  RECON_GENCMD_GENERATE = 1
  RECON_GENCMD_REGEN = 2
  RECON_GENCMD_SAVE = 3
  RECON_GENCMD_RELOAD = 4

def generate_recons(scene_name : string)
  var found = false
  query() <| $ [es(REQUIRE=aiReconsManager)] (var recons__genRunCmd : int&;
                                              var recons__genRunStr : das_string&;
                                              var recons__genRunActive : bool&;
                                              var recons__genRunAround : bool&)
    recons__genRunCmd = RECON_GENCMD_GENERATE
    recons__genRunStr := scene_name
    recons__genRunActive = false
    recons__genRunAround = false
    found = true
  if !found
    createEntity("ai_recons_manager") <| $(init)
      init |> set("recons__genRunCmd", RECON_GENCMD_GENERATE)
      init |> set("recons__genRunStr", scene_name)

def generate_recons_around(pos : float3; radius : float)
  var found = false
  query() <| $ [es(REQUIRE=aiReconsManager)] (var recons__genRunCmd : int&;
                                              var recons__genRunStr : das_string&;
                                              var recons__genRunActive : bool&;
                                              var recons__genRunAround : bool&;
                                              var recons__genRunAroundPos : float3&;
                                              var recons__genRunAroundRad : float&)
    recons__genRunCmd = RECON_GENCMD_REGEN
    recons__genRunStr := ""
    recons__genRunActive = false
    recons__genRunAround = true
    recons__genRunAroundPos = pos
    recons__genRunAroundRad = radius
    found = true
  if !found
    createEntity("ai_recons_manager") <| $(init)
      init |> set("recons__genRunCmd", RECON_GENCMD_REGEN)
      init |> set("recons__genRunStr", "")
      init |> set("recons__genRunAround", true)
      init |> set("recons__genRunAroundPos", pos)
      init |> set("recons__genRunAroundRad", radius)

def stop_generate_recons()
  query() <| $ [es(REQUIRE=aiReconsManager)] (var recons__genRunCmd : int&;
                                              var recons__genRunStr : das_string&)
    recons__genRunCmd = -1
    recons__genRunStr := ""

def save_recons(scene_name : string)
  query() <| $ [es(REQUIRE=aiReconsManager)] (var recons__genRunCmd : int&;
                                              var recons__genRunStr : das_string&)
    recons__genRunCmd = RECON_GENCMD_SAVE
    recons__genRunStr := scene_name

def reload_recons(scene_name : string)
  query() <| $ [es(REQUIRE=aiReconsManager)] (var recons__genRunCmd : int&;
                                              var recons__genRunStr : das_string&)
    recons__genRunCmd = RECON_GENCMD_RELOAD
    recons__genRunStr := scene_name
