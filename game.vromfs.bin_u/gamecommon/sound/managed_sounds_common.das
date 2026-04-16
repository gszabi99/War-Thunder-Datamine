require ecs
require DagorMath
require math.base
require Sound

let FAR_LOD_IDX = 1


def get_watched_hero_info(var hero_pos : float3&; var hero_fwd_xz : float2&; var hero_team : int&)
  hero_pos = get_cached_listener_pos()
  hero_fwd_xz = float2(0.0, 1.0)
  hero_team = -1
  query() <| $ [es(REQUIRE=watchedHero)] (transform : float3x4;
                                          human_net_phys__aimDir : float3 = float3(0.0, 0.0, 1.0);
                                          team : int)
    hero_pos = transform[3]
    hero_fwd_xz = float2(human_net_phys__aimDir.x, human_net_phys__aimDir.z)
    if length_sq(hero_fwd_xz) < 1e-6
      hero_fwd_xz = float2(0.0, 1.0)
    hero_team = team
