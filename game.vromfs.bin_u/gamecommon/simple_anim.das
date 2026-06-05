require ecs
require DagorMath
require DagorDriver3D
require RendInst
require WTCamera
require app



def simple_anim_update_base(eid : EntityId; cur_time : float)
  query(eid) <| $ [es] (var simple_anim__baseTransform : float3x4&;
                        var simple_anim__baseTime : float&;
                        transform : float3x4)
    simple_anim__baseTransform = transform
    simple_anim__baseTime = cur_time


[es(on_appear)]
def simple_spin_init_base_es(evt : ecs::Event;
                             transform : float3x4;
                             var simple_anim__baseTransform : float3x4&;
                             var simple_anim__baseTime : float&)
  simple_anim__baseTransform = transform
  simple_anim__baseTime = get_sync_time()



[es(no_order, REQUIRE_NOT=simple_anim__disableOnServer)]
def simple_spin_animation_es(act : UpdateStageInfoAct;
                             var transform : float3x4&;
                             simple_anim__enabled : bool;
                             simple_anim__baseTransform : float3x4;
                             simple_anim__baseTime : float;
                             simple_anim_spin__rotationAxis : float3;
                             simple_anim_spin__speed : float;
                             simple_anim_spin__sector : float2)
  if !simple_anim__enabled
    return
  var curRot = simple_anim_spin__speed * (act.curTime - simple_anim__baseTime)
  if simple_anim_spin__sector.x < simple_anim_spin__sector.y 
    let sector = simple_anim_spin__sector.y - simple_anim_spin__sector.x
    curRot += (simple_anim_spin__sector.x + simple_anim_spin__sector.y) * 0.5f
    curRot = curRot % (2.f * sector)
    if curRot < 0.f
      curRot += 2.f * sector
    if curRot > sector
      curRot = 2.f * sector - curRot
    curRot += simple_anim_spin__sector.x
  var rotTM : float3x4
  make_tm(quat(simple_anim_spin__rotationAxis, curRot), rotTM)
  transform = simple_anim__baseTransform * rotTM



[es(no_order, tag=render)]
def simple_anim_cull_es(act : UpdateStageInfoAct)
  let frustum = Frustum(get_cull_glob_tm())
  var perspHk = 1.f
  get_Driver3dPerspective() <| $(pers : Driver3dPerspective#)
    perspHk = pers.hk
  query() <| $[es] (transform : float3x4;
                    var simple_anim__enabled : bool&;
                    simple_anim_cull__cullingDistRangeSq : float2;
                    simple_anim_cull__cullObjectRadius : float;
                    simple_anim_cull__relScreenSizeThreshold : float)
    let distSqToCam = distance_sq(get_camera_pos(), transform[3])
    var enabled = distSqToCam < simple_anim_cull__cullingDistRangeSq.y
    if enabled && distSqToCam > simple_anim_cull__cullingDistRangeSq.x
      enabled = frustum_test_sphere(frustum, transform[3], simple_anim_cull__cullObjectRadius)
      if enabled
        
        let radiusXperspHk = perspHk * simple_anim_cull__cullObjectRadius * 2.f
        enabled = radiusXperspHk * radiusXperspHk > distSqToCam * (simple_anim_cull__relScreenSizeThreshold * simple_anim_cull__relScreenSizeThreshold)

    
    
    
    simple_anim__enabled = enabled


[es(on_appear, after=riextra_spawn_ri_es, tag=render)]
def simple_anim_init_rendinst_bsphere_es(evt : ecs::Event;
                                         ri_extra : RiExtraComponent;
                                         var simple_anim_cull__cullObjectRadius : float&)
  if !ri_extra.valid
    return
  let sph = getRIGenBSphere(RendInstDesc(ri_extra.handle))
  if sph.w > 0.
    simple_anim_cull__cullObjectRadius = length(sph.xyz) + sph.w
