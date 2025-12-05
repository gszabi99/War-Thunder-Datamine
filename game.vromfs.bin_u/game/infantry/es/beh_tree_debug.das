options no_aot
require ecs
require ecs.common
require app
require DagorConsole
require DagorDebug3D
require DagorMath
require DngWalkerai
require DngBehTree
require BehNodes
require walkerai
require math
require math.base
require DngHuman
require HumanPhys
require ecs.ecs_template
require strings
require %appGame.infantry.es.net_console_macro


[ecs_template]
struct global_debug_beh_tree
  global_beh_tree__debug : int
  global_beh_tree__showDebugLog : bool
  global_entity_danger__debug : bool


[ecs_template]
struct debug_bot_temp_template
  beh_tree__debug : bool
  beh_tree__debugMode : int
  beh_tree__debugLog : Array
  entity_danger__debug : bool
  beh_tree__showDebugLog : bool


[ecs_template]
struct global_debug_attract_points
  attract_points__debugDraw : bool


def toggle_bots_template(template_name : string; activate : bool)
  query() <| $ [es(REQUIRE_NOT=controlledHero)] (eid : EntityId; beh_tree__enabled : bool)
    if beh_tree__enabled
      let templateName = getEntityTemplateName(eid)
      var newTemplate = remove_sub_template_name(templateName, template_name)
      if activate
        newTemplate = "{newTemplate}+{template_name}"
      print("ai: {templateName} -> {newTemplate}")
      remote_recreate_entity_from(eid, newTemplate)


[net_console_cmd(name="ai.debug_server_bots")]
def server_debug_behaviour_tree(activate : bool = true)
  toggle_bots_template("squad_member_server_debug_ai", activate)


[es(tag=(server, dev), REQUIRE=beh_tree__server_debug, no_order)]
def sync_server_beh_tree_state(evt : UpdateStageInfoAct; beh_tree : BehaviourTree; var beh_tree__debugState : das_string)
  beh_tree__debugState := beh_tree_current_name(beh_tree, true)


[es(tag=(render, dev), REQUIRE=beh_tree__server_debug, REQUIRE_NOT=deadEntity, no_order)]
def draw_server_beh_tree_state(evt : UpdateStageInfoRenderDebug; transform : float3x4; beh_tree__debugState : string)
  let pos = transform[3]
  add_debug_text_mark(pos, "ai: {beh_tree__debugState}", -1, 0f, E3DCOLOR(0xFFFFFFFF))


