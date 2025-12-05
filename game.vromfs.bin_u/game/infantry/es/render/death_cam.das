require ecs

require %appGame.wt_events


[es(tag=render, REQUIRE=watchedByPlr)]
def set_death_cam_killer(evt : EventEntityDied; eid : EntityId; var death_cam__killer : EntityId&)
  if evt.victim != eid
    return

  death_cam__killer = evt.offender
  
  
  
  
  
  
  
  
  
  
  
  
  
