module human_use_object_common shared
require ecs
require net
require math.base
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.squad_personal_order_common


def human_try_use_object(user_eid : EntityId;
                         user_position : float3;
                         use_distance_threshold : float;
                         used_object_eid : EntityId)
  var done = false
  query(used_object_eid) <| $ [es] (squad_member__squad : EntityId)
    query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
      if squad__leader == user_eid
        query(user_eid) <| $ [es] (var personal_bot_order__currentBotEid : EntityId&)
          if is_bot_valid_for_personal_order(user_eid, used_object_eid)
            personal_bot_order__currentBotEid = used_object_eid
        done = true
  if done
    return

  query(used_object_eid) <| $ [es] (transform : float3x4)
    if length_sq(user_position - transform[3]) <= square(use_distance_threshold)
      if !is_server()
        sendEvent(user_eid, HumanUseObjectRequest(objectEid = used_object_eid))
      else
        sendEvent(used_object_eid, CmdUse(requesterEid = user_eid))

def human_try_use_object_alt(user_eid : EntityId;
                             user_position : float3;
                             use_distance_threshold : float;
                             used_object_eid : EntityId)
  query(used_object_eid) <| $ [es] (transform : float3x4)
    if length_sq(user_position - transform[3]) <= square(use_distance_threshold)
      if !is_server()
        send_net_event(user_eid, HumanUseAltObjectRequest(objectEid = used_object_eid))
      else
        sendEvent(used_object_eid, CmdUseAlt(requesterEid = user_eid))
