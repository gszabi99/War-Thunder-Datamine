require ecs
require ecs.safe
require soundSystem
require DagorDataBlock
require DagorDebug3D
require DagorMath
require DagorRandom
require DagorConsole
require DagorSystem
require math.base
require strings
require app
require %game.events
require Sound
require %game.sound.managed_sounds_common
require daslib/enum_trait

let UPDATE_INTERVAL = 0.05


[es(tag=sound, on_appear)]
def managed_sound_group_processing_init(evt : Event;
                                        var managed_sound_group_processing__list : EidList&;
                                        var managed_sound_group__updateTimer : float&)
  managed_sound_group__updateTimer = UPDATE_INTERVAL + gfrnd() * UPDATE_INTERVAL
  let cnt = typeinfo enum_length(type<ManagedSoundGroupType>)
  managed_sound_group_processing__list |> resize(cnt)


[es(tag=sound, on_appear)]
def managed_sound_group_init(evt : Event;
                             eid : EntityId;
                             managed_sound_group__type : string;
                             var managed_sound_group__lodRadiusSq : FloatList&;
                             var managed_sound_group__lodMaxSounds : IntList&;
                             var managed_sound_group__maxRadiusSq : float&)

  datablock_load_cached("config/sound_studio.blk") <| $(sndBlk : DataBlock)
    let typeBlk = sndBlk |> datablock_get_block_by_name(managed_sound_group__type)
    if typeBlk == null
      logerr("managed_sound_group_init: '{managed_sound_group__type}' block not found in sound_studio.blk")
      return

    let lodsBlk = *typeBlk |> datablock_get_block_by_name("lods")
    if lodsBlk == null
      logerr("managed_sound_group_init:  'lods' block not found in '{managed_sound_group__type}'")
      return

    clear(managed_sound_group__lodRadiusSq)
    clear(managed_sound_group__lodMaxSounds)
    var maxRadiusSq = 0.0

    for blk_i in 0u..lodsBlk.blockCount
      let lodBlk = *lodsBlk |> datablock_get_block(blk_i)
      if lodBlk == null
        continue
      let radius = *lodBlk |> datablock_getReal("radius", 0.0)
      let maxSounds = *lodBlk |> datablock_getInt("maxSounds", 0)
      let radiusSq = radius * radius
      push(managed_sound_group__lodRadiusSq, radiusSq)
      push(managed_sound_group__lodMaxSounds, (maxSounds + 3) & ~3)
      if radiusSq > maxRadiusSq
        maxRadiusSq = radiusSq

    managed_sound_group__maxRadiusSq = maxRadiusSq

  let typeIdx = get_managed_sound_group_type_index(managed_sound_group__type)
  if typeIdx >= 0
    query() <| $ [es] (var managed_sound_group_processing__list : EidList&)
      managed_sound_group_processing__list[typeIdx] = eid


struct SoundDist
  eid : EntityId
  distSq : float
  posXZ : float2


def get_sector_index(fwd_xz : float2; listener_xz : float2; sound_xz : float2) : int
  let d = sound_xz - listener_xz
  let front = d.x * fwd_xz.x + d.y * fwd_xz.y >= 0.0
  let right = d.x * fwd_xz.y - d.y * fwd_xz.x >= 0.0
  return front ? (right ? 0 : 3) : (right ? 1 : 2)


