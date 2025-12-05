require ecs
require PhysVars
require %game.events

[es(on_appear, tag=render, before=anim_phys_init_es)]
def human_anim_fpv_init(evt : Event; var human_anim__isFpvVarId : int&; var phys_vars : PhysVars)
  human_anim__isFpvVarId = registerVar(phys_vars, "is_fpv", 0.0)

[es(tag=render, track=human_anim__isFpv, after=human_anim_fpv_init)]
def human_anim_fpv_track(evt : Event; human_anim__isFpv : bool; human_anim__isFpvVarId : int; var phys_vars : PhysVars)
  phys_vars |> setVar(human_anim__isFpvVarId, human_anim__isFpv ? 1.0 : 0.0)

[es(tag=render, on_disappear, REQUIRE=cockpitEntity)]
def human_anim_fpv_disable(evt : Event; var human_anim__isFpv : bool&)
  human_anim__isFpv = false

[es(before=human_anim_es, tag=render)]
def human_anim_fpv(info : ParallelUpdateFrameDelayed; isHeroCockpitCam : bool; camera__active : bool; camera__target : EntityId)
  if camera__active
    query() <| $ [es(REQUIRE=cockpitEntity)] (var human_anim__isFpv : bool&)
      human_anim__isFpv = isHeroCockpitCam
    query() <| $ [es] (eid : EntityId; var human_anim__isFpv : bool&)
      human_anim__isFpv = eid == camera__target ? isHeroCockpitCam : false

