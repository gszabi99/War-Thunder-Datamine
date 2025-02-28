options no_aot
require ecs
require vehicle

[es(no_order, REQUIRE=daeditor__selected)]
def animchar_update_vehicle_wake_up_es(info : UpdateStageInfoAct;
                                       var vehicle_net_phys : VehiclePhysActor)
  vehicle_net_phys.phys |> wakeUp()