def managed_sound_group_update(managedSoundsEids : array<EntityId>;
                               managed_sound_group__lodRadiusSq : FloatList;
                               managed_sound_group__lodMaxSounds : IntList;
                               managed_sound_group__maxRadiusSq : float;
                               heroPos : float3;
                               heroFwdXZ : float2;
                               var managed_sound_group__debugCloseLodCount : int&;
                               var managed_sound_group__debugSectorCounts : int4&)

  let numLods = length(managed_sound_group__lodRadiusSq)
  if numLods == 0
    return

  let heroXZ = float2(heroPos.x, heroPos.z)

  var sortedSounds : array<SoundDist>

  for sndEid in managedSoundsEids
    query(sndEid) <| $ [es] (managed_sound__pos : float3;
                             var managed_sound__isStealed : bool&)
      let dSq = length_sq(heroPos - managed_sound__pos)
      if dSq <= managed_sound_group__maxRadiusSq
        sortedSounds |> push(SoundDist(eid = sndEid, distSq = dSq, posXZ = float2(managed_sound__pos.x, managed_sound__pos.z)))
      else
        managed_sound__isStealed = true

  sortedSounds |> sort() <| $(a, b : SoundDist)
    return a.distSq < b.distSq

  var sectorCounts = int4(0, 0, 0, 0)
  var closeLodCount = 0
  var lodNo = 0
  var totalAssigned = 0

  for sd in sortedSounds
    if lodNo < numLods
      var incLod = 0
      if totalAssigned >= managed_sound_group__lodMaxSounds[lodNo]
        incLod = 1
      else
        for curLod in range(lodNo, numLods)
          if sd.distSq > managed_sound_group__lodRadiusSq[curLod]
            incLod++
          else
            break
      lodNo += incLod

    var effectiveLod = lodNo

    if lodNo == FAR_LOD_IDX && lodNo < numLods
      let sector = get_sector_index(heroFwdXZ, heroXZ, sd.posXZ)
      let maxPerSector = managed_sound_group__lodMaxSounds[FAR_LOD_IDX] / 4
      if sectorCounts[sector] >= maxPerSector
        effectiveLod = numLods
      else
        sectorCounts[sector] += 1

    if effectiveLod == lodNo
      totalAssigned++
    let stealed = effectiveLod >= numLods
    query(sd.eid) <| $ [es] (var managed_sound__isStealed : bool&)
      managed_sound__isStealed = stealed

    if effectiveLod == 0
      closeLodCount++

  managed_sound_group__debugCloseLodCount = closeLodCount
  managed_sound_group__debugSectorCounts = sectorCounts


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def managed_sound_group_processing_update(info : ParallelUpdateFrameDelayed;
                                          managed_sound_group_processing__list : EidList;
                                          var managed_sound_group__updateTimer : float&)
  let dt = info.dt
  managed_sound_group__updateTimer -= dt
  if managed_sound_group__updateTimer > 0.0
    return
  managed_sound_group__updateTimer = UPDATE_INTERVAL + gfrnd() * UPDATE_INTERVAL

  let cnt = length(managed_sound_group_processing__list)
  if cnt == 0
    return

  var heroPos : float3
  var heroFwdXZ : float2
  var heroTeam : int
  get_watched_hero_info(heroPos, heroFwdXZ, heroTeam)

  var managedSoundsEids : array<array<EntityId>>
  managedSoundsEids |> resize(cnt)

  let friendlyStepsIdx = int(ManagedSoundGroupType.MSND_HUMAN_STEPS)
  let enemyStepsIdx = int(ManagedSoundGroupType.MSND_HUMAN_STEPS_ENEMY)
  let friendlyGunIdx = int(ManagedSoundGroupType.MSND_HUMAN_GUN)
  let enemyGunIdx = int(ManagedSoundGroupType.MSND_HUMAN_GUN_ENEMY)

  query() <| $ [es(REQUIRE=humanSteps, REQUIRE_NOT=(deadEntity, shootingRangeDummy, watchedHero))] (eid : EntityId;
                                                                                                    team : int)
    let friendly = (team == heroTeam && team != -1 && heroTeam != -1)
    let idx = friendly ? friendlyStepsIdx : enemyStepsIdx
    managedSoundsEids[idx] |> push(eid)

  query() <| $ [es(REQUIRE=humanGun, REQUIRE_NOT=(deadEntity, shootingRangeDummy))] (eid : EntityId;
                                                                                     gun__owner : EntityId;
                                                                                     var managed_sound__isStealed : bool&;
                                                                                     var managed_sound__pos : float3&;
                                                                                     managed_sound_human_gun__team : int)
    var isAimingAtListener = false
    var isVisibleToListener = false
    if !filter_human_gun(eid, gun__owner, heroPos, managed_sound__pos, isAimingAtListener, isVisibleToListener)
      return
    if isAimingAtListener || isVisibleToListener
      managed_sound__isStealed = false
      return

    let friendly = (managed_sound_human_gun__team == heroTeam && managed_sound_human_gun__team != -1 && heroTeam != -1)
    let idx = friendly ? friendlyGunIdx : enemyGunIdx
    managedSoundsEids[idx] |> push(eid)

  for i in range(0, cnt)
    let groupEid = managed_sound_group_processing__list[i]
    if groupEid == INVALID_ENTITY_ID
      continue
    query(groupEid) <| $ [es] (managed_sound_group__lodRadiusSq : FloatList;
                               managed_sound_group__lodMaxSounds : IntList;
                               managed_sound_group__maxRadiusSq : float;
                               var managed_sound_group__debugCloseLodCount : int&;
                               var managed_sound_group__debugSectorCounts : int4&)
      managed_sound_group_update(managedSoundsEids[i],
                                 managed_sound_group__lodRadiusSq,
                                 managed_sound_group__lodMaxSounds,
                                 managed_sound_group__maxRadiusSq,
                                 heroPos, heroFwdXZ,
                                 managed_sound_group__debugCloseLodCount,
                                 managed_sound_group__debugSectorCounts)


[es(tag=sound, on_appear, REQUIRE=humanGun)]
def managed_sound_human_gun_on_appear(evt : Event;
                                      gun__owner : EntityId;
                                      var managed_sound_human_gun__team : int&)
  query(gun__owner) <| $ [es] (team : int)
    managed_sound_human_gun__team = team


[es(tag=sound, on_appear, track=(team, human_weap__gunEids))]
def propagate_team_to_human_guns(evt : Event;
                                 team : int;
                                 human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    if gunEid != INVALID_ENTITY_ID
      query(gunEid) <| $ [es(REQUIRE=humanGun)] (var managed_sound_human_gun__team : int&)
        managed_sound_human_gun__team = team
