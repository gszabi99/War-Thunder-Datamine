require ecs

[es(tag=gameClient,  track=camera__target, REQUIRE=camera__target)]
def shooter_cam_on_target_change(evt : Event;
                                 camera__prevTarget : EntityId;
                                 shooter_cam__tauOnChange : float;
                                 var shooter_cam__tauInc : float&)
  if shooter_cam__tauOnChange > 0.0f && !!camera__prevTarget
    shooter_cam__tauInc = shooter_cam__tauOnChange