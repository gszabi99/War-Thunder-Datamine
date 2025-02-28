require ecs
require DngHuman
require vehicle

[es(before=animchar_es)]
def human_save_tm(info : UpdateStageInfoAct;
                  human_net_phys : HumanActor;
                  var transform : float3x4)
  location_toTM(human_net_phys.phys.visualLocation, transform)

[es(before=animchar_es)]
def vehicle_save_tm(info : UpdateStageInfoAct;
                    vehicle_net_phys : VehiclePhysActor;
                    var transform : float3x4)
  location_toTM(vehicle_net_phys.phys.visualLocation, transform)