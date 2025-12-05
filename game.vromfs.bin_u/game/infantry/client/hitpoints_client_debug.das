options no_aot
require ecs
require ecs.ecs_template
require math.base
require strings
require DagorConsole
require DagorDebug3D
require ecs
require ecs.common


[ecs_template]
struct hitpoints_debug_draw
  hitpoints__debugDrawDist : float = 0.0
  hitpoints__debugDrawDistSq : float = 0.0


[console_cmd(name="hitpoints.debug_hp")]
def hitpoints_debug_draw_cmd(dist = 50.0)
  let tmpl = "hitpoints_debug_draw"
  let distSq = square(dist)

  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var hitpoints__debugDrawDist : float&;
                                       var hitpoints__debugDrawDistSq : float&)
    if hitpoints__debugDrawDist == dist
      destroyEntity(eid)
    else
      hitpoints__debugDrawDist = dist
      hitpoints__debugDrawDistSq = distSq
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("hitpoints__debugDrawDist", dist)
      init |> set("hitpoints__debugDrawDistSq", distSq)


[es(tag=(render, dev), no_order)]
def debug_draw_hitpoints_hp_es(evt : UpdateStageInfoAct;
                               hitpoints__debugDrawDistSq : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query() <| $ [es] (transform aka hitpoints_transform : float3x4;
                       hitpoints__hp : float;
                       hitpoints__maxHp : float;
                       dm_parts__armorItemEids : EidList)
      let distSq = distance_sq(camera_transform[3], hitpoints_transform[3])
      if distSq > hitpoints__debugDrawDistSq
        return
      let markPos = hitpoints_transform[3] + float3(0.0, 1.0, 0.0)
      add_debug_text_mark(markPos, "hp:{format("%.2f", hitpoints__hp)}/{format("%.2f", hitpoints__maxHp)}", -1, 0.0, E3DCOLOR(0xFFFFFFFF))
      let offsetDelta = 1.5
      var offset = offsetDelta
      for armorEid in dm_parts__armorItemEids
        var armorSegmentEids = array(armorEid)
        query(armorEid) <| $ [es] (segmented_armor__segmentsEids : EidList)
          clear(armorSegmentEids)
          for armorSegmentEid in segmented_armor__segmentsEids
            push(armorSegmentEids, armorSegmentEid)
        for armorSegmentEid in armorSegmentEids
          query(armorSegmentEid) <| $ [es] (item__armorDurabilityMaxAmount : float;
                                            item__armorDurabilityAmount : float;
                                            item__armorHudDmPart : string)
            let armorTemplate = split_template(getEntityTemplateName(armorSegmentEid))[0]
            add_debug_text_mark(markPos, "{item__armorHudDmPart}: {armorTemplate}: {format("%.2f", item__armorDurabilityAmount)}/{format("%.2f", item__armorDurabilityMaxAmount)}", -1, offset, E3DCOLOR(0xFFFFFFFF))
            offset += offsetDelta
    return true
