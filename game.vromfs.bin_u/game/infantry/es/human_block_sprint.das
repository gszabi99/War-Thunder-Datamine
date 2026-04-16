require ecs
require DngHuman
require HumanPhys
require %game.events


[es]
def human_block_sprint_es(evt : CmdPostPhysUpdate;
                          var human_net_phys : HumanActor;
                          human_weap__throwMode : bool;
                          human_phys__jumpEndTime : float;
                          burning__isPuttingOut : bool;
                          human_phys__afterJumpDelay : float)
  let physTime = float(evt.tick) * evt.dt
  assume currentState = human_net_phys.phys.currentState
  let isBlockedByJump = physTime < human_phys__jumpEndTime + human_phys__afterJumpDelay
  let blocked = human_weap__throwMode || burning__isPuttingOut || isBlockedByJump
  human_phys_state_set_block_sprint(currentState, blocked)
