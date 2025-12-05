require ecs
require app
require Covers
require Dacoll
require RendInst
require PhysMat
require math.base
require DagorMath
require DagorMathUtils
require DagorConsole
require DagorSystem
require %appGame.infantry.ai.ai_recons_common
require strings

def make_scene_recons_filename(scene_name : string)
  if scene_name == ""
    return ""
  if starts_with(scene_name, "%ugm/")
    return "{scene_name}.recons.bin"
  return "gamedata/scenes/{scene_name}.recons.bin"

def private check_resize_recon_extra(var covers : CoversComponent&)
  let numCovers = length(covers.list)
  let numExtra = length(covers.coverExtra)
  if numCovers == 0
    clear(covers.coverExtra)
    return false
  if numExtra > numCovers
    resize(covers.coverExtra, numCovers)
    return true
  let diff = numCovers - numExtra
  resize(covers.coverExtra, numCovers)
  for i in range(diff)
    let idx = numExtra + i
    assume extra = covers.coverExtra[idx]
    extra.info = 0
  return true

def private clear_recon_extra()
  query() <| $ [es] (var covers : CoversComponent&)
    clear(covers.coverExtra)
    check_resize_recon_extra(covers)


let private
  RECON_H_CAST = 0.8 
  RECON_HCLIMB = 0.30 
  RECON_H_DOWN = 0.60 
  RECON_R_UP_2 = float3(0.0, RECON_HSPH_2, 0.0)
  RECON_R_UP_1 = float3(0.0, RECON_RADIUS, 0.0)
  RECON_HAIM_2 = 1.4
  RECON_HAIM_1 = 0.8
  RECON_AIMRAD = 0.125
  RECON_AIMFIT = HALF_PI * 0.1
  RECON_FIT_SEARCH_RADIUS = 8.0


require DagorDebug3D
def private draw_sph(pos : float3; rad : float; color : int; debug_show : bool = true; wait : int = 0)
  if debug_show
    let cval = color == 2 ? E3DCOLOR(0xFF00FF00) : color == 3 ? E3DCOLOR(0xFF00FFFF) : color == 4 ? E3DCOLOR(0xFFFF0000) : E3DCOLOR(0xFFFF00FF)
    draw_debug_sphere_buffered(pos, rad, cval, wait <= 0 ? 100 : wait)
def private draw_pos(pos : float3; color : int; debug_show : bool = true)
  let rad = RECON_RADIUS * 0.5
  draw_sph(pos + float3(0.0, rad, 0.0), rad, color, debug_show)


struct TraceReconCtx
  allow_passable : bool = true
  got_passable : bool = false
  debug_show : bool = false
  aim_mat_id : int = -1
  aim_cast : bool = false
  debug_1 : bool = false
  debug_2 : bool = false
  generated_count : int = 0
  skipped_count : int = 0

def private logrdbg(var tctx, msg)
  if tctx.debug_2
    logerr("{msg}")

def private init_recon_trace_ctx(var trace_ctx : TraceReconCtx&)
  trace_ctx.aim_mat_id = get_material_id("aimRay")


def private is_ri_passable(desc)
  var result = false
  let handle = desc.riExtraHandle
  if handle != RIEX_HANDLE_NULL
    let eid = find_ri_extra_eid(handle)
    query(eid) <| $ [es(REQUIRE=isDoor)] ()
      result = true
    if !result
      query(eid) <| $ [es(REQUIRE=destroyable_wall)] ()
        result = true
  return result

def private trace_recon_sph_cast(pos1 : float3; pos2 : float3; rad : float; var trace_ctx : TraceReconCtx&) : float
  var queryOut = ShapeQueryOutput()
  var passableTime = 1.0

  sphere_cast_land(pos1, pos2, rad, queryOut)

  let matId = trace_ctx.aim_cast ? trace_ctx.aim_mat_id : -1
  sphere_query_ri(pos1, pos2, rad, queryOut, matId, null) <| $(desc : RendInstDesc; t : float)
    
    
    
    if trace_ctx.allow_passable && is_ri_passable(desc)
      passableTime = t
      
      return false
    
    return true
  if passableTime < 1.0 && (queryOut.t >= 1.0 || passableTime <= queryOut.t)
    trace_ctx.got_passable = true
  
  if trace_ctx.debug_2 && trace_ctx.aim_cast
    draw_debug_line_buffered(pos1, pos2, E3DCOLOR(0xFFFF0000), 1000)
    draw_debug_line_buffered(pos1 + float3(0.0, 0.01, 0.0), pos1 + (pos2 - pos1) * queryOut.t + float3(0.0, 0.01, 0.0), E3DCOLOR(0xFFFFFF00), 1000)
  return queryOut.t

def private trace_recon_sph_from(from : float3; var pos : float3&; var trace_ctx : TraceReconCtx&) : float
  let delta = pos - from
  let t = trace_recon_sph_cast(from, pos, RECON_RADIUS, trace_ctx)
  if t < 1.0
    pos = from + delta * t
  return t

def private trace_recon_sph_vert(var pos : float3&; dist : float; var trace_ctx : TraceReconCtx&) : float
  let delta = float3(0.0, dist, 0.0)
  let t = trace_recon_sph_cast(pos, pos + delta, RECON_RADIUS, trace_ctx)
  if t < 1.0
    pos += delta * t
  else
    pos.y += dist
  return t


def private check_recon_pos_at(pos : float3; var trace_ctx : TraceReconCtx&) : bool
  let pos2 = pos + RECON_R_UP_2
  let pos1 = pos + RECON_R_UP_1
  let t = trace_recon_sph_cast(pos1, pos2, RECON_RADIUS, trace_ctx)
  return t >= 1.0

def check_recon_pos(pos : float3; var trace_ctx : TraceReconCtx&) : bool
  if !check_recon_pos_at(pos, trace_ctx)
    return false
  var dest = pos
  dest.y += RECON_RADIUS + 0.01
  if trace_recon_sph_from(dest - float3(0.01, -0.01, 0.01), dest, trace_ctx) < 1.0
    return false
  if trace_recon_sph_from(dest - float3(-0.01, -0.01, 0.01), dest, trace_ctx) < 1.0
    return false
  if trace_recon_sph_from(dest - float3(0.01, -0.01, -0.01), dest, trace_ctx) < 1.0
    return false
  if trace_recon_sph_from(dest - float3(-0.01, -0.01, -0.01), dest, trace_ctx) < 1.0
    return false
  return true


