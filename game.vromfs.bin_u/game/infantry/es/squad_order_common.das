module squad_order_common shared

require ecs
require ecs.enum_macro
require %appGame.squad_order_enums
require %appGame.infantry.es.walker_common


def is_squad_mate_order_positional(order : int)
  return (order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STANDING) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP))

def is_squad_mate_order_action(order : int)
  return order != int(SquadMateOrder.ESMO_NO_ORDER) && !is_squad_mate_order_positional(order)


def is_squad_mate_order_overwatch_by_direction(order : int)
  return (order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE))

def is_squad_mate_order_peekout(order : int)
  return (order == int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STANDING) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP))

def is_squad_mate_order_throw_grenade(order : int)
  return (order == int(SquadMateOrder.ESMO_THROW_FRAG_GRENADE) ||
    order == int(SquadMateOrder.ESMO_THROW_SMOKE_GRENADE) ||
    order == int(SquadMateOrder.ESMO_THROW_FLASH_GRENADE))

def is_squad_mate_order_attack_vehicle(order : int)
  return order == int(SquadMateOrder.ESMO_ATTACK_VEHICLE)

def is_squad_mate_order_ignore_leader_stance(order : int)
  return (order == int(SquadMateOrder.ESMO_NO_ORDER) ||
    order != int(SquadMateOrder.ESMO_DEFEND_POINT))

def is_squad_mate_order_cancelled_when_too_far(order : int)
  return (order == int(SquadMateOrder.ESMO_DEFEND_POINT) ||
    order == int(SquadMateOrder.ESMO_USE_VEHICLE) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STANDING) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED) ||
    order == int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP))


def get_squad_mate_order(mate_eid : EntityId)
  var result = -1
  query(mate_eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                             squad_member__orderType : int)
    if squad_member__isPersonalOrder
      result = squad_member__orderType
  return result

def get_squad_mate_order_direction(mate_eid : EntityId)
  var result = float3()
  query(mate_eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                             squad_member__orderType : int;
                             squad_member__orderByDirection : float3;
                             squad_member__followLeader : bool;
                             squad_member__followLeaderDir : float3)
    if squad_member__isPersonalOrder && is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
      result = squad_member__orderByDirection
    elif squad_member__followLeader
      result = squad_member__followLeaderDir
  return result

def get_squad_mate_order_stance(order : int)
  if order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING) || order == int(SquadMateOrder.ESMO_PEEKOUT_STANDING)
    return STANCE_STAND
  if order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED) || order == int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED) || order == int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP)
    return STANCE_CROUCH
  if order == int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE)
    return STANCE_CRAWL
  return -1

def get_squad_mate_order_stance(mate_eid : EntityId)
  var result = -1
  query(mate_eid) <| $ [es] (squad_member__isPersonalOrder : bool;
                             squad_member__orderType : int;
                             squad_member__followLeader : bool;
                             squad_member__followLeaderStance : int)
    if squad_member__isPersonalOrder && is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
      result = get_squad_mate_order_stance(squad_member__orderType)
    elif squad_member__followLeader
      result = squad_member__followLeaderStance
  return result
