options no_aot

require app
require ecs
require ecs.ecs_template
require math.base
require Unit
require HeroManager
require %appGame.infantry.ai.ai_recons_common
require DagorDebug3D
require DagorConsole
require DagorSystem
require Covers
require RendInst
require Dacoll


[ecs_template]
struct recons_debug_tmpl
  nonCreatableObj : bool = true
  reconsDebug : Tag
  recons_debug__mode : int = 1

[console_cmd(name="recons.debug")]
def recons_debug(debug_mode : int = -1)
  var debugEid = INVALID_ENTITY_ID
  var updated = false
  query() <| $ [es(REQUIRE=reconsDebug)] (eid : EntityId; var recons_debug__mode : int&)
    if debug_mode <= 0
      debugEid = eid
    else
      recons_debug__mode = debug_mode
      updated = true

  if debugEid == INVALID_ENTITY_ID
    let debugMode = debug_mode <= 0 ? 1 : debug_mode
    if updated
      console_print("RECONS DEBUG: Updated ({debugMode})")
    else
      console_print("RECONS DEBUG: Enabled ({debugMode})")
      createEntity("recons_debug_tmpl") <| $(init)
        init |> set("recons_debug__mode", debugMode)
  else
    console_print("RECONS DEBUG: Disabled (0)")
    destroyEntity(debugEid)

  query() <| $ [es] (var recon__enabled : bool&)
    recon__enabled = debug_mode != 4

[es(tag=server, on_appear)]
def recon_debug_init_es(evt : Event; var recon__enabled : bool&)
  query() <| $ [es] (recons_debug__mode : int)
    if recons_debug__mode == 4
      recon__enabled = false


[console_cmd(name="recons.generate", hint="Generates recons for whole scene, if name provided or already setup in recons__sceneName will try to save recons to file after generation")]
def recons_generate(scene_name : string = "")
  if !has_recons_manager()
    console_print("RECONS GENERATE: No recons system, create 'ai_recons_manager' entity first")
  elif !is_generating_recons()
    generate_recons(scene_name)
  else
    stop_generate_recons()

[console_cmd(name="recons.stop_generate", hint="Stops recons generation, alternatively you can call recons.generate second time")]
def recons_stop_generate()
  stop_generate_recons()

[console_cmd(name="recons.save", hint="Saves generated recons to file, if name provided first changes recons__sceneName, only works if recons were generated for whole scene")]
def recons_save(scene_name : string = "")
  if !has_recons_manager()
    console_print("RECONS SAVE: No recons system, create 'ai_recons_manager' entity")
  elif !is_recons_generated_for_whole_scene()
    console_print("RECONS SAVE: Not saved, because recons not generated for whole scene, or loaded from file and should not be re-saved")
  else
    save_recons(scene_name)

[console_cmd(name="recons.reload", hint="Reload recons from file name provided in recons__sceneName, if name provided will load from alternative scene name, not changing recons__sceneName")]
def recons_reload(scene_name : string = "")
  if !has_recons_manager()
    console_print("RECONS SAVE: No recons system, create 'ai_recons_manager' entity")
  else
    reload_recons(scene_name)

[console_cmd(name="recons.regen", hint="Generates recons only around hero for debug purposes (will not be saved to file)")]
def recons_regen(radius : float = 25.0)
  if !has_recons_manager()
    console_print("RECONS REGEN: No recons system, create 'ai_recons_manager' entity first")
  elif radius < 0.0
    console_print("RECONS REGEN: Negative radius is invalid")
  else
    let hero = get_controlled_hero()
    let hero_eid = hero != null ? hero.eid : INVALID_ENTITY_ID
    query(hero_eid) <| $ [es] (transform : float3x4)
      generate_recons_around(transform[3], radius) // not for saving


[console_cmd(name="recons.enable", hint="Enables using of recons by AI bots soldiers")]
def recons_enable(enable : bool)
  var found = false
  query() <| $ [es] (var recons__enabled : bool&)
    recons__enabled = enable
    found = true
  if !found
    console_print("RECONS ENABLE: No recons system, create 'ai_recons_manager' entity first")
  elif enable
    console_print("RECONS ENABLE: AI Enabled")
  else
    console_print("RECONS ENABLE: AI Disabled")

