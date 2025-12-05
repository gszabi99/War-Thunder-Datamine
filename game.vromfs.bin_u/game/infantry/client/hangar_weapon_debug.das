options no_aot
require ecs
require DagorConsole
require DagorDebug3D
require DagorMath
require CollRes
require math.base

require %appGame.wt_events

[console_cmd(name="hangar.debug_weapon", hint="Enables human weapon debug draw")]
def debug_weapon_enable(enable : bool)
  query() <| $ [es] (var hangar_weapon__debug_draw : bool&)
    hangar_weapon__debug_draw = enable
  query() <| $ [es(REQUIRE=camera_view)] (var camera__dof_enabled : bool&)
    camera__dof_enabled = !enable

[es(REQUIRE=hangar_weapon_placer, no_order)]
def hangar_weapon_debug_es(act : UpdateStageInfoAct;
                           hangar_weapon__debug_draw : bool&;
                           hangar_weapon__focusPos : float3&;
                           transform : float3x4& const;
                           original_transform : float3x4& const;
                           hangar_weapon__pivotOffset : float3 const = float3(0., 0., 0.);
                           collres : CollisionResource const)
  if !hangar_weapon__debug_draw
    return

  draw_debug_sphere_buffered(original_transform[3], 0.05f, E3DCOLOR(0xFFFFFFFF), 32, 1);
  draw_debug_sphere_buffered(hangar_weapon__focusPos, 0.05f, E3DCOLOR(0xFFFFFFFF), 32, 1);

  let tm = transform
  var bbox = collres.boundingBox
  bbox.boxMin.x = -collres.boundingBox.boxMin.z;
  bbox.boxMax.x = -collres.boundingBox.boxMax.z;
  bbox.boxMin.z = collres.boundingBox.boxMin.x;
  bbox.boxMax.z = collres.boundingBox.boxMax.x;
  let bboxCenterWorld = tm * bbox.center

  var rotation = transform
  rotation[3] = float3(0., 0., 0.)
  let offset = float3(hangar_weapon__pivotOffset.x, hangar_weapon__pivotOffset.z, 0.0)
  let pivotWorld = bboxCenterWorld + rotation * offset
  draw_debug_box_buffered(bbox, tm, E3DCOLOR(0xFFFFFFFF), 1)
  draw_debug_sphere_buffered(bboxCenterWorld, 0.05f, E3DCOLOR(0xFFFF0000), 32, 1)
  draw_debug_sphere_buffered(pivotWorld, 0.05f, E3DCOLOR(0xFFFF00FF), 32, 1)
  draw_debug_sphere_buffered(tm[3], 0.05f, E3DCOLOR(0xFF00FF00), 32, 1)
