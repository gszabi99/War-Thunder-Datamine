require ecs
require %appGame.infantry.es.team_common
require math.base
require math.ang


[es(tag=server, on_event=EventLevelLoaded)]
def item_spawner(evt : Event;
                 transform : float3x4;
                 spawnItemList : Array;
                 spawnItemStep : float3;
                 spawn_item__rotationDeg : float3;
                 team : int = TEAM_UNASSIGNED)
  var tm = transform
  for itemC in spawnItemList
    let item = get_ecs_object(itemC)
    let count = item |> get_int("count") ?? 1
    let templ = item |> get_string("templ", "")

    if templ == ""
      return

    let perItemRotation = item |> get_Point3("rot") ?? float3(0.0)
    let rotTm = make_rot_cw_zyx(deg_to_rad(spawn_item__rotationDeg + perItemRotation))

    for _i in 0..count
      createEntity(templ) <| $(init)
        let itemTm = tm * rotTm
        init |> set("team", team)
        init |> set("transform", itemTm)
      tm[3] += spawnItemStep
