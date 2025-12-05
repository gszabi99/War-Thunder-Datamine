require ecs
require human_net_speech.modules.human_net_speech_request_common


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def squad_member_was_killed_net_speech(evt : Event;
                                       eid aka victim_eid : EntityId;
                                       squad_member__squad aka victim_squad_member__squad : EntityId;
                                       transform aka victim_transform : float3x4)
  if !victim_squad_member__squad
    return
  var numAliveMembers = 0
  var playerSpeaker = INVALID_ENTITY_ID
  var botSpeaker = INVALID_ENTITY_ID
  var botSpeakerDistSq = 0.

  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid, squad_member__squad, possessedByPlr : EntityId; transform : float3x4; concussion__isActive = false)
    if squad_member__squad == victim_squad_member__squad && eid != victim_eid
      ++numAliveMembers

      if !concussion__isActive
        if !!possessedByPlr
          playerSpeaker = eid
        elif botSpeaker == INVALID_ENTITY_ID || distance_sq(victim_transform[3], transform[3]) < botSpeakerDistSq
          botSpeakerDistSq = distance_sq(victim_transform[3], transform[3])
          botSpeaker = eid

  if numAliveMembers == 1
    request_net_speech(playerSpeaker, "leftAloneInSquad")
  else
    request_net_speech_except_possessed(botSpeaker, "squadMemberKilled", victim_eid)
