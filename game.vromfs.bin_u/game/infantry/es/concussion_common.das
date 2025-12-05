module concussion_common shared
require ecs
require app


def enable_concussion_affect(owner_eid : EntityId;
                             duration : float;
                             intensity : float;
                             is_blocks_sprint : bool;
                             look_sens_mult : float;
                             look_inertia : float;
                             move_inertia : float)
  if intensity <= 0.0
    return

  query(owner_eid) <| $ [es] (concussion__allowReapply : bool = true;
                              var concussion__isActive : bool&;
                              var concussion__isBlocksSprint : bool&;
                              var concussion__lookSensMult : float&;
                              var concussion__lookInertia : float&;
                              var concussion__moveInertia : float&;
                              var concussion__endTime : float&;
                              var concussion__intensityMult : float&)
    if !concussion__isActive || concussion__allowReapply
      concussion__endTime = get_sync_time() + duration
    concussion__isActive = true
    concussion__isBlocksSprint = is_blocks_sprint
    concussion__lookSensMult = look_sens_mult
    concussion__lookInertia = look_inertia
    concussion__moveInertia = move_inertia
    concussion__intensityMult = intensity

def has_concussion_affect(owner_eid : EntityId) : bool
  var res = false
  query(owner_eid) <| $ [es] (concussion__isActive : bool)
    res = concussion__isActive
  return res