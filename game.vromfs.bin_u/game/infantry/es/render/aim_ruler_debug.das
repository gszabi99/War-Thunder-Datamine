options no_aot
require ecs
require strings
require CollRes
require DagorConsole
require Dacoll
require DagorDebug3D
require GridCollision
require CollisionTraces
require PhysMat
require DagorShaders


let
  aim_ruler_physmatVarId = get_shader_variable_id("aim_ruler_physmat", true)

enum RulerMode : int
  DISABLE = 0
  RULER = 1
  BOXES = 2
  PHYSMAP = 3

[console_cmd(name="aim.ruler", hint="<mode 0 - disable, 1 - ruler, 2 - ruler+boxes, 3 - ruler+boxes+physmap>")]
def draw_ruler(mode : int)
  let found = find_query() <| $ [es(REQUIRE=aimRulerDebug)] (eid : EntityId; var aim_ruler__drawPhysMap, aim_ruler__drawBoxes : bool&)
    if mode == int(RulerMode.DISABLE)
      destroyEntity(eid)
    else
      aim_ruler__drawBoxes = (mode >= int(RulerMode.BOXES))
      aim_ruler__drawPhysMap = (mode >= int(RulerMode.PHYSMAP))
    return true

  if !found && mode >= int(RulerMode.RULER)
    createEntity("aim_ruler_debug") <| $(init)
      init |> set("aim_ruler__drawBoxes", mode >= int(RulerMode.BOXES))
      init |> set("aim_ruler__drawPhysMap", mode >= int(RulerMode.PHYSMAP))

def private trace_grid(grid_type : uint; pos, dir : float3; var len : float&)
  var retEid = INVALID_ENTITY_ID
  trace_entities_in_grid(grid_type, pos, dir, len, INVALID_ENTITY_ID, SortIntersections.YES) <| $(intersections : array<IntersectedEntity>#)
    if length(intersections) != 0
      retEid = intersections[0].eid
  return retEid


























[es(tag=render, no_order, REQUIRE=aimRulerDebug)]
def draw_ruler_es(evt : UpdateStageInfoRenderDebug;
                  aim_ruler__shouldDraw : bool;
                  aim_ruler__tracePos : float3;
                  aim_ruler__traceDir : float3;
                  aim_ruler__traceLen : float;
                  aim_ruler__targetEid : EntityId;
                  
                  aim_ruler__drawPhysMap : bool)
  if !aim_ruler__shouldDraw
    return
  var len = aim_ruler__traceLen
  var norm : float3
  var color = E3DCOLOR(0xFFFFFFFF)
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  if traceray_normalized(aim_ruler__tracePos, aim_ruler__traceDir, len, matId, norm, ETF_ALL, riDesc, -1)
    color = E3DCOLOR(0xFF00FF00)
  var desc = fmt(":.2f", len) + "m"
  if !aim_ruler__targetEid
    if matId >= 0
      desc += " mat {matId} <{get_material_name(get_material(matId))}>"
  else
    color = E3DCOLOR(0xFF00FF00)
    query(aim_ruler__targetEid) <| $ [es] (possessedByPlr : EntityId const?; transform : float3x4; collres : CollisionResource; material : string = "default")
      var t = 4000f
      if collres_traceray(collres, transform, aim_ruler__tracePos, aim_ruler__traceDir, t, norm, matId)
        desc += " pmat {matId} <{get_material_name(get_material(matId))}>"
      desc += " mat {get_material_id(material)} <{material}>"
      if possessedByPlr != null
        desc += " plr <{get_string(*possessedByPlr, "name", "")}>"
    desc += " {aim_ruler__targetEid} <{getEntityTemplateName(aim_ruler__targetEid)}>"
  let pos = aim_ruler__tracePos + aim_ruler__traceDir * len
  if aim_ruler__drawPhysMap
    DagorShaders::set_int(aim_ruler_physmatVarId, matId)
  begin_draw_cached_debug_lines(false, false, false)

  
  
  draw_debug_line_buffered(aim_ruler__tracePos, pos, color, 5)
  let textMartPos = pos + float3(0.0, 0.5, 0.0)
  add_debug_text_mark(textMartPos, desc, -1, 0., color)

  end_draw_cached_debug_lines()