[es(tag=(render, dev), REQUIRE_NOT=deadEntity, after=beh_tree_update_es)]
def beh_tree_debug_es(evt : UpdateStageInfoRenderDebug; transform : float3x4;
                      eid : EntityId;
                      squad_member__squad : EntityId = INVALID_ENTITY_ID;
                      human_net_phys : HumanActor const?;
                      beh_tree : BehaviourTree; team : int = 0;
                      beh_tree__debug : bool;
                      beh_tree__debugMode : int = 1;
                      beh_tree__debugSym1 : int3 = int3(0, 0, 0);
                      beh_tree__debugSym2 : int3 = int3(0, 0, 0);
                      beh_tree__debugSym3 : int3 = int3(0, 0, 0);
                      beh_tree__debugSymU : int3 = int3(0, 0, 0))
  if beh_tree__debug
    var pos = transform[3]
    if beh_tree__debugMode == 1
      beh_tree |> beh_tree_drawDebug()
      add_debug_text_mark(pos, beh_tree |> beh_tree_current_name(true), -1, 0f, E3DCOLOR(0x00000000))
    elif beh_tree__debugMode == 2 || beh_tree__debugMode == 3 || beh_tree__debugMode == 5
      let isLeader = (get_Eid(squad_member__squad, "squad__leader") ?? INVALID_ENTITY_ID) == eid
      if beh_tree__debugMode == 2
        beh_tree |> beh_tree_drawDebug()
      elif beh_tree__debugMode == 5
        if isLeader
          query(squad_member__squad) <| $ [es] (squadAI_tactical__path : Point3List)
            let len = length(squadAI_tactical__path)
            if len > 0
              var prevPt = squadAI_tactical__path[0]
              let drawOfs = float3(0.0, 0.20, 0.0)
              let drawOfs2 = float3(0.00, 0.22, 0.02)
              draw_debug_sphere_buffered(prevPt + drawOfs, 0.1, E3DCOLOR(0xFF00FFFF), 8, 1)
              let midPt = (pos + prevPt) * 0.5 + float3(0.0, 3.5, 0.0)
              draw_debug_line_buffered(pos, midPt, E3DCOLOR(0xFF00FFFF), 1)
              draw_debug_line_buffered(midPt, prevPt + drawOfs, E3DCOLOR(0xFF00FFFF), 1)
              for i in range(1, len)
                let nextPt = squadAI_tactical__path[i]
                draw_debug_line_buffered(prevPt + drawOfs, nextPt + drawOfs, E3DCOLOR(0xFFFFFFFF), 1)
                draw_debug_line_buffered(prevPt + drawOfs2, nextPt + drawOfs2, E3DCOLOR(0xFFFFFFFF), 1)
                if i == len - 1
                  draw_debug_sphere_buffered(nextPt + drawOfs, 0.25, E3DCOLOR(0xFFFF00FF), 8, 1)
                prevPt = nextPt
      if isLeader
        add_debug_text_mark(pos, "={team}=", -1, 0f, E3DCOLOR(0x00000000))
      else
        add_debug_text_mark(pos, "{team}", -1, 0f, E3DCOLOR(0x00000000))
    elif beh_tree__debugMode == 4
      pos.y += 0.5
      assume sym1 = beh_tree__debugSym1
      assume sym2 = beh_tree__debugSym2
      assume sym3 = beh_tree__debugSym3
      if sym1.x > 0
        let isLeader = (get_Eid(squad_member__squad, "squad__leader") ?? INVALID_ENTITY_ID) == eid
        let symB = to_char(sym1.x)
        let symA = to_char(sym1.z)
        let symRB = to_char(sym2.z)
        let symRA = to_char(sym3.y)
        if sym2.y != 0
          let symR = sym2.y > 0 ? "r" : "R"
          let idxR = abs(sym2.y)
          if isLeader
            add_debug_text_mark(pos, "={team}: {symB}{sym1.y}~{symA}{sym2.x} {symR}{idxR}:{symRA}{sym3.z}{symRB}{sym3.x}=", -1, 1.0, E3DCOLOR(0x000000))
          else
            add_debug_text_mark(pos, "{team}: {symB}{sym1.y}~{symA}{sym2.x} {symR}{idxR}:{symRA}{sym3.z}{symRB}{sym3.x}", -1, 1.0, E3DCOLOR(0x000000))
        else
          if isLeader
            add_debug_text_mark(pos, "={team}: {symB}{sym1.y}~{symA}{sym2.x}=", -1, 1.0, E3DCOLOR(0x000000))
          else
            add_debug_text_mark(pos, "{team}: {symB}{sym1.y}~{symA}{sym2.x}", -1, 1.0, E3DCOLOR(0x000000))
    elif beh_tree__debugMode == 6
      pos.y += 0.5
      assume sym1 = beh_tree__debugSym1
      assume sym2 = beh_tree__debugSym2
      let isLeader = (get_Eid(squad_member__squad, "squad__leader") ?? INVALID_ENTITY_ID) == eid
      let updA = beh_tree__debugSymU.y
      let symA = to_char(sym1.z)
      if isLeader
        add_debug_text_mark(pos, "={team}: {symA}{sym2.x} ~{updA}=", -1, 1.0, E3DCOLOR(0x000000))
      else
        add_debug_text_mark(pos, "{team}: {symA}{sym2.x} ~{updA}", -1, 1.0, E3DCOLOR(0x000000))
      if human_net_phys != null
        let shootDir = human_net_phys.phys.appliedCT.wishShootDir
        let p1 = transform[3] + float3(0.0, 1.5, 0.0) + transform[0] * 0.3
        let p2 = p1 + shootDir * 0.5
        draw_debug_line_buffered(p1, p2, E3DCOLOR(0xFFFF0000), 1)
        draw_debug_sphere_buffered(p2, 0.05, E3DCOLOR(0xFF00FFFF), 8, 1)


[console_cmd(name="ai.beh_tree_enabled")]
def debug_beh_tree(beh_tree_enabled : bool = true)
  query() <| $ [es(REQUIRE=beh_tree, REQUIRE_NOT=controlledHero)] (var human_net_phys : HumanActor?; var navmesh_phys__wishWalkSpeed : float?;
                                                                   var beh_tree__enabled : bool&)
    beh_tree__enabled = beh_tree_enabled

    if !beh_tree_enabled
      if human_net_phys != null
        human_control_state_set_walk_speed(human_net_phys.phys.producedCT, 0.f)
        human_control_state_set_neutral_ctrl(human_net_phys.phys.producedCT)
      if navmesh_phys__wishWalkSpeed != null
        *navmesh_phys__wishWalkSpeed = 0.f


