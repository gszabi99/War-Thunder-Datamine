options no_aot
require ecs
require Ship
require DngShip

[es(no_order, REQUIRE=daeditor__selected)]
def animchar_update_ship_wake_up_es(info : UpdateStageInfoAct;
                                    var ship_net_phys : ShipActor)
  ship_net_phys.phys |> ship_phys_wake_up()
