require ecs
require %game.events
require AnimV20

let
  upperHash = ecs_hash("upper")
  lowerHash = ecs_hash("lower")

def get_state_id_or(eid : EntityId; state : string; default_value : int)
  var res = default_value
  query(eid) <| $ [es] (animchar : AnimcharBaseComponent)
    let animGraph = animchar.animGraph
    if animGraph != null
      res = anim_graph_getStateIdx(*animGraph, state)
  return res

[es(on_appear)]
def init_force_anim(evt : Event;
                    game_effect__attachedTo : EntityId;
                    game_effect__forceAnimState : string;
                    var game_effect__forceAnimStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    game_effect__forceAnimStateId = get_state_id_or(eid, game_effect__forceAnimState, game_effect__forceAnimStateId)
    send_change_anim_state_event(game_effect__attachedTo, "lower", lowerHash, game_effect__forceAnimStateId)
    send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimStateId)

[es(on_appear)]
def init_force_anim_lower(evt : Event;
                          game_effect__attachedTo : EntityId;
                          game_effect__forceAnimLowerState : string;
                          var game_effect__forceAnimLowerStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    game_effect__forceAnimLowerStateId = get_state_id_or(eid, game_effect__forceAnimLowerState, game_effect__forceAnimLowerStateId)
    send_change_anim_state_event(game_effect__attachedTo, "lower", lowerHash, game_effect__forceAnimLowerStateId)

[es(on_appear)]
def init_force_anim_upper(evt : Event;
                          game_effect__attachedTo : EntityId;
                          game_effect__forceAnimUpperState : string;
                          var game_effect__forceAnimUpperStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    game_effect__forceAnimUpperStateId = get_state_id_or(eid, game_effect__forceAnimUpperState, game_effect__forceAnimUpperStateId)
    send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimUpperStateId)

[es(on_appear)]
def init_force_anim_upper_crawl(evt : Event;
                                game_effect__attachedTo : EntityId;
                                game_effect__forceAnimUpperCrawlState : string;
                                var game_effect__forceAnimUpperCrawlStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    game_effect__forceAnimUpperCrawlStateId = get_state_id_or(eid, game_effect__forceAnimUpperCrawlState, game_effect__forceAnimUpperCrawlStateId)
    if (get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
      send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimUpperCrawlStateId)

[es(on_appear)]
def init_force_anim_upper_non_crawl(evt : Event;
                                    game_effect__attachedTo : EntityId;
                                    game_effect__forceAnimUpperNonCrawlState : string;
                                    var game_effect__forceAnimUpperNonCrawlStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    game_effect__forceAnimUpperNonCrawlStateId = get_state_id_or(eid, game_effect__forceAnimUpperNonCrawlState, game_effect__forceAnimUpperNonCrawlStateId)
    if !(get_bool(game_effect__attachedTo, "human_net_phys__isCrawl") ?? false)
      send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimUpperNonCrawlStateId)

[es(after=human_gun_phys_vars_es)]
def force_anim_state_es(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimStateId : int)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    send_change_anim_state_event(eid, "lower", lowerHash, game_effect__forceAnimStateId)
    send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_lower(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimLowerStateId : int)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    send_change_anim_state_event(eid, "lower", lowerHash, game_effect__forceAnimLowerStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperStateId : int)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    send_change_anim_state_event(eid, "upper", upperHash, game_effect__forceAnimUpperStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper_non_crawl(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperNonCrawlStateId : int)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    if !(get_bool(eid, "human_net_phys__isCrawl") ?? false)
      send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimUpperNonCrawlStateId)

[es(after=human_anim_es, before=force_anim_state_es)]
def force_anim_state_upper_crawl(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; game_effect__forceAnimUpperCrawlStateId : int)
  query(game_effect__attachedTo) <| $ [es] (eid : EntityId)
    if (get_bool(eid, "human_net_phys__isCrawl") ?? false)
      send_change_anim_state_event(game_effect__attachedTo, "upper", upperHash, game_effect__forceAnimUpperCrawlStateId)
