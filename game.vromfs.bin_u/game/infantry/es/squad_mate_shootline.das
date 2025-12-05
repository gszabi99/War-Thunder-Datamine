
require ecs
require math.base
require DngHuman
require %appGame.infantry.es.squad_order_common
require %appGame.infantry.es.loc_squad_common
require %game.events

[es(tag=server, no_order)]
def on_squadmate_overwatch_danger_calc_shoot_line_mode(info : ParallelUpdateFrameDelayed;
                                                       var danger_calc__onShootLineMode : bool&;
                                                       beh_tree__enabled : bool;
                                                       human_net_phys : HumanActor;
                                                       squad_member__playerEid : EntityId;
                                                       squad_member__isPersonalOrder : bool;
                                                       squad_member__orderType : int;
                                                       squad_member__orderPosition : float3;
                                                       squad_member__orderByDirection : float3;
                                                       squad_member__minDistanceForShootLineMode : float = 1.5;
                                                       squad_member__minDotCosForShootLineMode : float = 0.75;
                                                       transform : float3x4)
  danger_calc__onShootLineMode = false

  if !beh_tree__enabled
    return

  var isBotPlayer = false
  query(squad_member__playerEid) <| $ [es(REQUIRE=playerIsBot)] ()
    isBotPlayer = true

  if !isBotPlayer
    if squad_member__isPersonalOrder && is_squad_mate_order_positional(squad_member__orderType)
      if distance_sq(transform[3], squad_member__orderPosition) < square(squad_member__minDistanceForShootLineMode)
        if dot(transform[0], squad_member__orderByDirection) > squad_member__minDotCosForShootLineMode
          danger_calc__onShootLineMode = true
  else
    assume ct = human_net_phys.phys.producedCT
    let isCrouch = ct |> is_control_bit_set(HumanPhysControlType.HCT_CROUCH)
    let isCrawl = ct |> is_control_bit_set(HumanPhysControlType.HCT_CRAWL)
    let standState = human_net_phys.phys.currentState.standState
    if (standState == HUStandState.ESS_CROUCH || isCrouch) && !isCrawl
      danger_calc__onShootLineMode = true
