options no_aot
require ecs
require app
require math
require math.base
require DagorConsole
require %appGame.infantry.es.net_console_macro


def private find_plant_site(site_name : string) : EntityId
  var siteEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=plantSite)] (eid : EntityId; plant_site__name : string)
    if plant_site__name != site_name
      return false
    siteEid = eid
    return true
  if siteEid == INVALID_ENTITY_ID
    error("plant_site '{site_name}' not found")
  return siteEid


[console_cmd(name="plant_site.dump")]
def plant_site_dump()
  query() <| $ [es(REQUIRE=plantSite)] (eid : EntityId;
                                        active : bool;
                                        plant_site__destroyed : bool;
                                        plant_site__name : string;
                                        bomb_site__plantingTeam : int;
                                        bomb_site__operator : EntityId;
                                        bomb_site__isBombPlanted : bool)
    console_print("plant_site(eid={eid}): name='{plant_site__name}' active={active} team={bomb_site__plantingTeam}  destroyed={plant_site__destroyed} operator={uint(bomb_site__operator)} planted={bomb_site__isBombPlanted}")


[net_console_cmd(name="plant_site.force_plant")]
def plant_site_force_plant(site_name : string; @net_hero hero_eid : EntityId)
  query(find_plant_site(site_name)) <| $ [es] (bomb_site__isBombPlanted : bool;
                                               var bomb_site__operator : EntityId&;
                                               var bomb_site__plantProgress : float&;
                                               var bomb_site__plantProgressDeltaPerSec : float&)
    if bomb_site__isBombPlanted
      return
    bomb_site__operator = hero_eid
    bomb_site__plantProgress = 1.0
    bomb_site__plantProgressDeltaPerSec = 1.0


[net_console_cmd(name="plant_site.force_defuse")]
def plant_site_force_defuse(site_name : string; @net_hero hero_eid : EntityId)
  query(find_plant_site(site_name)) <| $ [es] (bomb_site__isBombPlanted : bool;
                                               var bomb_site__operator : EntityId&;
                                               var bomb_site__defuseProgress : float&;
                                               var bomb_site__defuseProgressDeltaPerSec : float&)
    if !bomb_site__isBombPlanted
      return
    bomb_site__operator = hero_eid
    bomb_site__defuseProgress = 0.0
    bomb_site__defuseProgressDeltaPerSec = 0.0


[net_console_cmd(name="plant_site.set_timer")]
def plant_site_set_timer(site_name : string; time_left : float)
  query(find_plant_site(site_name)) <| $ [es] (bomb_site__isBombPlanted : bool;
                                               bomb_site__isBombTicking : bool;
                                               var bomb_site__timeToExplosionLeft : float&;
                                               var bomb_site__explosionTimeEnd : float&;
                                               var bomb_site__explosionTimerPausedAtTime : float&)
    if !bomb_site__isBombPlanted
      return
    bomb_site__timeToExplosionLeft = time_left
    if bomb_site__isBombTicking
      bomb_site__explosionTimeEnd = get_sync_time() + time_left
    else
      bomb_site__explosionTimerPausedAtTime = time_left


[net_console_cmd(name="plant_site.set_active")]
def plant_site_set_active(site_name : string; is_active : bool)
  query(find_plant_site(site_name)) <| $ [es] (var active : bool&)
    active = is_active


[net_console_cmd(name="plant_site.force_detonate")]
def plant_site_force_detonate(site_name : string)
  query(find_plant_site(site_name)) <| $ [es] (var bomb_site__isBombPlanted : bool&;
                                               var bomb_site__operator : EntityId&;
                                               var bomb_site__timeToExplosionLeft : float&)
    bomb_site__isBombPlanted = true
    bomb_site__operator = INVALID_ENTITY_ID
    bomb_site__timeToExplosionLeft = 0.0