def private test_recon_pos_lower_elev(pos : float3; elev : float; var trace_ctx : TraceReconCtx&) : bool
  let pos2 = float3(pos.x, elev, pos.z)
  let pos1 = float3(pos.x, elev + RECON_H_CAST, pos.z)
  let t = trace_recon_sph_cast(pos1, pos2, RECON_RADIUS, trace_ctx)
  return t >= 1.0

def private make_recon_down(var pos : float3&; var trace_ctx : TraceReconCtx&) : bool
  var at = pos + RECON_R_UP_1
  if trace_recon_sph_vert(at, -RECON_H_DOWN, trace_ctx) >= 1.0
    return false
  pos = at - RECON_R_UP_1
  return true

def private make_recon_step(from : float3; var pos : float3&; back_off : float; var trace_ctx : TraceReconCtx&) : bool
  var tctx = trace_ctx
  let eps = 0.01

  var at = from + RECON_R_UP_1
  at.y += eps
  let startY = at.y
  if trace_recon_sph_vert(at, RECON_HCLIMB, tctx) < 1.0
    
    return false

  let step = x0z(pos) - x0z(from)
  var to = at + step
  let tforw = trace_recon_sph_from(at, to, tctx)
  if tforw >= 1.0
    if back_off > 0.0
      let bstep = normalize(step) * back_off
      var go = to + bstep
      let tadv = trace_recon_sph_from(to, go, tctx)
      if tadv < 1.0
        to += bstep * (tadv + 0.01)
  else
    if back_off > 0.0
      if back_off < length(step) * tforw
        to -= normalize(step) * back_off
      else
        to = at
    else
      
      
      return false

  at = (at + to) * 0.5
  if trace_recon_sph_vert(at, -RECON_H_DOWN, tctx) >= 1.0
    
    return false
  at.y += eps

  if trace_recon_sph_vert(to, -RECON_H_DOWN, tctx) >= 1.0
    
    return false
  to.y += eps

  if at.y > startY && !test_recon_pos_lower_elev(from, at.y, tctx)
    
    return false
  if !test_recon_pos_lower_elev(at, at.y, tctx)
    
    return false
  if !test_recon_pos_lower_elev(to, max(at.y, to.y), tctx)
    
    return false

  pos = to - RECON_R_UP_1
  pos.y -= eps
  trace_ctx = tctx
  return true

def private make_recon_step_alts(from : float3; var pos : float3&; alt_ofs1 : float3; alt_ofs2 : float3; var back_off : float; var trace_ctx : TraceReconCtx&) : bool
  if make_recon_step(from, pos, back_off, trace_ctx)
    return true
  let to = pos
  pos = to + alt_ofs1
  if make_recon_step(from, pos, back_off, trace_ctx)
    return true
  pos = to + alt_ofs2
  if make_recon_step(from, pos, back_off, trace_ctx)
    return true
  return false

def private test_recon_step_by_dir(pos : float3; dir : float3; dist : float; var trace_ctx : TraceReconCtx&) : bool
  var to = pos + dir * dist
  if !make_recon_step(pos, to, -1.0, trace_ctx)
    
    return false
  
  return true

def private test_recon_step_by_dir_alts(from : float3; var out_pos : float3&; dir : float3; dist : float; var trace_ctx : TraceReconCtx&; ofs_alt1 : float3; ofs_alt2 : float3) : bool
  out_pos = from + dir * dist
  if !make_recon_step_alts(from, out_pos, ofs_alt1, ofs_alt2, -1.0, trace_ctx)
    
    return false
  
  return true


let
  RECON_COS_22_DEG = 0.927183
  RECON_SIN_22_DEG = 0.374607
def private turn_recon_dir_22deg(dir : float3; sign : float)
  let dx = dir.x
  let dz = dir.z
  return float3(dx * RECON_COS_22_DEG + sign * dz * RECON_SIN_22_DEG, 0.0, dz * RECON_COS_22_DEG - sign * dx * RECON_SIN_22_DEG)

def private trace_recon_aim(pos : float3; dir : float3; dist : float; var trace_ctx : TraceReconCtx&; var out_crouch : bool&; aim_cast : bool) : float
  let pos1 = pos + float3(0.0, RECON_HAIM_2, 0.0)
  let pos2 = pos1 + dir * dist
  trace_ctx.aim_cast = aim_cast
  let t1 = trace_recon_sph_cast(pos1, pos2, RECON_AIMRAD, trace_ctx)
  trace_ctx.aim_cast = false
  
  
  if t1 >= 1.0
    out_crouch = false
    return t1

  let pos3 = pos + float3(0.0, RECON_HAIM_1, 0.0)
  let pos4 = pos3 + dir * dist
  trace_ctx.aim_cast = aim_cast
  let t2 = trace_recon_sph_cast(pos3, pos4, RECON_AIMRAD, trace_ctx)
  trace_ctx.aim_cast = false
  
  
  if t2 >= 1.0
    out_crouch = true
    return t2

  if trace_ctx.debug_2
    
    draw_sph(pos1 + (pos2 - pos1) * t1, RECON_AIMRAD, 3, true, 1000)
    draw_sph(pos3 + (pos4 - pos3) * t2, RECON_AIMRAD, 3, true, 1000)

  out_crouch = t2 > t1
  return out_crouch ? t2 : t1

def private trace_recon_aim_alts(pos : float3; var dir : float3&; dist : float; var trace_ctx : TraceReconCtx&;
                                 var out_crouch : bool&; allow_alts : bool) : float
  let ALT_DIST_COEF = 1.1
  var c1 = false
  let t1 = trace_recon_aim(pos, dir, dist, trace_ctx, c1, true)
  if t1 >= 1.0 || !allow_alts
    out_crouch = c1
    return t1
  let leftDir = turn_recon_dir_22deg(dir, -1.0)
  var c2 = false
  let t2 = trace_recon_aim(pos, leftDir, dist * ALT_DIST_COEF, trace_ctx, c2, true)
  if t2 >= 1.0
    dir = leftDir
    out_crouch = c2
    return t2
  let rightDir = turn_recon_dir_22deg(dir, 1.0)
  var c3 = false
  let t3 = trace_recon_aim(pos, rightDir, dist * ALT_DIST_COEF, trace_ctx, c3, true)
  if t3 >= 1.0
    dir = rightDir
    out_crouch = c3
    return t3
  var tbest = t1
  var cbest = c1
  if t2 > tbest
    tbest = t2
    cbest = c2
  if t3 > tbest
    tbest = t3
    cbest = c3
  out_crouch = cbest
  return tbest

