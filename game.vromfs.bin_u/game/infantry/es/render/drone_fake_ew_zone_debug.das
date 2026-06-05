options no_aot
require ecs
require ecs.ecs_template
require math.base
require DagorMath
require DagorDebug3D
require DagorConsole


[ecs_template]
struct fake_ew_zone_debug_draw
  fakeEwZoneDebugDraw : Tag


[console_cmd(name="fake_ew_zone.debug", hint="Toggle debug draw of all fake EW zones (sphere + team label)")]
def fake_ew_zone_debug_toggle()
  let found = find_query() <| $ [es(REQUIRE=fakeEwZoneDebugDraw)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !found
    createEntity("fake_ew_zone_debug_draw")
  console_print("fake_ew_zone debug {found ? "deactivated" : "activated"}")


[es(tag=gameClient, no_order, REQUIRE=fakeEwZoneDebugDraw)]
def fake_ew_zone_debug_draw_es(evt : UpdateStageInfoRenderDebug)
  query() <| $ [es(REQUIRE=fakeEwZone)] (eid : EntityId;
                                         transform : float3x4;
                                         fake_ew_zone__areaSq : float2;
                                         team : int)
    let innerRadius = sqrt(fake_ew_zone__areaSq.x)
    let outerRadius = sqrt(fake_ew_zone__areaSq.y)
    let outerColor = team == 1 ? E3DCOLOR(0xFF3060FF) : (team == 2 ? E3DCOLOR(0xFFFF6030) : E3DCOLOR(0xFFFFFF00))
    let innerColor = team == 1 ? E3DCOLOR(0xFF80A0FF) : (team == 2 ? E3DCOLOR(0xFFFFA080) : E3DCOLOR(0xFFFFFFA0))
    draw_cached_debug_sphere(transform[3], outerRadius, outerColor, 128)
    draw_cached_debug_sphere(transform[3], innerRadius, innerColor, 128)
    add_debug_text_mark(transform[3], "{getEntityTemplateName(eid)} team={team} inner={innerRadius} outer={outerRadius}", -1, 1.0, outerColor)
