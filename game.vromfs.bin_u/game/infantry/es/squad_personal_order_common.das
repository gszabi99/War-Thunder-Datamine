module squad_personal_order_common shared
require ecs
require ecs.common


def is_bot_valid_for_personal_order(squad_leader_eid : EntityId; bot_eid : EntityId)
  return bot_eid != squad_leader_eid && !has(bot_eid, "deadEntity") && doesEntityExist(bot_eid)

def find_next_bot_for_personal_order(squad_leader_eid : EntityId;
                                     squad_member__squad : EntityId;
                                     personal_bot_order__currentBotEid : EntityId)
  var foundBotEid = personal_bot_order__currentBotEid
  query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
    let count = length(squad__allMembers)

    if count > 1
      let curIndex = find_index(squad__allMembers, personal_bot_order__currentBotEid)
      var nextIndex = (curIndex + 1) % count
      var botEid = squad__allMembers[nextIndex]

      for _i in range(0, count)
        if nextIndex == curIndex
          break
        if is_bot_valid_for_personal_order(squad_leader_eid, botEid)
          foundBotEid = botEid
          break

        nextIndex = (nextIndex + 1) % count
        botEid = squad__allMembers[nextIndex]

  return foundBotEid

def find_spare_bot_for_personal_order(squad_leader_eid : EntityId;
                                      squad_member__squad : EntityId;
                                      personal_bot_order__currentBotEid : EntityId)
  var foundBotEid = INVALID_ENTITY_ID
  query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
    for memberEid in squad__allMembers
      if memberEid == squad_leader_eid
        continue
      if memberEid == personal_bot_order__currentBotEid
        continue
      query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__isPersonalOrder : bool)
        if !squad_member__isPersonalOrder
          foundBotEid = memberEid
      if !!foundBotEid
        break
  if !!foundBotEid
    return foundBotEid
  return find_next_bot_for_personal_order(squad_leader_eid, squad_member__squad, personal_bot_order__currentBotEid)
