require ecs
require ecs.safe
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require gameLibs.pufd_events.pufd_events
require DagorMath
require math.base
require PhysMat


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def human_collision_scrape_sound_update(evt : ParallelUpdateFrameDelayed;
                                        sound_preset__isLoaded : bool;
                                        human_net_phys__velocity : float3;
                                        human_net_phys__curMoveState : int;
                                        human_net_phys__isInAir : bool;
                                        human_collision_scrape_sound__descIdx : int;
                                        @shared_comp human_collision_scrape_sound__descs : Array;
                                        human_collision_scrape_sound__speedToForce : float4;
                                        var human_collision_scrape_sound__nextTime : float&;
                                        human_collision_scrape_sound__cooldown : float;
                                        var sound_event_group : SoundEventGroup&;
                                        sound_tags : Object;
                                        is_watched_sound : bool;
                                        human_sound__prefix : string = "";
                                        transform : float3x4)
  var handle = get_sound(sound_event_group, sound_hash("collisionScrape"))
  if !is_valid_handle_value(handle) && sound_preset__isLoaded && evt.curTime >= human_collision_scrape_sound__nextTime
    let isMoving = human_net_phys__curMoveState > 0 || human_net_phys__isInAir
    if human_collision_scrape_sound__descIdx >= 0 && length_sq(human_net_phys__velocity) > square(human_collision_scrape_sound__speedToForce.x) && isMoving
      let desc = human_collision_scrape_sound__descs[human_collision_scrape_sound__descIdx] as Object
      if desc != null
        handle = play_path(*desc, sound_tags, is_watched_sound, transform[3], sound_hash("collisionScrape"), sound_event_group, 0., human_sound__prefix)
        human_collision_scrape_sound__nextTime = evt.curTime + human_collision_scrape_sound__cooldown
  if is_playing(handle)
    let force = cvt(length(human_net_phys__velocity), human_collision_scrape_sound__speedToForce.x, human_collision_scrape_sound__speedToForce.y, human_collision_scrape_sound__speedToForce.z, human_collision_scrape_sound__speedToForce.w)
    set_var_optional(handle, "force", force)


[es(tag=sound, track=human_collision_scrape_sound__descIdx, REQUIRE=human_collision_scrape_sound__descIdx)]
def human_collision_scrape_sound_track(evt : Event;
                                       var sound_event_group : SoundEventGroup&)
  reject_sound(sound_event_group, sound_hash("collisionScrape"))
