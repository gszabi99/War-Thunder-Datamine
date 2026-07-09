require ecs
require app

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require human_sounds.modules.human_sounds_events
require %game.dm.dm_events
require %appGame.infantry.es.team_common
require sound_utils.modules.sound_player_common
require soundEvent


let MAX_NET_DELAY = 3.

[es(tag=sound, REQUIRE_NOT=shootingRangeDummy)]
def human_hit_cry_sound(evt : CmdHumanHitNetSound;
                        eid : EntityId;
                        human_hit_cry_sound__cooldown : float;
                        var human_hit_cry_sound__nextTime : float&)
  if get_sync_time() < evt.time + MAX_NET_DELAY && get_sync_time() >= human_hit_cry_sound__nextTime
    human_hit_cry_sound__nextTime = get_sync_time() + human_hit_cry_sound__cooldown
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "hitCry"))


[es(tag=sound, REQUIRE_NOT=shootingRangeDummy)]
def human_hit_by_vehicle_sound(evt : CmdHumanHitNetSound;
                               eid : EntityId;
                               transform : float3x4;
                               sound_preset__isLoaded : bool;
                               human_sound__prefix : string = "")
  if !sound_preset__isLoaded || get_sync_time() >= evt.time + MAX_NET_DELAY
    return

  if evt.damageType != int(DamageType.DM_COLLISION) || evt.offender == eid || evt.offender == INVALID_ENTITY_ID
    return

  var collisionHandle = set_var_optional_and_play("intense", 1.0, "{human_sound__prefix}effects/collision_body", "", transform[3])
  abandon(collisionHandle)


[es(tag=sound, REQUIRE_NOT=shootingRangeDummy)]
def human_hit_cry_sound_from_projectile(evt : EventOnHitEntity; 
                                        eid : EntityId;
                                        team : int;
                                        human_hit_cry_sound__cooldown : float;
                                        var human_hit_cry_sound__nextTime : float&)
  if  get_sync_time() >= human_hit_cry_sound__nextTime
    let isFriendly = is_teams_friendly(get_int(evt.offender, "team") ?? TEAM_UNASSIGNED, team)
    if isFriendly
      return
    human_hit_cry_sound__nextTime = get_sync_time() + human_hit_cry_sound__cooldown
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "hitCry"))
