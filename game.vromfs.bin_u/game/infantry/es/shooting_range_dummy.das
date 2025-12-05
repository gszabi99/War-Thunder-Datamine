require ecs
require %appGame.wt_events
require DagorSystem
require GeomNodeTree
require AnimV20
require PhysVars
require app
require %game.dm.dm_events
require %game.events

[es(on_appear, REQUIRE=shootingRangeDummy)]
def shooting_range_dummy_anim_init_es(evt : Event;
                                      shooting_range_dummy__animVarName : string;
                                      var shooting_range_dummy__animVarId : int&;
                                      var phys_vars : PhysVars&)
  shooting_range_dummy__animVarId = registerVar(phys_vars, shooting_range_dummy__animVarName, 0.f)

[es(on_appear, REQUIRE=shootingRangeDummy, after=dm_parts_es)]
def shooting_range_dummy_dot_mults_init_es(evt : Event;
                                           var dm_parts__dotMult : FloatList&)
  for dotMult in dm_parts__dotMult
    dotMult = 0.0

[es(track=shooting_range_dummy__stateDown)]
def shooting_range_dummy_on_track_es(evt : Event;
                                     shooting_range_dummy__animVarId : int;
                                     shooting_range_dummy__stateDown : bool;
                                     var phys_vars : PhysVars&)
  setVar(phys_vars, shooting_range_dummy__animVarId, shooting_range_dummy__stateDown ? -1.0 : 1.0)


[es(track=isAlive)]
def shooting_range_dummy_on_dead_es(evt : Event;
                                    isAlive : bool;
                                    shooting_range_dummy__cooldown : float;
                                    var shooting_range_dummy__aliveAtTime : float&;
                                    var shooting_range_dummy__stateDown : bool&)
  shooting_range_dummy__stateDown = !isAlive
  if !isAlive
    shooting_range_dummy__aliveAtTime = get_sync_time() + shooting_range_dummy__cooldown

[es]
def shooting_range_dummy_cooldown_es(info : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     var isAlive : bool&;
                                     var shooting_range_dummy__aliveAtTime : float&)
  if shooting_range_dummy__aliveAtTime > 0.f && info.curTime >= shooting_range_dummy__aliveAtTime
    isAlive = true
    sendEventImmediate(eid, CmdRestoreHpPart(hp = 1.))
    sendEventImmediate(eid, CmdRestoreArmor())
    shooting_range_dummy__aliveAtTime = -1.f