[console_cmd(name="ai.debug_bots", hint="ai.debug_bots (debug_beh_tree, log_ai = false, debug_dangers = false)")]
def debug_behaviour_tree(debug_beh_tree : int; log_ai : bool = false; debug_dangers : bool = false)
  let hasGlobal = find_query() <| $ [es] (var global_beh_tree__debug : int&;
                                          var global_entity_danger__debug, global_beh_tree__showDebugLog : bool&)
    global_beh_tree__debug = debug_beh_tree
    global_beh_tree__showDebugLog = log_ai
    global_entity_danger__debug = debug_dangers
    return true

  if !hasGlobal && (debug_beh_tree > 0 || log_ai || debug_dangers)
    createEntity("global_debug_beh_tree") <| $(init)
      init |> set("global_beh_tree__debug", debug_beh_tree)
      init |> set("global_beh_tree__showDebugLog", log_ai)
      init |> set("global_entity_danger__debug", debug_dangers)


[es(tag=(server, dev), no_order)]
def debug_behaviour_tree_update(evt : UpdateStageInfoAct; eid : EntityId;
                                global_beh_tree__debug : int;
                                global_entity_danger__debug, global_beh_tree__showDebugLog : bool)
  if global_beh_tree__debug <= 0 && !global_entity_danger__debug && !global_beh_tree__showDebugLog
    destroyEntity(eid)
  query() <| $ [es] (eid : EntityId; beh_tree__enabled : bool;
                     var beh_tree__debug : bool?;
                     var beh_tree__debugMode : int?;
                     var entity_danger__debug, beh_tree__showDebugLog : bool?)
    if !beh_tree__enabled
      return
    if beh_tree__debug != null && entity_danger__debug != null && beh_tree__showDebugLog != null
      *beh_tree__debug = global_beh_tree__debug != 0
      if beh_tree__debugMode != null
        *beh_tree__debugMode = global_beh_tree__debug
      *entity_danger__debug = global_entity_danger__debug
      *beh_tree__showDebugLog = global_beh_tree__showDebugLog
    elif global_beh_tree__debug > 0 || global_entity_danger__debug || global_beh_tree__showDebugLog
      addSubTemplate(eid, "debug_bot_temp_template") <| $(var init)
        set(init, "beh_tree__debug", global_beh_tree__debug != 0)
        set(init, "beh_tree__debugMode", global_beh_tree__debug)
        set(init, "entity_danger__debug", global_entity_danger__debug)
        set(init, "beh_tree__showDebugLog", global_beh_tree__showDebugLog)


[console_cmd(name="ai.debug_obstacles")]
def debug_obstacles(draw_obstacles : bool = true)
  let tmpl = "debug_obstacles"
  query() <| $ [es(REQUIRE=walker_agent)] (eid : EntityId; beh_tree__enabled : bool)
    if beh_tree__enabled
      addSubTemplate(eid, tmpl) <| $(var init)
        set(init, "beh_tree__drawObstacles", draw_obstacles)
  query() <| $ [es(REQUIRE=agent_obstacles)] (eid : EntityId; beh_tree__enabled : bool)
    if beh_tree__enabled
      addSubTemplate(eid, tmpl) <| $(var init)
        set(init, "beh_tree__drawObstacles", draw_obstacles)

def draw_agent_obstacle(obstacle)
  let offset = float3(0., 0.2, 0.)
  let live = 200
  let convex = length(obstacle.segments) > 2
  if convex
    draw_debug_sphere_buffered(obstacle.center, 1.0, E3DCOLOR(0xFFFF0000), 12, live)
  for seg in obstacle.segments
    let start = seg.start + offset
    let end = seg.end + offset
    if length_sq(seg.dir) > 1e-5
      let dir = normalize(end - start)
      let swap = convex && dot(seg.dir, dir) < 0f
      let st = swap ? end - dir * 0.2 : start + dir * 0.2
      let en = swap ? start + dir * 0.2 : end - dir * 0.2
      draw_debug_sphere_buffered(st, 0.1, E3DCOLOR(0xFFFF0000), 12, live)
      draw_debug_sphere_buffered(en, 0.1, E3DCOLOR(0xFF00FF00), 12, live)
    draw_debug_line_buffered(start, end, E3DCOLOR(0xFFFF0000), live)