[console_cmd(name="recons.stat_traces")]
def recons_stat_traces(reset : bool = false)
  let hero = get_controlled_hero()
  let hero_eid = hero != null ? hero.eid : INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (var recon__stats : int3&; recon__stoppers : Point4List)
    let traced = recon__stats.x - recon__stats.y
    let prc = recon__stats.x > 0 ? ((traced * 100) / recon__stats.x) : -1
    let eff1 = recon__stats.x > 0 ? ((recon__stats.z * 100) / recon__stats.x) : -1
    let cost1 = recon__stats.x * 150
    let cost2 = traced * 150 + recon__stats.x * (50 * length(recon__stoppers)) / 128
    let eff2 = 100 - (cost1 > 0 ? ((cost2 * 100) / cost1) : -1)
    console_print("RECON STATS: traces={recon__stats.x} stopped={recon__stats.y} traced={traced}({prc}%) added={recon__stats.z}({eff1}%) cost1={cost1} cost2={cost2} eff={eff2}%")
    if reset
      recon__stats = int3(0, 0, 0)

[console_cmd(name="recons.stat_stoppers")]
def recons_stat_stoppers(count : int = 0)
  let hero = get_controlled_hero()
  let hero_eid = hero != null ? hero.eid : INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (var recon__stoppers : Point4List&; var recon__nextStopper : int&)
    let wasCount = length(recon__stoppers)
    if count > 0
      resize(recon__stoppers, count)
      recon__nextStopper %= count
      console_print("RECON STATS: stoppers oldCount={wasCount} newCount={count}")
    else
      console_print("RECON STATS: stoppers currentCount={wasCount}")


def private draw_debug_wall_buffered(pos1 : float3; pos2 : float3; height : float; color : E3DCOLOR)
  let offs = float3(0.0, height, 0.0)
  draw_debug_line_buffered(pos1, pos2, color, 1)
  draw_debug_line_buffered(pos1 + offs, pos2 + offs, color, 1)
  draw_debug_line_buffered(pos1, pos1 + offs, color, 1)
  draw_debug_line_buffered(pos2, pos2 + offs, color, 1)

def private draw_debug_recon(covers : CoversComponent; cover_id : int; trace_pos : float3; simple_mode : bool)
  assume extra = covers.coverExtra[cover_id]
  let reconType = recon_type(extra.info)

  if reconType == int(ReconType.CORNER)
    let ang1 = recon_arg1(extra.info)
    let ang2 = recon_arg2(extra.info)
    if ang1 == 0 && ang2 == 255
      if !simple_mode
        draw_debug_sphere_buffered(extra.pos, RECON_RADIUS * 0.5, E3DCOLOR(0xFF00FFFF), 1)
    else
      let dir1 = recon_ang_to_dir(ang1)
      let dir2 = recon_ang_to_dir(ang2)
      let pos = extra.pos + float3(0.0, 0.1, 0.0)
      let hgt = RECON_HEIGHT - 0.1
      draw_debug_wall_buffered(pos, pos + dir1 * 0.5, hgt, E3DCOLOR(0xFFFF00FF))
      draw_debug_wall_buffered(pos, pos + dir2 * 0.5, hgt, E3DCOLOR(0xFFFFFF00))
      if !simple_mode
        draw_debug_sphere_buffered(extra.pos, RECON_RADIUS * 0.5, E3DCOLOR(0xFF0000FF), 1)

      if trace_pos != float3()
        let curTime = get_sync_time() * 2.0
        let animTime = curTime - float(int(curTime))
        if animTime > 0.5
          let animVal = clamp(int(animTime * 255.0), 0, 255)
          let animColor = E3DCOLOR(0xFF000000 | uint(animVal << 16))
          if !simple_mode
            draw_debug_sphere_buffered(trace_pos, 0.05, animColor, 1)
    //draw_debug_sphere_buffered(pos + float3(0.0, hgt, 0.0), RECON_RADIUS * 0.5, E3DCOLOR(0xFFFF00FF), 1)
  elif !simple_mode
    draw_debug_sphere_buffered(extra.pos + float3(0.0, RECON_HSPH_1, 0.0), RECON_RADIUS, E3DCOLOR(0xFFFF00FF), 1)
    draw_debug_sphere_buffered(extra.pos + float3(0.0, RECON_HSPH_2, 0.0), RECON_RADIUS, E3DCOLOR(0xFFFF00FF), 1)


