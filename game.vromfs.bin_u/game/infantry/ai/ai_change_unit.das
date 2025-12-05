require ecs
require %game.player_events
require %appGame.infantry.es.drone_common
require %appGame.infantry.es.loc_squad_common

[es(tag=server)]
def human_ai_disable_on_switch_from(evt : EventPlayerChangeControlFrom;
                                    var beh_tree__enabled : bool&)
  beh_tree__enabled = true


[es(tag=server, before=human_ai_disable_on_switch_from)]
def human_ai_become_droner_on_switch_from(evt : EventPlayerChangeControlFrom;
                                          eid : EntityId;
                                          var beh_tree__wantRoleDroner : bool&)
  if get_controlled_drone_from_owner(eid) != INVALID_ENTITY_ID
    beh_tree__wantRoleDroner = true


[es(tag=server, track=(beh_tree__enabled, beh_tree__wantRoleDroner))]
def human_ai_bot_switch_beh(evt : Event;
                            eid : EntityId;
                            beh_tree__enabled : bool;
                            beh_tree__wantRoleDroner : bool;
                            beh_tree__nodeDefault : string;
                            beh_tree__nodeDroner : string;
                            var beh_tree__role : das_string&;
                            var beh_tree__node : das_string&)
  if !beh_tree__enabled
    return

  var role = ""
  var node = beh_tree__nodeDefault
  if beh_tree__wantRoleDroner
    role = "role_droner"
    node = beh_tree__nodeDroner

  if role == beh_tree__role
    return

  beh_tree__role := role
  beh_tree__node := node
  reload_squad_mate_beh_tree(eid)


[es(tag=server)]
def human_ai_enable_on_switch_to(evt : EventPlayerChangeControlTo;
                                 squad_member__playerEid : EntityId;
                                 var beh_tree__enabled : bool&)
  if !has(squad_member__playerEid, "playerIsBot")
    beh_tree__enabled = false
