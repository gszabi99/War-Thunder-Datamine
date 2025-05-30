require ecs
require %game.unit.unit_events
require %game.events
require Unit
require IGroundModel
require DagorSystem
require net
require DagorDataBlock
require app
require HeroManager
require vehicle

[es(REQUIRE=unit_tag__tank, no_order)]
def tank_engine_stage_updater_es(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 var vehicle_net_phys : VehiclePhysActor&;
                                 var tank_engine__startDelayTimer : float&;
                                 var tank_engine__stopDelayTimer : float&;
                                 tank_engine__isWorking : bool;
                                 var tank_engine__stage : uint8&;
                                 tank_engine__startDelay : float;
                                 tank_engine__stopDelay : float;
                                 var tank_engine__commandSent : bool&)
  let wasEngineState = tank_engine__stage

  if tank_engine__stage == uint8(TankEngineStage.STAGE_STOPPED)
    vehicle_phys_setIsICEWorking(vehicle_net_phys.phys, tank_engine__isWorking)
    if tank_engine__isWorking
      tank_engine__stage = uint8(TankEngineStage.STAGE_STARTING)

  elif tank_engine__stage == uint8(TankEngineStage.STAGE_STARTING)
    tank_engine__startDelayTimer -= act.dt
    if tank_engine__startDelayTimer <= 0.0f
      tank_engine__stage = uint8(TankEngineStage.STAGE_READY)

  elif tank_engine__stage == uint8(TankEngineStage.STAGE_READY)
    tank_engine__startDelayTimer = tank_engine__startDelay
    tank_engine__stage = uint8(TankEngineStage.STAGE_NOMINAL)
    tank_engine__commandSent = false
    vehicle_net_phys.phys.disableEngineOmega = false

  elif tank_engine__stage == uint8(TankEngineStage.STAGE_NOMINAL)
    if !tank_engine__isWorking
      tank_engine__stage = uint8(TankEngineStage.STAGE_STOPPING)

  elif tank_engine__stage == uint8(TankEngineStage.STAGE_STOPPING)
    tank_engine__stopDelayTimer -= act.dt
    if tank_engine__stopDelayTimer < 0.0
      tank_engine__stage = uint8(TankEngineStage.STAGE_TURNING_OFF)

  elif tank_engine__stage == uint8(TankEngineStage.STAGE_TURNING_OFF)
    tank_engine__commandSent = false
    tank_engine__stage = uint8(TankEngineStage.STAGE_STOPPED)
    tank_engine__stopDelayTimer = tank_engine__stopDelay
    vehicle_net_phys.phys.disableEngineOmega = true

  if tank_engine__stage != wasEngineState
    sendEvent(eid, EventTankEngineStageChanged(newStage = tank_engine__stage))

[es]
def tank_engine_state_init_es(evt : CmdInitComponent;
                              var tank_engine__startDelayTimer : float&;
                              var tank_engine__stopDelayTimer : float&;
                              var tank_engine__startDelay : float&;
                              var tank_engine__stopDelay : float&)
  let tankEngineModelBlk = *evt.modelBlk |> datablock_get_block_by_name("tankEngine")
  let commonBlk = get_common_unit_systems_blk()
  let tankEngineCommonBlk = commonBlk != null ? *commonBlk |> datablock_get_block_by_name("tankEngine") : null
  if tankEngineModelBlk == null && tankEngineCommonBlk == null
    return

  assume tankEngineBlk = tankEngineModelBlk != null ? *tankEngineModelBlk : *tankEngineCommonBlk
  tankEngineBlk |> datablock_get_block("engine") <| $(engineBlk)
    let engineDelay = engineBlk |> datablock_getPoint2("engineGMDelay", get_game_params().engineGMDelay)
    tank_engine__startDelay = engineDelay.x
    tank_engine__stopDelay = engineDelay.y
    tank_engine__startDelayTimer = tank_engine__startDelay
    tank_engine__stopDelayTimer = tank_engine__stopDelay

[es, unused_argument(evt)]
def tank_engine_state_toggle_es(evt : EventTryToggleGMEngine;
                                eid : EntityId;
                                tank_engine__isWorking : bool;
                                var tank_engine__commandSent : bool&)
  if tank_engine__commandSent
    return
  tank_engine__commandSent = true
  sendEvent(eid, EventGmEngineOnOff(
      value = !tank_engine__isWorking))

[es, unused_argument(evt)]
def tank_engine_state_turn_on_es(evt : EventTryEnableEngine;
                                 eid : EntityId;
                                 tank_engine__isWorking : bool;
                                 var tank_engine__commandSent : bool&)
  if tank_engine__commandSent || tank_engine__isWorking
    return
  tank_engine__commandSent = true
  sendEvent(eid, EventGmEngineOnOff(
      value = true))

[es(tag=server)]
def tank_engine_state_on_off_es(evt : EventGmEngineOnOff;
                                var tank_engine__isWorking : bool&)
  tank_engine__isWorking = evt.value

[es(on_event=EventUnitRepair, on_event=EventUnitRespawn)]
def tank_engine_state_respawn_handler_es(evt : Event;
                                         var tank_engine__isWorking : bool&;
                                         var tank_engine__commandSent : bool&;
                                         var tank_engine__soundStarted : bool&)
  tank_engine__isWorking = true
  tank_engine__commandSent = false
  tank_engine__soundStarted = false