[es(tag=render, no_order, REQUIRE=reconsDebug)]
def recons_debug_draw_es(evt : UpdateStageInfoRenderDebug;
                         recons_debug__mode : int)
  let curTime = get_sync_time()

  // capzones positions (1)
  if recons_debug__mode == 3
    begin_draw_cached_debug_lines(true, false, false)
    query() <| $ [es] (capzone__insideNavmeshPositions : Point3List;
                       capzone__outsideNavmeshPositions : Point3List)
      for pos in capzone__insideNavmeshPositions
        draw_cached_debug_sphere(pos, 0.3, E3DCOLOR(0xFF00FF00), 1)
      for pos in capzone__outsideNavmeshPositions
        draw_cached_debug_sphere(pos, 0.3, E3DCOLOR(0xFFFF00FF), 1)
    end_draw_cached_debug_lines()
    // query() <| $ [es] (capzone__insideNavmeshPositions : Point3List;
    //                    capzone__outsideNavmeshPositions : Point3List)
    //   for pos in capzone__insideNavmeshPositions
    //     draw_debug_sphere_buffered(pos, 0.3, E3DCOLOR(0xFF00FF00), 1)
    //   for pos in capzone__outsideNavmeshPositions
    //     draw_debug_sphere_buffered(pos, 0.3, E3DCOLOR(0xFFFF00FF), 1)
    return

  if recons_debug__mode == 7
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if !camera__active
        return false
      let maxDist = 50.0
      var box : bbox3f
      let boxCenter = transform[3]
      box.bmin.xyz = boxCenter - float3(maxDist, FLT_MAX, maxDist)
      box.bmax.xyz = boxCenter + float3(maxDist, FLT_MAX, maxDist)
      query() <| $ [es] (var covers : CoversComponent&)
        let numExtra = length(covers.coverExtra)
        covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int; tm : mat44f#)
          if id < numExtra
            assume extra = covers.coverExtra[id]
            if recon_flag(extra.info, RCXI_FLAG_CONTAINS)
              var tracePos = float3()
              let lookFromPos = transform[3] + float3(0.0, RECON_TRACEH, 0.0)
              if get_recon_corner_trace_pos(tracePos, extra.pos, extra.info, lookFromPos)
                draw_debug_recon(covers, id, tracePos, true)
      return true
    return

  // show backtracking
  if recons_debug__mode == 1 || recons_debug__mode == 5
    query() <| $ [es] (recon__backTrackPosTime : Point4List;
                       recon__backTrackLast : int;
                       recon__backTrackLen : int)
      var iter = recon__backTrackLast
      let queueSize = length(recon__backTrackPosTime)
      for _i in range(recon__backTrackLen)
        assume elem = recon__backTrackPosTime[iter]
        draw_debug_sphere_buffered(float3(elem.x, elem.y + 0.05, elem.z), 0.2, E3DCOLOR(0x7700FF00), 1)
        iter = (iter + queueSize - 1) % queueSize

  query() <| $ [es] (transform : float3x4;
                     possessedByPlr : EntityId;
                     recon__scanHeights : float2;
                     recon__scanDistances : float4;
                     recon__stoppers : Point4List;
                     recon__elemData1 : IPoint4List;
                     recon__elemData2 : Point4List;
                     recon__elemData3 : Point4List;
                     recon__elemData4 : Point4List)
    if possessedByPlr == INVALID_ENTITY_ID
      return

    // all recons in scan distance (2)
    if recons_debug__mode == 2
      let maxDist = recon__scanDistances.y
      var box : bbox3f
      let boxCenter = transform[3]
      box.bmin.xyz = boxCenter - float3(maxDist, FLT_MAX, maxDist)
      box.bmax.xyz = boxCenter + float3(maxDist, FLT_MAX, maxDist)
      query() <| $ [es] (var covers : CoversComponent&)
        let numExtra = length(covers.coverExtra)
        covers_box_cull(covers, box) <| $ [unused_argument(tm)] (id : int; tm : mat44f#)
          //assume cover = covers.list[id]
          //assume coverDesc = covers.coverDescs[id]
          if id < numExtra
            assume extra = covers.coverExtra[id]
            if recon_flag(extra.info, RCXI_FLAG_CONTAINS)
              var tracePos = float3()
              let lookFromPos = transform[3] + float3(0.0, RECON_TRACEH, 0.0)
              if get_recon_corner_trace_pos(tracePos, extra.pos, extra.info, lookFromPos)
                draw_debug_recon(covers, id, tracePos, false)
      return

    // traced recons (1) / traced recons with disabled tracing (4)
    if recons_debug__mode == 1 || recons_debug__mode == 4
      let pos1 = transform[3] + float3(0.0, 0.3, 0.0) + transform[0] * 0.1
      let pos2 = transform[3] + float3(0.0, 1.1, 0.0) + transform[0] * 0.1
      draw_debug_capsule_buffered(pos1, pos2, 0.3, E3DCOLOR(0xFF0000FF), 8, 1)

      let originPos = transform[3] + float3(0.0, 0.2, 0.0)
      let hOffset = (recon__scanHeights.x + recon__scanHeights.y) * 0.5
      let hRadius = (recon__scanHeights.y - recon__scanHeights.x) * 0.5
      draw_debug_sphere_buffered(originPos + float3(0.0, hOffset, 0.0), hRadius, E3DCOLOR(0xFF007700), 1)
      draw_debug_sphere_buffered(originPos + transform[0] * recon__scanDistances.x, recon__scanDistances.y, E3DCOLOR(0xFF0000FF), 1)
      if recon__scanDistances.w > 0.0
        draw_debug_sphere_buffered(originPos + transform[0] * recon__scanDistances.z, recon__scanDistances.w, E3DCOLOR(0xFF0000FF), 1)

      for stop in recon__stoppers
        draw_debug_sphere_buffered(float3(stop.x, stop.y, stop.z), sqrt(stop.w), E3DCOLOR(0xFF770000), 1)

      query() <| $ [es] (covers : CoversComponent)
        for data1, data2, data3, data4 in recon__elemData1, recon__elemData2, recon__elemData3, recon__elemData4
          if data1.w == 0
            continue

          assume extra = covers.coverExtra[data1.x]

          let tracePos = data2.xyz
          let pos = extra.pos

          if data1.w == int(ReconType.CORNER)
            let dir1 = float3(data3.x, 0.0, data3.y)
            let dir2 = float3(data3.z, 0.0, data3.w)
            draw_debug_wall_buffered(pos, pos + dir1 * 0.5, RECON_HEIGHT, E3DCOLOR(0xFFFF00FF))
            draw_debug_wall_buffered(pos, pos + dir2 * 0.5, RECON_HEIGHT, E3DCOLOR(0xFFFFFF00))
            draw_debug_sphere_buffered(pos, RECON_RADIUS * 0.5, E3DCOLOR(0xFF0000FF), 1)
          else
            let color1 = E3DCOLOR(0xFFFF00FF)
            draw_debug_sphere_buffered(pos + float3(0.0, 0.3, 0.0), 0.3, color1, 1)
            draw_debug_sphere_buffered(pos + float3(0.0, 0.6, 0.0), 0.25, color1, 1)
            draw_debug_sphere_buffered(pos + float3(0.0, 1.2, 0.0), 0.2, color1, 1)

          let threat = calc_recon_threat(curTime, data4.w, data2.w)
          draw_debug_sphere_buffered(tracePos - float3(0.0, RECON_TRACEH - threat * RECON_TRACEH, 0.0), 0.03, E3DCOLOR(0xFF7700FF), 1)

          if threat > 0.9
            let playTime = curTime * 2.0
            let animTime = playTime - float(int(playTime))
            if animTime > 0.5
              let animVal = clamp(int(animTime * 255.0), 0, 255)
              let animColor = E3DCOLOR(0xFF000000 | uint(animVal << 16))
              draw_debug_sphere_buffered(tracePos, 0.05, animColor, 1)
