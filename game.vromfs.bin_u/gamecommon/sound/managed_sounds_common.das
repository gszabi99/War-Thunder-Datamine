require ecs
require DagorMath
require math.base
require Sound
require ECSGlobalTags

let FAR_LOD_IDX = 1
let AIM_AT_LISTENER_CONE_COS = 0.866 


enum ManagedSoundGroupType
  MSND_HUMAN_STEPS
  MSND_HUMAN_STEPS_ENEMY
  MSND_HUMAN_GUN
  MSND_HUMAN_GUN_ENEMY


def get_managed_sound_group_type_index(type_name : string) : int
  if type_name == "human_steps"
    return int(ManagedSoundGroupType.MSND_HUMAN_STEPS)
  if type_name == "human_steps_enemy"
    return int(ManagedSoundGroupType.MSND_HUMAN_STEPS_ENEMY)
  if type_name == "human_gun"
    return int(ManagedSoundGroupType.MSND_HUMAN_GUN)
  if type_name == "human_gun_enemy"
    return int(ManagedSoundGroupType.MSND_HUMAN_GUN_ENEMY)
  return -1


def filter_human_gun(gun_eid : EntityId;
                     gun__owner : EntityId;
                     listener_pos : float3;
                     var sound_pos : float3&;
                     var aim_at_listener : bool&;
                     var visible_to_listener : bool&) : bool
  var isChosen = false
  aim_at_listener = false
  visible_to_listener = false
  query(gun__owner) <| $ [es(REQUIRE_NOT=watchedHero)] (human_weap__currentGunEid : EntityId;
                                                        human_net_phys__aimDir : float3 = float3(0., 0., 1.);
                                                        transform : float3x4;
                                                        nodes_los__visible : bool = false)
    sound_pos = transform[3]
    isChosen = human_weap__currentGunEid == gun_eid
    if isChosen
      visible_to_listener = nodes_los__visible
      let toListener = listener_pos - transform[3]
      let toListenerLenSq = length_sq(toListener)
      if toListenerLenSq > 1e-6
        let dotVal = dot(human_net_phys__aimDir, toListener) / sqrt(toListenerLenSq)
        if dotVal >= AIM_AT_LISTENER_CONE_COS
          aim_at_listener = true
  return isChosen


def get_watched_hero_info(var hero_pos : float3&; var hero_fwd_xz : float2&; var hero_team : int&)
  hero_pos = get_cached_listener_pos()
  hero_fwd_xz = float2(0.0, 1.0)
  hero_team = -1
  query() <| $ [es(REQUIRE=watchedHero)] (transform : float3x4;
                                          human_net_phys__aimDir : float3 = float3(0.0, 0.0, 1.0);
                                          drone__owner : EntityId = INVALID_ENTITY_ID;
                                          team : int)
    if drone__owner != INVALID_ENTITY_ID
      query(drone__owner) <| $ [es] (transform : float3x4;
                                     human_net_phys__aimDir : float3 = float3(0.0, 0.0, 1.0))
        hero_pos = transform[3]
        hero_fwd_xz = float2(human_net_phys__aimDir.x, human_net_phys__aimDir.z)
        if length_sq(hero_fwd_xz) < 1e-6
          hero_fwd_xz = float2(0.0, 1.0)
    else
      hero_pos = transform[3]
      hero_fwd_xz = float2(human_net_phys__aimDir.x, human_net_phys__aimDir.z)
      if length_sq(hero_fwd_xz) < 1e-6
        hero_fwd_xz = float2(0.0, 1.0)
    hero_team = team
