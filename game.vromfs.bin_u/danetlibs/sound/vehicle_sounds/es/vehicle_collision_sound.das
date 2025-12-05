require ecs
require DagorMath
require math.base
require soundEvent
require soundSystem
require vehicleSoundProps
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events
require sound_utils.modules.sound_utils_events
require PhysMat


def update_hit(info : ParallelUpdateFrameDelayed;
               var sound_event : SoundEvent&;
               var hit_time : float&;
               var hit_force : float&;
               mat_props : SoundVehiclePhysMatProps const?;
               coll : float;
               name : string;
               pos : float3;
               @shared_comp sound_paths : Object;
               sound_tags : Object)
  let defMaxImpulse = float2(0.75, 3.)
  let minMaxImpulse = mat_props != null ? (*mat_props).minMaxImpulse : defMaxImpulse
  let force = cvt(coll, minMaxImpulse.x, minMaxImpulse.y, 0., 1.)
  sound_player_common::play_parameterized(sound_event, name, force, hit_force, "force", pos, sound_paths, sound_tags, true, info.curTime, hit_time)


def update_scrape(info : ParallelUpdateFrameDelayed;
                  var sound_event : SoundEvent&;
                  var scrape_timer : float&;
                  mat_props : SoundVehiclePhysMatProps const?;
                  coll : float;
                  pos : float3;
                  is_watched_sound : bool;
                  @shared_comp sound_paths : Object;
                  sound_tags : Object)
  if is_watched_sound
    let defMaxScrape = float2(0.35, 0.5)
    let minMaxScrape = mat_props != null ? (*mat_props).minMaxScrape : defMaxScrape
    let scrape = cvt(coll, minMaxScrape.x, minMaxScrape.y, 0., 1.)
    if scrape > 0.
      if !is_valid_event_instance(sound_event)
        release(sound_event)
        sound_event |> reset(sound_player_common::play_path("collScrape", sound_paths, sound_tags, is_watched_sound, pos, false))
      set_var(sound_event, "force", scrape)
      set_pos(sound_event, pos)
      set_volume(sound_event, 1.)
      scrape_timer = 0.
      return
  let scrapeTimeThreshold = 4.
  if scrape_timer < scrapeTimeThreshold
    set_volume(sound_event, max(1. - scrape_timer, 0.))
    scrape_timer += info.dt
    if scrape_timer >= scrapeTimeThreshold
      abandon(sound_event)


[es(tag=sound)]
def vehicle_collision_sound_on_collision(evt : EventOnCollision;
                                         var vehicle_collision_sound__entityCollSummary : float&;
                                         var vehicle_collision_sound__entityCollMatId : int&;
                                         vehicle_collision_sound__enabled : bool)
  if vehicle_collision_sound__enabled
    vehicle_collision_sound__entityCollSummary += length(evt.vel)
    vehicle_collision_sound__entityCollMatId = PHYSMAT_DEFAULT
    query(evt.offender) <| $ [es] (material : string)
      vehicle_collision_sound__entityCollMatId = get_material_id(material)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_collision_sound(info : ParallelUpdateFrameDelayed;
                            vehicle_collision_sound__collRange : float2;

                            var vehicle_collision_sound__enabled : bool&;
                            var vehicle_collision_sound__entityCollSummary : float&;
                            var vehicle_collision_sound__entityCollMatId : int&;

                            var vehicle_hit_sound_event : SoundEvent&;
                            var vehicle_collision_sound__hitTime : float&;
                            var vehicle_collision_sound__hitForce : float&;

                            var vehicle_scrape_sound_event : SoundEvent&;
                            var vehicle_collision_sound__scrapeTimer : float&;
                            vehicle_collision_sound__scrapeMinMax : float2;

                            vehicle_sound_phys_state__deltaShock : float;
                            vehicle_sound_phys_state__noiseReduction : float;

                            is_watched_sound : bool;

                            @shared_comp vehicle_collision_sound__paths : Object;

                            sound_tags : Object;

                            transform : float3x4)

  let enable = (vehicle_collision_sound__enabled ?
    is_watched_sound || length_sq(transform[3] - get_listener_pos()) < square(vehicle_collision_sound__collRange.y) :
    is_watched_sound || length_sq(transform[3] - get_listener_pos()) < square(vehicle_collision_sound__collRange.x))
  assert(vehicle_collision_sound__collRange.y > vehicle_collision_sound__collRange.x)

  if vehicle_collision_sound__enabled != enable
    vehicle_collision_sound__enabled = enable
    vehicle_collision_sound__entityCollSummary = 0.
    vehicle_collision_sound__entityCollMatId = PHYSMAT_DEFAULT
    abandon(vehicle_hit_sound_event)
    abandon(vehicle_scrape_sound_event)

  if !vehicle_collision_sound__enabled
    return

  var coll = 0.
  var descName = ""
  var matProps : SoundVehiclePhysMatProps const? = null
  let treeCollision = false

  if vehicle_sound_phys_state__deltaShock > vehicle_collision_sound__entityCollSummary
    coll = vehicle_sound_phys_state__deltaShock
    descName = treeCollision ? "collTree" : "collGeneric"
  else
    coll = vehicle_collision_sound__entityCollSummary

  vehicle_physmat_sound_get_props(vehicle_collision_sound__entityCollMatId) <| $(props : SoundVehiclePhysMatProps)
    descName = props.collDesc

  vehicle_collision_sound__entityCollSummary = 0.
  vehicle_collision_sound__entityCollMatId = PHYSMAT_DEFAULT

  update_hit(info, vehicle_hit_sound_event, vehicle_collision_sound__hitTime, vehicle_collision_sound__hitForce, matProps, coll, descName, transform[3], vehicle_collision_sound__paths, sound_tags)

  let decayScrapeReduction = 10.
  let scrape = cvt(coll, vehicle_collision_sound__scrapeMinMax.x, vehicle_collision_sound__scrapeMinMax.y, 0., 1.) * min(vehicle_sound_phys_state__noiseReduction * decayScrapeReduction, 1.)
  update_scrape(info, vehicle_scrape_sound_event, vehicle_collision_sound__scrapeTimer, matProps, scrape, transform[3], is_watched_sound, vehicle_collision_sound__paths, sound_tags)
