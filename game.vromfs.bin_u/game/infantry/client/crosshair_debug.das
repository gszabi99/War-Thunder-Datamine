options no_aot

require ecs
require ecs.ecs_template
require DagorConsole
require Unit
require HeroManager
require %appGame.infantry.es.human_weap_common
require app
require DagorMath
require DagorStdGuiRender
require DagorDriver3D
require %appGame.infantry.es.render.screen_projection_common


[cpp_event(broadcast)]
struct RenderEventUI
  viewTm : float3x4
  viewItm : float3x4
  persp : Driver3dPerspective

[ecs_template]
struct crosshair_debug_draw
  crosshairDebug : Tag
  crosshair__lineLength : float = 50f
  crosshair__lineThickness : float = 3f
  crosshair__lineIdent : float2 = float2(30, 0)
  crosshair__lineColor : E3DCOLOR =  E3DCOLOR(0xFFF9F9F9)


[console_cmd(name="hud.force_crosshair")]
def force_crosshair_debug_cmd()
  let exists = find_query() <| $ [es(REQUIRE=crosshairDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exists
    createEntity("crosshair_debug_draw")

[ecs_template]
struct screen_cross_debug_draw
  screenCrossDebug : Tag
  screenCross__fullScreen : bool = false
  screenCross__lineLength : float = 50f
  screenCross__lineThickness : float = 3f
  screenCross__lineColor : E3DCOLOR = E3DCOLOR(0xFFF9F9F9)


[console_cmd(name="hud.screen_cross")]
def screen_cross_debug_cmd(full_screen : bool = false)
  var sameMode = false
  find_query() <| $ [es(REQUIRE=screenCrossDebug)] (eid : EntityId; screenCross__fullScreen : bool)
    sameMode = screenCross__fullScreen == full_screen
    destroyEntity(eid)
    return true
  if !sameMode
    createEntity("screen_cross_debug_draw") <| $(var init : ComponentsInitializer)
      set(init, "screenCross__fullScreen", full_screen)

[es(tag=dev, REQUIRE=screenCrossDebug)]
def ui_screen_cross_debug_draw_es(evt : RenderEventUI;
                                  screenCross__fullScreen : bool;
                                  screenCross__lineLength : float;
                                  screenCross__lineThickness : float;
                                  screenCross__lineColor : E3DCOLOR)
  let screenSize = StdGuiRender_screen_size()
  let center = screenSize / 2.0
  let noIdent = float2(0f, 0f)

  if screenCross__fullScreen
    StdGuiRender_render_line_aa(float2(0f, center.y), float2(screenSize.x, center.y), false, screenCross__lineThickness, noIdent, screenCross__lineColor)
    StdGuiRender_render_line_aa(float2(center.x, 0f), float2(center.x, screenSize.y), false, screenCross__lineThickness, noIdent, screenCross__lineColor)
    return

  let lineDirRight = float2(1f, 0f)
  let lineDirUp = float2(0f, 1f)
  StdGuiRender_render_line_aa(center - lineDirRight * screenCross__lineLength, center + lineDirRight * screenCross__lineLength, false, screenCross__lineThickness, noIdent, screenCross__lineColor)
  StdGuiRender_render_line_aa(center - lineDirUp * screenCross__lineLength, center + lineDirUp * screenCross__lineLength, false, screenCross__lineThickness, noIdent, screenCross__lineColor)

[es(tag=dev, REQUIRE=crosshairDebug)]
def ui_crosshair_debug_draw_es(evt : RenderEventUI;
                               crosshair__lineLength : float;
                               crosshair__lineThickness : float;
                               crosshair__lineIdent : float2;
                               crosshair__lineColor : E3DCOLOR)
  let hero = get_controlled_hero()
  let hero_eid = hero != null ? hero.eid : INVALID_ENTITY_ID

  var gunTraceLen = 0.0
  query(hero_eid) <| $ [es] (human_weap__tracerayLen : float = 0.0)
    gunTraceLen = human_weap__tracerayLen

  var shootTm : float3x4
  var tracePos : float3
  var traceDir : float3

  let curTime = get_sync_time()

  if human_weap_get_aim_tm(hero_eid, curTime, shootTm)
    traceDir = shootTm[0]
    tracePos = shootTm[3]
    let traceEndPos = tracePos + traceDir * gunTraceLen

    let uiViewTm : float3x4 = evt.viewTm
    let screenHalfSize = StdGuiRender_screen_size() / 2.0
    let screenPos = from_world_coord_to_screen(uiViewTm * traceEndPos, evt.persp.wk, evt.persp.hk, screenHalfSize)
    let lineDirRight =  float2(1f, 0f)
    let lineDirUp =  float2(0f, 1f)

    StdGuiRender_render_line_aa(screenPos + lineDirRight, screenPos + lineDirRight * crosshair__lineLength, false, crosshair__lineThickness, crosshair__lineIdent, crosshair__lineColor)
    StdGuiRender_render_line_aa(screenPos - lineDirRight, screenPos - lineDirRight * crosshair__lineLength, false, crosshair__lineThickness, crosshair__lineIdent, crosshair__lineColor)

    StdGuiRender_render_line_aa(screenPos + lineDirUp, screenPos + lineDirUp * crosshair__lineLength, false, crosshair__lineThickness, crosshair__lineIdent, crosshair__lineColor)
    StdGuiRender_render_line_aa(screenPos - lineDirUp, screenPos - lineDirUp * crosshair__lineLength, false, crosshair__lineThickness, crosshair__lineIdent, crosshair__lineColor)

    let recSize = 6f
    let halfSize = recSize * 0.5f
    StdGuiRender_set_color(crosshair__lineColor)
    StdGuiRender_render_rect(screenPos.x - halfSize, screenPos.y - halfSize, screenPos.x + halfSize, screenPos.y + halfSize)
