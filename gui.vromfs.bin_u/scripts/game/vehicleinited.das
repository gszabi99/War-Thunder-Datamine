require DagorSystem
require ecs
module events;

//sample system on CmdInitComponent event

[es (on_event=CmdInitComponent)]
def vehicle_created_es(evt:Event; unit_crew_dot_inited : bool)
  if unit_crew_dot_inited == true
    logerr("Vehicle es inited")
