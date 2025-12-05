require ecs
require DngHuman
require %appGame.infantry.es.team_common

require %appGame.wt_events
require %appGame.infantry.es.inventory_common

















[es(tag=server, after=human_inventory_fill_guns_custom_props_on_death)]
def drop_held_weapon_on_death(evt : EventEntityDied;
                              eid : EntityId;
                              human_weap__gunEids : EidList)
  let isDropRestricted = is_teams_friendly(evt.victimTeam, evt.offenderTeam) && find_query() <| $ [es(REQUIRE=disableTeamkillWeaponDrops)] () => true
  if !isDropRestricted && !has(human_weap__gunEids[int(HUWeaponSlots.EWS_PRIMARY)], "disableItemDrop")
    
    
    drop_weap_from_slot_impl(eid, int(HUWeaponSlots.EWS_PRIMARY), false, true)



















































































