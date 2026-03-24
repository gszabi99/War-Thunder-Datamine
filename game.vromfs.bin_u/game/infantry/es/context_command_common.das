module context_command_common shared

require ecs
require ecs.enum_macro
require %appGame.infantry.input.human_context_command_point_common
require %appGame.infantry.client.destroyable_wall_client_common

[export_enum]
enum ContextCommand
  ECC_DISABLED 
  ECC_NONE
  ECC_CANCEL
  ECC_REVIVE
  ECC_BUILD
  ECC_SELECT_SQUAD_MATE
  ECC_START_POINT_OVERWATCH_ORDER
  ECC_END_POINT_ORDER
  ECC_DEFEND_POINT
  ECC_ATTACK_TARGET
  ECC_BRING_AMMO
  ECC_PLANT_BOMB
  ECC_DEFUSE_BOMB


def human_context_command_menu_init_context(human_eid : EntityId)
  query(human_eid) <| $ [es] (var human_context_command__menuCtxPos : float3&;
                              var human_context_command__menuCtxType : das_string&;
                              var human_context_command__menuCtxEid : EntityId&;
                              var human_context_command__menuCtxTracePos : float3&;
                              var human_context_command__menuCtxTraceDir : float3&;
                              squad_member__squad : EntityId = INVALID_ENTITY_ID;
                              team : int = -1)
    human_context_command__menuCtxPos = float3()
    human_context_command__menuCtxType := "" 
    human_context_command__menuCtxEid = INVALID_ENTITY_ID
    human_context_command__menuCtxTracePos = float3()
    human_context_command__menuCtxTraceDir = float3()

    if !human_point_get_trace_pos_dir(human_eid, human_context_command__menuCtxTracePos, human_context_command__menuCtxTraceDir)
      return

    var traced = HumanPointOrderTraced()
    if human_point_order_trace_spot(human_eid, int(HumanPointOrderType.POINT_DETECT_CONTEXT), traced)
      human_context_command__menuCtxPos = traced.pos
      human_context_command__menuCtxEid = traced.eid

      
      
      

      if traced.kind == int(HumanPointTargetKind.DOOR)
        human_context_command__menuCtxType := "door"
        query(traced.eid) <| $ [es] (rendinst_axis_rotation__targetAngle : float; door_operations__closedAngle : float)
          if rendinst_axis_rotation__targetAngle == door_operations__closedAngle
            human_context_command__menuCtxType := "closed_door"
      elif traced.kind == int(HumanPointTargetKind.DESTROYABLE_WALL)
        human_context_command__menuCtxType := "destr_wall"
        let riFlags = determine_mining_wall_flags(traced.eid)
        if (riFlags & int(MineWallFlag.CAN_MINE)) != 0
          human_context_command__menuCtxType := "destr_wall_plant_mine"
        elif (riFlags & int(MineWallFlag.CAN_REASSEMBLE)) != 0
          human_context_command__menuCtxType := "destr_wall_reassemble"
      elif traced.kind == int(HumanPointTargetKind.HUMAN)
        if !!squad_member__squad && squad_member__squad == traced.eid |> get_Eid("squad_member__squad") ?? INVALID_ENTITY_ID
          human_context_command__menuCtxType := "squad_mate"
        elif team != -1 && team == traced.eid |> get_int("team") ?? -1
          human_context_command__menuCtxType := "ally_human"
        else
          human_context_command__menuCtxType := "enemy_human"
      elif traced.kind == int(HumanPointTargetKind.VEHICLE)
        if team != -1 && team == traced.eid |> get_int("team") ?? -1
          human_context_command__menuCtxType := "ally_vehicle"
        else
          human_context_command__menuCtxType := "enemy_vehicle"
      elif traced.kind == int(HumanPointTargetKind.NONOBJ)
        human_context_command__menuCtxType := "non_obj"
      else
        human_context_command__menuCtxType := "unknown"