def private trace_recon_aim_for_wall(pos : float3; var dir : float3&; dist : float; var trace_ctx : TraceReconCtx&) : bool
  var crouch = false
  if trace_recon_aim(pos, dir, dist, trace_ctx, crouch, false) < 1.0
    return true
  let leftDir = turn_recon_dir_22deg(dir, -1.0)
  if trace_recon_aim(pos, leftDir, dist, trace_ctx, crouch, false) < 1.0
    dir = leftDir
    return true
  let rightDir = turn_recon_dir_22deg(dir, 1.0)
  if trace_recon_aim(pos, rightDir, dist, trace_ctx, crouch, false) < 1.0
    dir = rightDir
    return true
  
  
  
  
  
  
  
  
  return false

def private turn_recon_dir_up(dir : float3; rad : float) : float3
  var res = normalize(float3(dir.x, 0.0, dir.z))
  var kSin, kCos : float
  sincos(rad, kSin, kCos)
  res.x *= kCos
  res.y = kSin
  res.z *= kCos
  return res

def private trace_recon_strafe_aim_corner(var in_out_pos : float3&; var out_dir : float3&;
                                          step_dir : float3; look_dir : float3; allow_alts : bool;
                                          start_dist : float; max_steps : int; step_dist : float;
                                          look_dist : float; var trace_ctx : TraceReconCtx&) : bool
  var dist = start_dist
  var look = look_dir

  let MIN_FARTHER = 3.0
  let MIN_CLOSER = 0.5
  let MIN_FARTH_T = MIN_FARTHER / look_dist
  let MIN_CLOSE_T = MIN_CLOSER / look_dist

  var found = false
  var crouch = false
  var prev = in_out_pos
  
  let twal = trace_recon_aim(in_out_pos, look, look_dist, trace_ctx, crouch, false)
  logrdbg(trace_ctx, "!!! AIM_CORNER twal={twal}")

  var tfar = 0.0
  var dfar = 0.0
  var lfar = float3()

  let alt_ofs1 = -look_dir * 0.1
  let alt_ofs2 = alt_ofs1 * 2.0

  let LOOK_UP_RAD = HALF_PI * 0.5
  let LOOK_UP_DISTCOEF = 2.0
  let lookUpDir = turn_recon_dir_up(look_dir, LOOK_UP_RAD)
  let lookSideDir = turn_recon_dir_up(step_dir, LOOK_UP_RAD)
  let lookUpDist = look_dist * LOOK_UP_DISTCOEF

  for _i in range(max_steps)
    var to = in_out_pos + step_dir * dist
    
    if !make_recon_step_alts(prev, to, alt_ofs1, alt_ofs2, -1.0, trace_ctx)
      if trace_ctx.debug_2
        
        
        logerr("!!! AIM_CORNER no step dist={dist}")
      return false
    look = look_dir
    
    var t = trace_recon_aim_alts(to, look, look_dist, trace_ctx, crouch, allow_alts)
    var td = t - twal
    logrdbg(trace_ctx, "!!! AIM_CORNER t={t}")
    if td < MIN_FARTH_T
      if trace_recon_aim(to, lookSideDir, lookUpDist, trace_ctx, crouch, true) < 1.0
        t = trace_recon_aim(to, lookUpDir, lookUpDist, trace_ctx, crouch, true)
        td = t - twal
    if td > MIN_FARTH_T
      logrdbg(trace_ctx, "!!! AIM_CORNER new tfar={t} dist={dist}")
      tfar = t
      dfar = dist
      lfar = look
      found = true
      break
    dist += step_dist
    prev = to

  if !found
    logrdbg(trace_ctx, "!!! AIM_CORNER not found")
    return false

  var best = -1.0
  var hasLook = false
  var blok = look
  var dlok = dist
  var step = step_dist * 0.5
  dist -= step
  step *= 0.5

  let MIN_STEP = 0.02
  while step > MIN_STEP
    let to = in_out_pos + step_dir * dist
    look = look_dir
    let t = trace_recon_aim_alts(to, look, look_dist, trace_ctx, crouch, allow_alts)
    if abs(t - tfar) < abs(t - twal)
      logrdbg(trace_ctx, "!!! AIM_CORNER t={t} NEW_LOOK dist={dist}")
      hasLook = true
      blok = look
      dlok = dist
      dist -= step
    else
      logrdbg(trace_ctx, "!!! AIM_CORNER t={t} NEW_DIST dist={dist}")
      
      best = dist
      dist += step
    step *= 0.5

  if best < 0.0
    if hasLook 
      logrdbg(trace_ctx, "!!! AIM_CORNER fallback best")
      best = (dfar + dlok) * 0.5
      blok = lfar
    else
      logrdbg(trace_ctx, "!!! AIM_CORNER no best (hasLook={hasLook} twal={twal} MIN_CLOSE_T={MIN_CLOSE_T} tfar={tfar} dist_delta={(tfar - twal) * look_dist}")
      return false

  logrdbg(trace_ctx, "!!! AIM_CORNER best={best}")

  if trace_ctx.debug_1
    draw_sph(in_out_pos + step_dir * best * 0.25, 0.1, 2, trace_ctx.debug_1, 2000)
    draw_sph(in_out_pos + step_dir * best * 0.50, 0.1, 2, trace_ctx.debug_1, 2000)
    draw_sph(in_out_pos + step_dir * best * 0.75, 0.1, 2, trace_ctx.debug_1, 2000)

  in_out_pos += step_dir * best
  out_dir = blok

  if trace_ctx.debug_1
    
    draw_sph(in_out_pos, 0.2, 3, trace_ctx.debug_1, 2000)
    draw_sph(in_out_pos + out_dir * 0.3, 0.1, 3, trace_ctx.debug_1, 2000)
    draw_sph(in_out_pos + out_dir * 0.6, 0.05, 3, trace_ctx.debug_1, 2000)
  return true


def recon_ang_to_byte(rad : float)
  var val = int(floor(rad * (256.0 / TWOPI)))
  if val > 255
    val = val & 255
  elif val < 0
    val = 255 - ((-val - 1) & 255)
  return val

def recon_byte_to_ang(val : int)
  return float(val) * (TWOPI / 256.0)

def recon_dir_to_ang(dir : float3)
  return atan2(dir.z, dir.x)

def recon_ang_in_range(a : int; a1 : int; a2 : int)
  return a1 <= a2 ? (a >= a1 && a <= a2) : (a >= a1 || a <= a2)