[es(tag=dev, tag=render, no_order)]
def debug_obstacles_render_agent(evt : UpdateStageInfoRenderDebug; walker_agent : EntityAgent; beh_tree__drawObstacles : bool)
  if !beh_tree__drawObstacles
    return
  for obstacle in walker_agent.obstacles
    draw_agent_obstacle(obstacle)

[es(tag=dev, tag=render, no_order)]
def debug_obstacles_render_navphys(evt : UpdateStageInfoRenderDebug; agent_obstacles : AgentObstacles; beh_tree__drawObstacles : bool)
  if !beh_tree__drawObstacles
    return
  for obstacle in agent_obstacles.obstacles
    draw_agent_obstacle(obstacle)





















[es(tag=(render, dev), no_order)]
def entity_dangers_debug(evt : UpdateStageInfoRenderDebug; eid : EntityId; agent_dangers__standShootPos : float3; agent_dangers : AgentDangers; transform : float3x4; entity_danger__debug : bool)
  if !entity_danger__debug || length(agent_dangers.dangers) == 0
    return
  draw_cached_debug_sphere(agent_dangers__standShootPos, 0.1, E3DCOLOR(0xFF0000FF), 12)
  let index = uint(eid)
  let idx1 = index & 7u
  let idx2 = (index >> 3u) & 3u
  let idx3 = (index >> 5u) & 3u
  let offset = float3(0f, float(idx1 + 1u) * 0.2, 0f)
  let color = E3DCOLOR(uint4(idx1 << 5u, idx2 << 6u, idx3 << 6u, 255u))
  let agentPos = transform[3] + offset
  draw_debug_sphere_buffered(agentPos, 0.2, color, 6, 20)
  let atTime = get_sync_time()
  for danger in agent_dangers.dangers
    if !danger.traceable
      continue
    let tm = get_TMatrix(danger.eid, "transform")
    if tm == null
      continue
    let pos = (*tm)[3] + offset
    var dir = agentPos - pos
    let lenSq = length_sq(dir)
    let str = "{danger.traceable?"* ":""}{danger.dangerMeter} noise {danger.noiseMeter} " + (danger.lastTime > 0f ? "{danger.lastTime}" : "{atTime - danger.lastTraceTime}")
    if lenSq > 4f
      let len = sqrt(lenSq)
      dir = dir * safeinv(len)
      let from = agentPos - dir * (len - 1.f)
      let to = pos + dir * (len - 0.7f)
      add_debug_text_mark(from, str, -1, 0f, color)
      add_debug_text_mark(to, str, -1, 0f, color)
    else
      let markPos = (pos + agentPos) * 0.5
      add_debug_text_mark(markPos, str, -1, 0f, color)

    if danger.lastTraceTime > 0f && atTime - danger.lastTraceTime < 0.2f
      draw_cached_debug_line(agentPos, pos, E3DCOLOR(0xFFFF0000))
    else
      draw_cached_debug_line(agentPos, pos, color)


[es(tag=dev, before=walker_agent_es)]
def beh_tree_update_reaction(act : UpdateStageInfoAct; eid : EntityId;
                             beh_tree__showDebugLog : bool; beh_tree : BehaviourTree;
                             var beh_tree__debugLog : Array&; beh_tree__debugLogSize : int = 5)
  if !beh_tree__showDebugLog || beh_tree__debugLogSize <= 0
    return
  if beh_tree.changeNodeReason != null
    let name = (*beh_tree.changeNodeReason) |> beh_node_hierarchy_name(true)
    beh_tree__debugLog |> push("{act.curTime} {eid} {name}")
  if beh_tree.resetReason != null
    let name = (*beh_tree.resetReason) |> beh_node_hierarchy_name(true)
    beh_tree__debugLog |> push("{act.curTime} {eid} {name}")
  while length(beh_tree__debugLog) > beh_tree__debugLogSize
    beh_tree__debugLog |> erase(0)


[es(tag=(dev, render), after=beh_tree_update_es, REQUIRE_NOT=deadEntity)]
def walker_agent_debug_reaction(act : UpdateStageInfoRenderDebug; transform : float3x4;
                                beh_tree__showDebugLog : bool; beh_tree__debugLog : Array&)
  if !beh_tree__showDebugLog
    return
  let pos = transform[3]
  var lineOffset = float(length(beh_tree__debugLog))
  let color = E3DCOLOR(uint4(40, 40, 40, 160))
  for it in beh_tree__debugLog
    add_debug_text_mark(pos, get_string(it, ""), -1, lineOffset, color)
    lineOffset -= 1f




























