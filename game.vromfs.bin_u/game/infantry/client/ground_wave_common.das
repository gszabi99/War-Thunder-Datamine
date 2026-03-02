require ecs
require ecs.safe
require ecs.extra_set
require ecs.common
require ecs.soa_template
require math.base
require strings
require AnimV20
require GeomNodeTree
require DaWeapons
require DagorSystem
require %appGame.infantry.client.physmat_fx_common
require PhysMat
require Dacoll
require RendInst
require DagorMath

module ground_wave_common shared

[soa_template]
struct VegetationInfo
  vegetation_info__posHeight : float4
  vegetation_info__fxName : string
  vegetation_info__rendinstPool : int


def private spawn_ground_wave_fx_aux(forward_dir : float3;
                                     fx_up_dir : float3;
                                     pos : float3;
                                     fx_name : string;
                                     allow_paint_from_biome : bool = false;
                                     desired_biome : string = "";
                                     check_trees_around : bool = false;
                                     leaves_check_radius : float = 1.0)
  if empty(fx_name) || fx_name == "-"
    return

  let fxTemplate = getTemplateByName(fx_name)
  if fxTemplate == null
    return

  
  
  
  

  if check_trees_around && count_tree_inside_radius(pos, leaves_check_radius) <= 0
    return

  var tm : float3x4
  tm[1] = normalize(fx_up_dir)
  tm[2] = normalize(cross(forward_dir, tm[1]))
  tm[0] = normalize(cross(tm[1], tm[2]))
  tm[3] = pos

  if allow_paint_from_biome && (getTemplateComponent(*fxTemplate, "paint_from_biome") ?? false)
    createEntity("biome_fx_readback_info ") <| $(init)
      init |> set("transform", tm)
      init |> set("fx_name_to_spawn", fx_name)
      if !empty(desired_biome)
        init |> set("biome_query__desiredBiomeName", desired_biome)
  else
    createEntity(fx_name) <| $(init)
      init |> set("transform", tm)


def private count_tree_inside_radius(pos : float3; radius : float) : int
  let box = BBox3(pos - float3(radius), pos + float3(radius))
  var count = 0

  rendinst_foreachTreeInBox(box) <| $ [unused_argument(coll_info)] (coll_info : CollisionInfo)
    count++
  return count

[export]
def spawn_ground_wave_fx(cur_shell_impulse : float; fx_up_dir : float3; gun_forward_dir : float3; gun_pos : float3; spawn_leaves : bool)
  find_query() <| $ [es] (gun_ground_wave_fx__effectGroups : Array; gun_ground_wave_fx__maxImpulses : FloatList)
    for elem, maxImpulse in gun_ground_wave_fx__effectGroups, gun_ground_wave_fx__maxImpulses
      if cur_shell_impulse > maxImpulse
        continue

      let effectGroup = elem as Object
      if effectGroup == null
        continue

      let defaultFx = effectGroup?.defaultFx ?? ""
      if empty(defaultFx)
        return true

      let maxDistanceFromGun = effectGroup?.maxDistanceFromGun ?? 1.0
      let leavesCheckRadius = effectGroup?.leavesCheckRadius ?? 10.0
      var dist = maxDistanceFromGun
      var pmid = -1
      var norm = float3()
      let traceDir = float3(0, -1, 0)

      using() <| $(var riDesc : RendInstDesc#)
        traceray_normalized(gun_pos, traceDir, dist, pmid, norm, ETF_DEFAULT, riDesc, -1)
        if dist == maxDistanceFromGun
          return

        if fx_up_dir != float3()
          norm = fx_up_dir

        let fxs = get_ecs_StringList(effectGroup?.fxs)
        var fx : string
        if fxs == null || pmid < 0
          fx = defaultFx
        else
          fx = string((*fxs)[pmid])
          if empty(fx)
            fx = defaultFx

        var pos = gun_pos
        pos.y -= dist

        
        let riexHandle = riDesc.riExtraHandle
        let isPaintFxOnHit = false 
        spawn_ground_wave_fx_aux(gun_forward_dir, norm, pos, fx, isPaintFxOnHit)

        
        
        let leavesFx = effectGroup?.leavesFx ?? ""
        let leavesAlwaysSpawn = effectGroup?.leavesAlwaysSpawn ?? true
        
        
        if (spawn_leaves || leavesAlwaysSpawn) && !empty(leavesFx) && riexHandle == RIEX_HANDLE_NULL
          let isPaintFxOnHitLeaves = false
          spawn_ground_wave_fx_aux(gun_forward_dir, norm, pos, leavesFx, isPaintFxOnHitLeaves, "", true, leavesCheckRadius)

      return true
    return true
