require ecs
require ecs.common
require strings
require %game.events
require %appGame.wt_events


def private do_recreation(eid : EntityId;
                          entity__recreateToOnDeath : string;
                          entity__playerEntityrecreateSubTemplate : string;
                          hasUnitCrewSquadSpawner : bool;
                          hasPlayerUnit : bool)
  
  let sourceFullTemplate = getEntityFutureTemplateName(eid)
  let sourceTemplates <- split_template(sourceFullTemplate)
  var destTemplate = entity__recreateToOnDeath
  if length(sourceTemplates) > 1
    let baseTemplate = hasUnitCrewSquadSpawner ? "{sourceTemplates[0]}+{sourceTemplates[1]}" : sourceTemplates[0]
    let subTemlates = replace(sourceFullTemplate, "{baseTemplate}+", "")
    destTemplate = "{entity__recreateToOnDeath}+{subTemlates}"
  if hasPlayerUnit && entity__playerEntityrecreateSubTemplate != ""
    destTemplate = add_sub_template_name(destTemplate, entity__playerEntityrecreateSubTemplate)
  reCreateEntityFrom(eid, destTemplate)


[es]
def recreate_on_death(evt : ParallelUpdateFrameDelayed)
  var counter = 5
  find_query() <| $ [es] (recreate_dead_entity__maxPerUpdate : int)
    counter = recreate_dead_entity__maxPerUpdate
    return true
  find_query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                                  isAlive : bool;
                                                  reanimation__available : bool;
                                                  entity__recreateToOnDeath : string;
                                                  entity__playerEntityrecreateSubTemplate : string = "";
                                                  unit_crew__squadSpawner : Tag const?;
                                                  playerUnit : Tag const?)
    if (!isAlive && !reanimation__available)
      do_recreation(eid, entity__recreateToOnDeath, entity__playerEntityrecreateSubTemplate, unit_crew__squadSpawner != null, playerUnit != null)
      return --counter == 0
    return false


[es(REQUIRE=deadEntity)]
def recreate_on_real_death_es(evt : EventDiedNotReanimated;
                              eid : EntityId;
                              isAlive : bool;
                              entity__recreateToOnDeath : string;
                              entity__playerEntityrecreateSubTemplate : string = "";
                              unit_crew__squadSpawner : Tag const?;
                              playerUnit : Tag const?)
  if !isAlive
    do_recreation(eid, entity__recreateToOnDeath, entity__playerEntityrecreateSubTemplate, unit_crew__squadSpawner != null, playerUnit != null)

[es(on_appear, REQUIRE_NOT=playerUnit, REQUIRE=(deadEntity, player_human_unit))] 
def remove_player_dead_entity_sub_template(evt : Event;
                                           eid : EntityId;
                                           entity__playerEntityrecreateSubTemplate : string)
  removeSubTemplate(eid, entity__playerEntityrecreateSubTemplate)
