require ecs
require DngHuman
require vehicle
require FlightModelWrap
require Unit

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

[es(before=animchar_es)]
def plane_save_tm(info : UpdateStageInfoAct;
                  plane_net_phys : PlaneActor;
                  var transform : float3x4)
  location_toTM(plane_net_phys.phys.visualLocation, transform)

[es(tag=server, on_appear)]
def init_unit_team(evt : Event;
                   unit__ref : UnitRef;
                   var team : int&)
  team = unit__ref.unit.army
