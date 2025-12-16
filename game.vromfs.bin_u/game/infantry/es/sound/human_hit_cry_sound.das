require ecs
require app

require %appGame.wt_events
require human_sounds.modules.human_sounds_events
require %game.dm.dm_events
require %appGame.infantry.es.team_common


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
