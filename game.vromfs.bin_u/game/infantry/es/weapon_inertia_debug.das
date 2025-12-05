options no_aot
require ecs
require ecs.ecs_template
require DagorDebug3D
require DagorConsole
require AnimV20
require GeomNodeTree
require %game.events


[ecs_template]
struct gun_inertia_debug
  gunInertiaDebug : Tag
  gun_debug_node : string
  gun_debug_positions : Point3List
  gun_debug_positions_index : int


[console_cmd(name="gun.debug_inertia", hint="Draw the line of weapon's tip inertia. If 'gunFx_main' doesn't work, consider 'bullet'")]
def gun_inertia_debug_cmd(node : string = "gunFx_main")
  let exists = find_query() <| $ [es(REQUIRE=gunInertiaDebug)] (eid : EntityId; var gun_debug_node : das_string&)
    if gun_debug_node == node
      destroyEntity(eid)
      console_print("gun.debug_inertia = false")
    else
      gun_debug_node := node
      console_print("gun.debug_inertia node name changed to {node}")
    return true
  if !exists
    createEntity("gun_inertia_debug") <| $(init)
      set(init, "gun_debug_node", node)
    console_print("gun.debug_inertia = true")


[es(no_order, REQUIRE=gunInertiaDebug)]
def gun_inertia_debug_draw(evt : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           gun_debug_node : string;
                           var gun_debug_positions : Point3List&;
                           var gun_debug_positions_index : int&)
  assume N = 100
  query() <| $ [es(REQUIRE=hero)] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent)
      var n = gun_debug_positions |> length()
      if n < N
        gun_debug_positions |> resize(N)
        n = gun_debug_positions |> length()

      let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, gun_debug_node)
      if nodeId < 0
        error("node {gun_debug_node} not found")
        destroyEntity(eid)
        return

      let p = geomtree_getNodeWpos(*animchar.nodeTree, nodeId)
      gun_debug_positions[gun_debug_positions_index] = p
      gun_debug_positions_index = (gun_debug_positions_index + 1) % n

      for i in 0..n - 1
        var a = gun_debug_positions[(gun_debug_positions_index + i) % n]
        var b = gun_debug_positions[(gun_debug_positions_index + i + 1) % n]
        a.y += float(n - i) * 0.005
        b.y += float(n - i - 1) * 0.005
        draw_debug_line_buffered(a, b, E3DCOLOR(0xffff0000), 1)
