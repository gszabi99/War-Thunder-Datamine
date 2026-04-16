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

let UPDATE_INTERVAL = 0.05


[es(tag=sound, on_appear)]
def managed_sound_group_init(evt : Event;
                             managed_sound_group__type : string;
                             var managed_sound_group__lodRadiusSq : FloatList&;
                             var managed_sound_group__lodMaxSounds : IntList&;
                             var managed_sound_group__maxRadiusSq : float&;
                             var managed_sound_group__updateTimer : float&)

  managed_sound_group__updateTimer = UPDATE_INTERVAL + gfrnd() * UPDATE_INTERVAL

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


struct SoundDist
  eid : EntityId
  distSq : float
  posXZ : float2


def get_sector_index(fwd_xz : float2; listener_xz : float2; sound_xz : float2) : int
  let d = sound_xz - listener_xz
  let front = d.x * fwd_xz.x + d.y * fwd_xz.y >= 0.0
  let right = d.x * fwd_xz.y - d.y * fwd_xz.x >= 0.0
  return front ? (right ? 0 : 3) : (right ? 1 : 2)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def managed_sound_group_update(info : ParallelUpdateFrameDelayed;
                               managed_sound_group__lodRadiusSq : FloatList;
                               managed_sound_group__lodMaxSounds : IntList;
                               managed_sound_group__maxRadiusSq : float;
                               managed_sound_group__isEnemy : bool;
                               var managed_sound_group__updateTimer : float&;
                               var managed_sound_group__debugCloseLodCount : int&;
                               var managed_sound_group__debugSectorCounts : int4&)

  let dt = info.dt
  managed_sound_group__updateTimer -= dt
  if managed_sound_group__updateTimer > 0.0
    return
  managed_sound_group__updateTimer = UPDATE_INTERVAL + gfrnd() * UPDATE_INTERVAL

  let numLods = length(managed_sound_group__lodRadiusSq)
  if numLods == 0
    return

  var heroPos : float3
  var heroFwdXZ : float2
  var heroTeam : int
  get_watched_hero_info(heroPos, heroFwdXZ, heroTeam)

  let heroXZ = float2(heroPos.x, heroPos.z)

  var sortedSounds : array<SoundDist>

  query() <| $ [es(REQUIRE=humanSteps, REQUIRE_NOT=(deadEntity, shootingRangeDummy, watchedHero))] (eid : EntityId;
                                                                                                    managed_sound__pos : float3;
                                                                                                    var managed_sound__isStealed : bool&;
                                                                                                    team : int)
    let friendly = (team == heroTeam && team != -1 && heroTeam != -1)
    if managed_sound_group__isEnemy == friendly
      return
    let dSq = length_sq(heroPos - managed_sound__pos)
    if dSq <= managed_sound_group__maxRadiusSq
      sortedSounds |> push(SoundDist(eid = eid, distSq = dSq, posXZ = float2(managed_sound__pos.x, managed_sound__pos.z)))
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