def recon_ang_range_mid(a1 : int; a2 : int)
  if a1 <= a2
    return (a1 + a2) / 2
  let a = ((a1 - 256) + a2) / 2
  return a >= 0 ? a : (a + 256)

def recon_ang_range_width(a1 : int; a2 : int)
  return a1 <= a2 ? (a2 - a1 + 1) : (a2 - a1 + 257)

def recon_ang_merge_ranges(var a1 : int&; var a2 : int&; b1 : int; b2 : int)
  let a1a = a1 > a2 ? (a1 - 256) : a1
  let b1a = b1 > b2 ? (b1 - 256) : b1
  if a1a > b2 || b1a > a2
    if a1a < 0 && b1a > 0 && a2 < b1 && a1 <= b2
      a1 = b1
      return true
    if b1a < 0 && a1a > 0 && b2 < a1 && b1 <= a2
      a2 = b2
      return true
    return false
  a1 = min(a1a, b1a)
  a2 = max(a2, b2)
  if a1 < 0
    a1 += 256
    if a1 <= a2
      a1 = 0
      a2 = 255
  return true

def recon_ang_merge_reduce(var a1 : int&; var a2 : int&; da : int)
  if a1 == a2
    return
  let w = recon_ang_range_width(a1, a2)
  if a1 > a2
    a1 -= 256
  if da * 2 >= w
    a1 = a1 + w / 2
    a2 = a1
  else
    a1 += da
    a2 -= da
  if a1 < 0
    a1 += 256
  elif a1 > 255
    a1 -= 256
  if a2 < 0
    a2 += 256
  elif a2 > 255
    a2 -= 256

def recon_ang_merge_ranges_dmin(var a1 : int&; var a2 : int&; b1 : int; b2 : int; dmin : int)
  var p1 = a1
  var p2 = a2
  var q1 = b1
  var q2 = b2
  recon_ang_merge_reduce(p1, p2, dmin)
  recon_ang_merge_reduce(q1, q2, dmin)
  if !recon_ang_merge_ranges(p1, p2, q1, q2)
    return false
  return recon_ang_merge_ranges(a1, a2, b1, b2)


def private recon_fill_extra_info(was_rcx_info : int; rcx_type : int; rcx_arg1 : int; rcx_arg2 : int)
  var info = rcx_type << RCXI_TYPE_SHIFT
  info |= rcx_arg1 & int(RCXI_ARG1_MASK)
  info |= (rcx_arg2 << RCXI_ARG2_SHIFT) & int(RCXI_ARG2_MASK)
  info |= was_rcx_info & int(RCXI_FLAGS_MASK)
  info |= int(RCXI_FLAG_CONTAINS)
  return info

def private recon_try_merge(var extra_pos : float3&; var extra_info : int&;
                            rcx_pos : float3; rcx_type : int; rcx_arg1 : int; rcx_arg2 : int) : bool
  if !recon_flag(extra_info, RCXI_FLAG_CONTAINS)
    extra_pos = rcx_pos
    extra_info = recon_fill_extra_info(extra_info, rcx_type, rcx_arg1, rcx_arg2)
    
    return true

  let MERGE_RADIUS = 1.0 
  let MERGE_RADIUS_SQ = square(MERGE_RADIUS)
  let MERGE_H_DIFF = RECON_HEIGHT * 0.5

  let distSq = distance_sq(extra_pos.xz, rcx_pos.xz)
  if distSq > MERGE_RADIUS_SQ
    return false
  if abs(rcx_pos.y - extra_pos.y) > MERGE_H_DIFF
    return false

  let rtype = recon_type(extra_info)

  if rtype == int(ReconType.COLUMN) && rcx_type == int(ReconType.CORNER)
    
    return false

  if rtype == int(ReconType.CORNER) && rcx_type == int(ReconType.CORNER)
    var ang1 = recon_arg1(extra_info)
    var ang2 = recon_arg2(extra_info)

    let ang = recon_ang_range_mid(ang1, ang2)
    let dir = recon_ang_to_dir(ang)
    
    
    

    
    if !recon_ang_merge_ranges(ang1, ang2, rcx_arg1, rcx_arg2)
      return false

    if ang1 == 0 && ang2 == 255 
      return false

    

    let rgt = float3(dir.z, 0.0, -dir.x)
    

    let avg = (extra_pos + rcx_pos) * 0.5
    let ofs1 = extra_pos - avg
    let ofs2 = rcx_pos - avg
    let o1d = dot(ofs1, dir)
    let o1r = dot(ofs1, rgt)
    let o2d = dot(ofs2, dir)
    let o2r = dot(ofs2, rgt)
    let ofd = max(o1d, o2d)
    let ofr = (o1r + o2r) * 0.5
    let pos = avg + dir * ofd + rgt * ofr

    extra_pos = pos
    
    extra_info = recon_fill_extra_info(extra_info, rtype, ang1, ang2)
    
    return true

  return false

