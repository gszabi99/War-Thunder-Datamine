require ecs
require app
require math.base
require DngWalkerai
require DngHuman
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

[es(tag=server)]
def on_cancel_squad_mate_order(squadMateOrder : RequestSquadMateOrder; eid : EntityId; squad__leader : EntityId)
  if squadMateOrder.orderType == SquadMateOrder.ESMO_NO_ORDER
    reset_squad_mate_orders(eid, squad__leader)
    reset_squad_behaviour(eid)

    query(eid) <| $ [es] (var squad__followLeaderGenTimer : float&)
      squad__followLeaderGenTimer = -1.0

[es(tag=server)]
def on_cancel_personal_squadmate_order(personalSquadMateOrder : RequestPersonalSquadMateOrder; eid : EntityId)
  if personalSquadMateOrder.orderType == int(SquadMateOrder.ESMO_NO_ORDER)
    if has_next_squad_mate_order(eid)
      switch_to_next_squad_mate_order(eid)
    else
      reset_personal_squadmate_orders(eid)
    reset_squad_mate_behaviour(eid)

    query(eid) <| $ [es] (squad_member__squad : EntityId)
      query(squad_member__squad) <| $ [es] (var squad__followLeaderGenTimer : float&)
        squad__followLeaderGenTimer = -1.0









[es(tag=server, no_order)]
def sync_squad_mate_order_status(act : UpdateStageInfoAct; eid : EntityId; squad__leader : EntityId;
                                 squad__numAliveMembers : int; var squad__hasPersonalOrder : bool&)
  squad__hasPersonalOrder = squad__numAliveMembers > 1 && collect_squad(eid, squad__leader) <| $(member_eid : EntityId)
    return get_int(member_eid, "squad_member__orderType") ?? int(SquadMateOrder.ESMO_NO_ORDER) != int(SquadMateOrder.ESMO_NO_ORDER)
