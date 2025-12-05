require ecs
require DngHuman
require vehicle
require FlightModelWrap
require Unit


[es(on_event=(EventUnitRespawn, EventUnitSpawned))]
def human_init_tm(evt : Event;
                  human_net_phys : HumanActor;
                  var transform : float3x4)
  location_toTM(human_net_phys.phys.visualLocation, transform)

[es(before=animchar_es)]
def human_save_tm(info : UpdateStageInfoAct;
                  human_net_phys : HumanActor;
                  human_net_phys__locationOffset : float3 const?;
                  var transform : float3x4)
  location_toTM(human_net_phys.phys.visualLocation, transform)
  if human_net_phys__locationOffset != null
    transform[3] += *human_net_phys__locationOffset

[es(before=animchar_es)]
def vehicle_save_tm(info : UpdateStageInfoAct;
                    vehicle_net_phys : VehiclePhysActor;
                    var transform : float3x4)
  location_toTM(vehicle_net_phys.phys.visualLocation, transform)

[es(before=animchar_es)]
def plane_save_tm(info : UpdateStageInfoAct;
                  plane_net_phys : PlaneActor;
                  var transform : float3x4)
  location_toTM(plane_net_phys.phys.visualLocation, transform)