[console_cmd(name="ai.reload_beh_tree")]
def reload_beh_tree(id : uint = 0u)
  sceneload_reload_ai()
  if id != 0u
    DngBehTree::load_beh_tree_from_ecs(EntityId(id))
    return
  query() <| $ [es(REQUIRE=beh_tree)] (eid : EntityId)
    DngBehTree::load_beh_tree_from_ecs(eid)



[es(on_appear, REQUIRE=behTreeDebugWrapped, after=load_beh_tree_es)]
def insert_wrapper_nodes_es(evt : Event; var beh_tree : BehaviourTree)
  beh_tree |> beh_tree_transformNodes() <| $(node)
    let wrap = node.getType != BN_DEBUG_WRAPPER && !(node.parent != null && node.parent.getType == BN_DEBUG_WRAPPER)
    if wrap
      return newDebugWrapperNode(node, beh_tree)
    return node


let debug_squads_ai_colors_table = fixed_array<E3DCOLOR>(
  E3DCOLOR(0xFF000000),
  E3DCOLOR(0xfF0000AA),
  E3DCOLOR(0xFF00AA00),
  E3DCOLOR(0xFF00AAAA),
  E3DCOLOR(0xFFAA0000),
  E3DCOLOR(0xFFAA00AA),
  E3DCOLOR(0xFFAA5500),
  E3DCOLOR(0xFFAAAAAA),
  E3DCOLOR(0xFF555555),
  E3DCOLOR(0xFF0000FF),
  E3DCOLOR(0xFF00FF00),
  E3DCOLOR(0xFF00FFFF),
  E3DCOLOR(0xFFFF0000),
  E3DCOLOR(0xFFFF00FF),
  E3DCOLOR(0xFFFFFF00),
  E3DCOLOR(0xFFFFFFFF)
)

def private get_color_by_index(color_idx : int)
  if color_idx < 0 || color_idx >= 15
    return E3DCOLOR(0xFFFFFFFF)
  return debug_squads_ai_colors_table[color_idx]

[es(tag=(dev, server, render), no_order)]
def debug_render_squads_ai_debug_primitives(evt : UpdateStageInfoRenderDebug;
                                            squadAIDebug__drawTypes : IntList;
                                            squadAIDebug__drawPoint1 : Point3List;
                                            squadAIDebug__drawPoint2 : Point3List;
                                            squadAIDebug__drawTexts : StringList;
                                            squadAIDebug__drawColorIdx : IntList;
                                            squadAIDebug__drawEndTimes : FloatList)
  if empty(squadAIDebug__drawTypes)
    return

  let curTime = get_sync_time()
  for i, elem_type, elem_end_time in iter_range(squadAIDebug__drawTypes), squadAIDebug__drawTypes, squadAIDebug__drawEndTimes
    if curTime < elem_end_time
      if elem_type == 0 
        let color = get_color_by_index(squadAIDebug__drawColorIdx[i])
        draw_debug_line_buffered(squadAIDebug__drawPoint1[i], squadAIDebug__drawPoint2[i], color, 1)
      elif elem_type == 1 
        let sphereData = squadAIDebug__drawPoint2[i]
        let radius = sphereData.x
        let fromTime = sphereData.y
        let midTime = (fromTime + elem_end_time) * 0.5
        let popTime = 0.25
        let onTime = max(0.00001, min(fromTime + popTime, midTime))
        let offTime = max(0.00001, max(elem_end_time - popTime, midTime))
        let popRatio = (curTime < onTime) ? ((curTime - fromTime) / (onTime - fromTime)) : (curTime > offTime) ? ((elem_end_time - curTime) / (elem_end_time - offTime)) : 1.0
        let color = get_color_by_index(squadAIDebug__drawColorIdx[i])
        draw_debug_sphere_buffered(squadAIDebug__drawPoint1[i], radius * popRatio, color, 12, 1)
        let drawOfs = float3(0.1, 0.1, 0.1)
        draw_debug_sphere_buffered(squadAIDebug__drawPoint1[i] + drawOfs, radius * popRatio, color, 12, 1)
      elif elem_type == 2 
        add_debug_text_mark(squadAIDebug__drawPoint1[i], string(squadAIDebug__drawTexts[i]), -1, 0f, E3DCOLOR(0x00000000))