def private recon_save_with_merge(var covers : CoversComponent&; by_cover_id : int;
                                  rcx_pos : float3; rcx_type : int; rcx_arg1 : int; rcx_arg2 : int)
  
  

  var freeExtraId = -1
  var freeDistSq = 0.0

  if by_cover_id >= 0
    assume byExtra = covers.coverExtra[by_cover_id]
    if !recon_flag(byExtra.info, RCXI_FLAG_CONTAINS)
      freeExtraId = by_cover_id
    elif recon_try_merge(byExtra.pos, byExtra.info, rcx_pos, rcx_type, rcx_arg1, rcx_arg2)
      
      return true

  var box : bbox3f
  box.bmax.xyz = rcx_pos + float3(RECON_FIT_SEARCH_RADIUS, FLT_MAX, RECON_FIT_SEARCH_RADIUS)
  box.bmin.xyz = rcx_pos - float3(RECON_FIT_SEARCH_RADIUS, FLT_MAX, RECON_FIT_SEARCH_RADIUS)

  var merged = false
  covers_box_cull(covers, box) <| $(id : int; tm : mat44f#)
    if tm.col3.xyz == float3() 
      return
    if id == by_cover_id
      return
    assume thatExtra = covers.coverExtra[id]
    if !recon_flag(thatExtra.info, RCXI_FLAG_CONTAINS)
      let distSq = distance_sq(tm.col3.xyz, rcx_pos)
      if freeExtraId < 0 || distSq < freeDistSq
        freeExtraId = id
        freeDistSq = distSq
    elif !merged
      if recon_try_merge(thatExtra.pos, thatExtra.info, rcx_pos, rcx_type, rcx_arg1, rcx_arg2)
        
        merged = true
  if merged
    return true

  if freeExtraId < 0
    
    return false

  assume thatExtra = covers.coverExtra[freeExtraId]
  thatExtra.pos = rcx_pos
  thatExtra.info = recon_fill_extra_info(thatExtra.info, rcx_type, rcx_arg1, rcx_arg2)

  
  
  
  

  return true


def private generate_recon_do_fit(var pos : float3&; var dir : float3&; var trace_ctx : TraceReconCtx&) : bool
  pos.y += RECON_HCLIMB
  if !make_recon_down(pos, trace_ctx)
    logrdbg(trace_ctx, "!!! NO-DOWN {pos.y}")
    return false

  let FIT_NOT_WALL_DIST = 3.0
  let FIT_MAX_FORW_DIST = 0.5

  if !trace_recon_aim_for_wall(pos, dir, FIT_NOT_WALL_DIST, trace_ctx)
    logrdbg(trace_ctx, "!!! NO-WALL")
    return false

  let from = pos
  pos += dir * FIT_MAX_FORW_DIST
  if !make_recon_step(from, pos, FIT_MAX_FORW_DIST - RECON_RADIUS, trace_ctx)
    pos = from

  return true

def generate_recon_do_ang_fit(pos : float3; dir : float3; right : bool; delta_ang : float; delta_max : float;
                              var trace_ctx : TraceReconCtx&) : float3
  var deltaSinL, deltaCosL : float
  sincos(delta_ang, deltaSinL, deltaCosL)
  var deltaSinR, deltaCosR : float
  sincos(-delta_ang, deltaSinR, deltaCosR)
  let algCoef = right ? 1.0 : -1.0

  let INIT_DIST = 0.7
  let SCAN_DIST = 1.5
  let SCAN_RAD = 0.25
  let SCAN_OFS = -0.05

  var pdir = normalize(dir)
  var ddir = pdir
  var dang = 0.0

  var crouch = false

  let dalg0 = float3(ddir.z, 0.0, -ddir.x) * algCoef
  let dpos0 = pos + dalg0 * SCAN_RAD + ddir * SCAN_OFS
  let t0 = trace_recon_aim(dpos0, ddir, INIT_DIST, trace_ctx, crouch, true)
  let forHit = !(t0 < 1.0)
  

  while abs(dang) < delta_max
    let dalg = float3(ddir.z, 0.0, -ddir.x) * algCoef
    let dpos = pos + dalg * SCAN_RAD + ddir * SCAN_OFS
    let hitt = trace_recon_aim(dpos, ddir, SCAN_DIST, trace_ctx, crouch, true)
    let hit = hitt < 1.0
    if trace_ctx.debug_2
      
      var rpos = dpos
      rpos.y += RECON_HAIM_2
      let phaseVal = uint(dang == 0.0 ? 255 : 0)
      draw_debug_line_buffered(rpos, rpos + ddir * SCAN_DIST, E3DCOLOR(0xFF00FF00 | phaseVal), 1500)
      rpos = dpos
      rpos.y += RECON_HAIM_1
      draw_debug_line_buffered(rpos, rpos + ddir * SCAN_DIST, E3DCOLOR(0xFF00FF00 | phaseVal), 1500)
    if forHit == hit
      
      return forHit ? pdir : ddir
    pdir = ddir
    if right == forHit
      ddir = normalize(float3(-ddir.z * deltaSinL + ddir.x * deltaCosL, 0.0, ddir.z * deltaCosL + ddir.x * deltaSinL))
      dang += delta_ang
    else
      ddir = normalize(float3(-ddir.z * deltaSinR + ddir.x * deltaCosR, 0.0, ddir.z * deltaCosR + ddir.x * deltaSinR))
      dang -= delta_ang
  
  return dir

def private generate_recon_try_walkout(from_pos : float3; is_left : bool; walk_dir : float3; look_dir : float3; allow_alts : bool;
                                       var trace_ctx : TraceReconCtx&; var covers : CoversComponent&; self_cover_id : int)
  let PRE_DIST = 0.5
  let MAX_STEPS = 4
  let STEP_DIST = 0.5
  let AIM_DIST = 5.0

  var outPos = from_pos
  var outDir = walk_dir
  if !trace_recon_strafe_aim_corner(outPos, outDir, walk_dir, look_dir, allow_alts, PRE_DIST, MAX_STEPS, STEP_DIST, AIM_DIST, trace_ctx)
    return false

  let CASTWALL_RADIUS = RECON_RADIUS - RECON_AIMRAD * 0.5

  let pos = outPos + (RECON_R_UP_2 + RECON_R_UP_1) * 0.5
  let t = trace_recon_sph_cast(pos, pos + outDir * AIM_DIST, CASTWALL_RADIUS, trace_ctx)
  var rpos = outPos + outDir * (AIM_DIST * t + CASTWALL_RADIUS)
  let tdown = trace_recon_sph_cast(rpos + RECON_R_UP_1, rpos - RECON_R_UP_2, RECON_RADIUS, trace_ctx)
  rpos += tdown * (RECON_R_UP_1 - RECON_R_UP_2)

  var dir1 : float3
  var dir2 : float3
  if is_left
    dir1 = generate_recon_do_ang_fit(rpos, outDir, false, RECON_AIMFIT, HALF_PI * 0.75, trace_ctx)
    dir2 = generate_recon_do_ang_fit(rpos, from_pos - outPos, true, RECON_AIMFIT, HALF_PI, trace_ctx)
  else
    dir1 = generate_recon_do_ang_fit(rpos, from_pos - outPos, false, RECON_AIMFIT, HALF_PI * 0.75, trace_ctx)
    dir2 = generate_recon_do_ang_fit(rpos, outDir, true, RECON_AIMFIT, HALF_PI, trace_ctx)

  let ang1 = recon_ang_to_byte(recon_dir_to_ang(dir1))
  let ang2 = recon_ang_to_byte(recon_dir_to_ang(dir2))

  let rw = recon_ang_range_width(ang1, ang2)

  let str = is_left ? "L" : "R"
  logrdbg(trace_ctx, "!!! {str}W w={rw} ang1={ang1} ang2={ang2}")

  let ANG_MIN1 = 158 
  let ANG_MIN2 = 155 

  var ok = false
  if rw >= ANG_MIN1 && t < 1.0
    logrdbg(trace_ctx, "!!! {str}W1 norm")
    ok = true
  elif rw >= ANG_MIN2 && t < 1.0
    var crouch = false
    if trace_recon_aim(rpos + RECON_R_UP_2, outDir, 1.0, trace_ctx, crouch, true) > 0.5
      logrdbg(trace_ctx, "!!! {str}W2 over")
      ok = true
  else
    logrdbg(trace_ctx, "!!! {str}WX too narrow")

  if ok
    let MIN_BACK_DIST = 1.15  
    let BACK_UPPER = float3(0.0, RECON_AIMRAD, 0.0)
    let BACK_DDIST = 0.62

    let testPos = rpos - normalize(dir1 + dir2) * BACK_DDIST
    var backDir = normalize(dir1)
    var crouch = false
    if trace_recon_aim(testPos, backDir, MIN_BACK_DIST, trace_ctx, crouch, true) < 1.0
      if trace_recon_aim(testPos + BACK_UPPER, backDir, MIN_BACK_DIST, trace_ctx, crouch, true) < 1.0
        logrdbg(trace_ctx, "!!! {str}X1 no {is_left ? "look" : "walk"}")
        
        
        ok = false
    else
      backDir = normalize(dir2)
      if trace_recon_aim(testPos, backDir, MIN_BACK_DIST, trace_ctx, crouch, true) < 1.0
        if trace_recon_aim(testPos + BACK_UPPER, backDir, MIN_BACK_DIST, trace_ctx, crouch, true) < 1.0
          logrdbg(trace_ctx, "!!! {str}X2 no {is_left ? "walk" : "look"}")
          
          ok = false

  if ok
    var qpos = rpos + RECON_R_UP_1
    if trace_recon_sph_cast(qpos + dir1 * 0.5, qpos + dir2 * 0.5, RECON_AIMRAD, trace_ctx) >= 1.0
      qpos = rpos + RECON_R_UP_2
      if trace_recon_sph_cast(qpos + dir1 * 0.5, qpos + dir2 * 0.5, RECON_AIMRAD, trace_ctx) >= 1.0
        logrdbg(trace_ctx, "!!! {str}X3 no between")
        ok = false

  if ok
    if trace_ctx.debug_2
      draw_sph(rpos + RECON_R_UP_2, RECON_RADIUS, 2, true, 1500)
    if recon_save_with_merge(covers, self_cover_id, rpos, int(ReconType.CORNER), ang1, ang2)
      trace_ctx.generated_count += 1
    else
      trace_ctx.skipped_count += 1
  else
    logrdbg(trace_ctx, "!!! {str} off")

  return true


def private generate_recon_for_cover(var covers : CoversComponent&; cover_id : int; var trace_ctx : TraceReconCtx&)
  
  assume extra = covers.coverExtra[cover_id]
  if (extra.info & int(RCXI_FLAG_PROCESSED)) != 0
    return false
  extra.info |= int(RCXI_FLAG_PROCESSED)

  assume cover = covers.list[cover_id]
  assume desc = covers.coverDescs[cover_id]

  
  
  

  let numSlots = length(desc.slots)
  let sidesNum = numSlots > 1 ? 2 : 1

  for slotSide in range(sidesNum)
    let slotIdx = slotSide == 0 ? 0 : numSlots - 1
    

    
    
    

    assume coverSlot = desc.slots[slotIdx]
    let slotPos = coverSlot.pos - cover.dir * 0.5
    let slotDir = cover.dir

    
    generate_recon_for_pos(covers, slotPos, slotDir, trace_ctx, cover_id)

    let testDist = 1.0
    var tpos = slotPos + RECON_R_UP_2
    if trace_recon_sph_cast(tpos, tpos - slotDir * testDist, RECON_RADIUS, trace_ctx) < 1.0
      tpos = slotPos + RECON_R_UP_1
      if trace_recon_sph_cast(tpos, tpos - slotDir * testDist, RECON_RADIUS, trace_ctx) < 1.0
        generate_recon_for_pos(covers, slotPos, -slotDir, trace_ctx, cover_id)

    
    
    
    
    
    
    
    
    
    
    

  return true



  
  
  
  
  
  
  
  
  







def private generate_recon_for_pos(var covers : CoversComponent&; from_pos : float3; from_dir : float3;
                                   var trace_ctx : TraceReconCtx&; self_cover_id : int)
  assume tctx = trace_ctx

  var atPos = from_pos
  var atDir = from_dir

  if !generate_recon_do_fit(atPos, atDir, tctx)
    return

  if tctx.debug_1
    draw_sph(atPos, RECON_RADIUS, 5, trace_ctx.debug_show, 1000)
    draw_sph(atPos + atDir * 0.3, 0.1, 5, trace_ctx.debug_show, 1000)
    draw_sph(atPos + atDir * 0.6, 0.1, 5, trace_ctx.debug_show, 1000)

  let forw = float3(atDir.x, 0.0, atDir.z)
  let right = float3(atDir.z, 0.0, -atDir.x)
  let diagL = normalize(forw - right)
  let diagR = normalize(forw + right)
  let backy1 = forw * -0.1
  let backy2 = backy1 * 2.0

  let testDist = 1.0
  var stepTo = float3()

  if test_recon_step_by_dir(atPos, diagL, testDist, tctx)
    logrdbg(trace_ctx, "!!! L1")
    if generate_recon_try_walkout(atPos, true, diagL, diagR, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L1A")
    elif generate_recon_try_walkout(atPos, true, -right, forw, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L1B")
  elif test_recon_step_by_dir_alts(atPos, stepTo, -right, testDist, tctx, backy1, backy2)
    logrdbg(trace_ctx, "!!! L2")
    let dirTo = normalize(stepTo - atPos)
    if generate_recon_try_walkout(atPos, true, dirTo, forw, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L2A")
    elif generate_recon_try_walkout(atPos, true, -diagR, diagL, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L2B")
  elif test_recon_step_by_dir(atPos, -diagR, testDist, tctx)
    logrdbg(trace_ctx, "!!! L3")
    if generate_recon_try_walkout(atPos, true, -diagR, diagL, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L3A")
    elif generate_recon_try_walkout(atPos, true, -forw, -right, false, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L3B")
  elif test_recon_step_by_dir(atPos, -forw, testDist, tctx)
    logrdbg(trace_ctx, "!!! L4")
    if generate_recon_try_walkout(atPos, true, -forw, -right, false, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! L4A")

  if test_recon_step_by_dir(atPos, diagR, testDist, tctx)
    logrdbg(trace_ctx, "!!! R1")
    if generate_recon_try_walkout(atPos, false, diagR, diagL, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R1A")
    elif generate_recon_try_walkout(atPos, false, right, forw, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R1B")
  elif test_recon_step_by_dir_alts(atPos, stepTo, right, testDist, tctx, backy1, backy2)
    logrdbg(trace_ctx, "!!! R2")
    let dirTo = normalize(stepTo - atPos)
    if generate_recon_try_walkout(atPos, false, dirTo, forw, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R2A")
    elif generate_recon_try_walkout(atPos, false, -diagL, diagR, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R2B")
  elif test_recon_step_by_dir(atPos, -diagL, testDist, tctx)
    logrdbg(trace_ctx, "!!! R3")
    if generate_recon_try_walkout(atPos, false, -diagL, diagR, true, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R3A")
    elif generate_recon_try_walkout(atPos, false, -forw, right, false, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R3B")
  elif test_recon_step_by_dir(atPos, -forw, testDist, tctx)
    logrdbg(trace_ctx, "!!! R4")
    if generate_recon_try_walkout(atPos, false, -forw, right, false, tctx, covers, self_cover_id)
      logrdbg(trace_ctx, "!!! R4A")


def private logrgen(msg)
  console_print("RECONS GEN: {msg}")

def private logrload(msg)
  console_print("RECONS: {msg}")

let private
  GENERATE_STEP_COVERS = 0
  GENERATE_STEP_RI_EXTRA = 1
  GENERATE_STEP_DONE = 2

struct ReconsGenCtx
  iters : int3
  count : int
  fails : int
  around : bool
  aroundPos : float3
  aroundRadSq : float
  dynamic : bool

def private recons_generate_from_covers(var tctx : TraceReconCtx&; var gctx : ReconsGenCtx&)
  var result = true
  query() <| $ [es] (var covers : CoversComponent&)
    let numCovers = length(covers.list)

    var limitLeft = 1
    if !gctx.dynamic
      flush_ri_instances()
      limitLeft = 20

    while gctx.iters.x < numCovers && limitLeft > 0
      let coverIndex = gctx.iters.x
      gctx.iters.x += 1
      if isCoverAllowable(covers, uint(coverIndex))
        var gen = false
        if gctx.around
          assume cover = covers.list[coverIndex]
          assume desc = covers.coverDescs[coverIndex]
          let numSlots = length(desc.slots)
          let coverPos = desc.slots[numSlots / 2].pos - cover.dir * 0.5
          let distSq = distance_sq(gctx.aroundPos, coverPos)
          if distSq < gctx.aroundRadSq
            gen = true
        else
          gen = true
        if gen
          logrgen("Generating recon from cover #{coverIndex} of {numCovers} {(coverIndex + 1) * 100 / numCovers}%")
          if generate_recon_for_cover(covers, coverIndex, tctx)
            --limitLeft
    if gctx.iters.x < numCovers
      result = false
  gctx.count += tctx.generated_count
  gctx.fails += tctx.skipped_count
  return result

def private recons_generate_from_ri_extra(var tctx : TraceReconCtx&; var gctx : ReconsGenCtx&)
  print("{tctx.aim_mat_id} {gctx.iters}")
  logrgen("Skipped generation from RI extra")
  return true


def recons_save_to_file(file_name : string)
  var result = false
  query() <| $ [es] (covers : CoversComponent)
    result = save_covers_extra_to_file(file_name, covers, SAVE_CVEX_IGNORE_ZERO_POS)
  return result

def recons_load_from_file(file_name : string)
  var result = false
  query() <| $ [es] (var covers : CoversComponent&)
    result = load_covers_extra_from_file(covers, file_name, LOAD_CVEX_TRY_TO_NEAREST, RECON_FIT_SEARCH_RADIUS)
  return result


def recons_save_component(eid : EntityId; component_name : string)
  query() <| $ [es] (var recons_edits__saveComponentsEids : EidList&;
                     var recons_edits__saveComponentsNames : StringList&)
    recons_edits__saveComponentsEids |> push(eid)
    recons_edits__saveComponentsNames |> push(component_name)


[event(unicast)]
struct DoReconsInitLater {}

[es(tag=server, no_order)]
def recons_init_waiter_es(evt : UpdateStageInfoAct; eid : EntityId;
                          recons__initWaitForEid : EntityId;
                          recons__initWaitForTime : float)
  if get_sync_time() < recons__initWaitForTime
    return
  sendEvent(recons__initWaitForEid, DoReconsInitLater())
  destroyEntity(eid)

[es(tag=server, no_order, on_event=(EventLevelLoaded, DoReconsInitLater))]
def recons_init_es(evt : Event;
                   eid aka recons_manager_eid : EntityId;
                   var recons__initWaitTries : int&;
                   recons__initRetryTime : float = 1.0;
                   recons__autoload : bool;
                   recons__sceneName : string)
  var gotCovers = false
  query() <| $ [es(REQUIRE=covers)] ()
    gotCovers = true
  if !gotCovers && recons__initWaitTries > 0
    --recons__initWaitTries
    logrload("Retrying init recons (waiting for CoversComponent)")
    createEntity("ai_recons_init_waiter") <| $(init)
      init |> set("recons__initWaitForEid", recons_manager_eid)
      init |> set("recons__initWaitForTime", get_sync_time() + recons__initRetryTime)
    return

  if recons__autoload && recons__sceneName != ""
    clear_recon_extra()
    query(recons_manager_eid) <| $ [es] (var recons__generated : bool&)
      recons__generated = false

    let fileName = make_scene_recons_filename(recons__sceneName)
    logrload("Loading recons from {fileName}")
    if recons_load_from_file(fileName)
      logrload("Successfully loaded recons.")
    else
      logerr("Failed to load recons from {fileName}!")

[es(tag=server, no_order, REQUIRE=aiReconsManager)]
def recons_generate_es(evt : UpdateStageInfoAct;
                       eid aka recons_manager_eid : EntityId;
                       var recons__genRunCmd : int&;
                       var recons__genRunActive : bool&;
                       recons__genRunAround : bool;
                       recons__genRunAroundPos : float3;
                       recons__genRunAroundRad : float;
                       var recons__genRunMatID : int&;
                       var recons__genRunStep : int&;
                       var recons__genRunIters : int3&;
                       var recons__genRunCount : int&;
                       var recons__genRunFails : int&;
                       var recons__genRunTimes : float2&;
                       var recons__genRunSave : bool&)
  if recons__genRunCmd != RECON_GENCMD_NONE
    var strParam : string
    query(recons_manager_eid) <| $ [es] (var recons__genRunStr : das_string&)
      if recons__genRunStr != ""
        strParam := recons__genRunStr
        recons__genRunStr := ""

    if recons__genRunCmd == RECON_GENCMD_STOP
      recons__genRunCmd = RECON_GENCMD_NONE
      if recons__genRunActive
        recons__genRunActive = false
        logrgen("Stopped by request")
      return

    if recons__genRunCmd == RECON_GENCMD_GENERATE || recons__genRunCmd == RECON_GENCMD_REGEN
      if recons__genRunCmd == RECON_GENCMD_GENERATE && strParam != ""
        query(recons_manager_eid) <| $ [es] (var recons__sceneName : das_string&)
          recons__sceneName := strParam
          recons_save_component(recons_manager_eid, "recons__sceneName")

      let shouldTryToSave = recons__genRunCmd == RECON_GENCMD_GENERATE

      recons__genRunCmd = RECON_GENCMD_NONE
      recons__genRunActive = true

      var tctx : TraceReconCtx = TraceReconCtx()
      init_recon_trace_ctx(tctx)
      recons__genRunMatID = tctx.aim_mat_id

      recons__genRunStep = GENERATE_STEP_COVERS
      recons__genRunIters = int3(0, 0, 0)
      recons__genRunCount = 0
      recons__genRunFails = 0
      recons__genRunTimes.x = get_sync_time()
      recons__genRunSave = shouldTryToSave

      clear_recon_extra()
      query(recons_manager_eid) <| $ [es] (var recons__generated : bool&)
        recons__generated = false

      query() <| $ [es] (var covers : CoversComponent&)
        if !check_resize_recon_extra(covers)
          recons__genRunStep = GENERATE_STEP_DONE
          recons__genRunSave = false

      if recons__genRunStep != GENERATE_STEP_DONE
        if recons__genRunAround
          logrgen("Started for pos=({recons__genRunAroundPos}) radius={recons__genRunAroundRad} (no saving to file)")
        else
          query(recons_manager_eid) <| $ [es] (recons__sceneName : string)
            if recons__sceneName != ""
              logrgen("Started (for whole level, will save to {make_scene_recons_filename(recons__sceneName)}")
            else
              logrgen("Started (for whole level, no saving to file, because recons__sceneName is empty)")

    if recons__genRunCmd == RECON_GENCMD_SAVE
      recons__genRunCmd = RECON_GENCMD_NONE
      if !is_recons_generated_for_whole_scene()
        logrgen("Recons generated not for whole scene")
        return

      if strParam != ""
        query(recons_manager_eid) <| $ [es] (var recons__sceneName : das_string&)
          recons__sceneName := strParam
          recons_save_component(recons_manager_eid, "recons__sceneName")

      query(recons_manager_eid) <| $ [es] (recons__sceneName : string)
        if recons__sceneName == ""
          logrgen("No saving (recons__sceneName is empty)")
        else
          let fileName = make_scene_recons_filename(recons__sceneName)
          logrgen("Saving to {fileName}")
          if recons_save_to_file(fileName)
            logrgen("Successfully saved recons. Please, save your scene now!")
          else
            logrgen("Failed to save recons!")
      return

    if recons__genRunCmd == RECON_GENCMD_RELOAD
      recons__genRunCmd = RECON_GENCMD_NONE

      clear_recon_extra()
      query(recons_manager_eid) <| $ [es] (var recons__generated : bool&)
        recons__generated = false

      query(recons_manager_eid) <| $ [es] (recons__sceneName : string)
        let sceneName = strParam != "" ? strParam : recons__sceneName
        if sceneName == ""
          logrgen("Not loaded (recons__sceneName is empty)")
        else
          let fileName = make_scene_recons_filename(sceneName)
          logrgen("Loading recons from {fileName}")
          if recons_load_from_file(fileName)
            logrgen("Successfully loaded recons.")
          else
            logrgen("Failed to load recons!")
      return

  if recons__genRunActive
    var tctx : TraceReconCtx = TraceReconCtx()
    tctx.aim_mat_id = recons__genRunMatID

    if recons__genRunAround
      tctx.debug_show = true

    var gctx : ReconsGenCtx
    gctx.iters = recons__genRunIters
    gctx.count = recons__genRunCount
    gctx.fails = recons__genRunFails
    gctx.around = recons__genRunAround
    gctx.aroundPos = recons__genRunAroundPos
    gctx.aroundRadSq = square(recons__genRunAroundRad)
    gctx.dynamic = false

    if recons__genRunStep == GENERATE_STEP_COVERS
      if recons_generate_from_covers(tctx, gctx)
        recons__genRunStep = GENERATE_STEP_RI_EXTRA
        recons__genRunIters = int3(0, 0, 0)
    elif recons__genRunStep == GENERATE_STEP_RI_EXTRA
      if recons_generate_from_ri_extra(tctx, gctx)
        recons__genRunStep = GENERATE_STEP_DONE
        recons__genRunIters = int3(0, 0, 0)
    elif recons__genRunStep == GENERATE_STEP_DONE
      recons__genRunTimes.y = get_sync_time()
      recons__genRunActive = false

      let totalTime = recons__genRunTimes.y - recons__genRunTimes.x

      var finalCount = 0
      query() <| $ [es] (var covers : CoversComponent&)
        for extra in covers.coverExtra
          if extra.pos != float3() && recon_flag(extra.info, RCXI_FLAG_CONTAINS)
            ++finalCount

      logrgen("Finished ({gctx.count} recons generated, merged to {finalCount} recons, time {totalTime}s, {gctx.fails} failed to fit)")

      if recons__genRunSave
        query(recons_manager_eid) <| $ [es] (var recons__generated : bool&; recons__sceneName : string)
          recons__generated = true
          if recons__sceneName == ""
            logrgen("No saving (recons__sceneName is empty)")
          else
            let fileName = make_scene_recons_filename(recons__sceneName)
            logrgen("Saving to {fileName}")
            if recons_save_to_file(fileName)
              logrgen("Successfully saved recons. Please, save your scene now!")
            else
              logrgen("Failed to save recons!")
    else
      recons__genRunActive = false
      logrgen("Aborted (bad step)")

    recons__genRunIters = gctx.iters
    recons__genRunCount = gctx.count
    recons__genRunFails = gctx.fails

  if recons__genRunActive
    return

  





