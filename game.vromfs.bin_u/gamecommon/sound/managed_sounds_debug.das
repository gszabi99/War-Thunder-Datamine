options no_aot
require ecs
require DagorDebug3D
require DagorMath
require DagorConsole
require math.base
require strings
require Sound
require soundEvent
require %game.sound.managed_sounds_common


[console_cmd(name="managed_snd.debug", hint="Toggle managed sound debug for a group. Usage: managed_snd.debug <type> or managed_snd.debug to disable")]
def managed_snd_debug_toggle(snd_type : string = "")
  query() <| $ [es] (managed_sound_group__type : string;
                     var managed_sound_group__debugEnabled : bool&)
    let enable = snd_type != "" && managed_sound_group__type == snd_type
    if managed_sound_group__debugEnabled != enable
      managed_sound_group__debugEnabled = enable
      console_print("managed_snd debug '{managed_sound_group__type}' {enable ? "ON" : "OFF"}")


[es(tag=sound, no_order)]
def managed_sound_group_debug_draw(evt : UpdateStageInfoRenderDebug;
                                   managed_sound_group__debugEnabled : bool;
                                   managed_sound_group__debugCloseLodCount : int;
                                   managed_sound_group__debugSectorCounts : int4;
                                   managed_sound_group__lodRadiusSq : FloatList;
                                   managed_sound_group__type : string;
                                   managed_sound_group__isEnemy : bool)
  if !managed_sound_group__debugEnabled
    return

  let numLods = length(managed_sound_group__lodRadiusSq)
  if numLods == 0
    return

  var heroPos : float3
  var heroFwdXZ : float2
  var heroTeam : int
  get_watched_hero_info(heroPos, heroFwdXZ, heroTeam)


  begin_draw_cached_debug_lines(false, false, false)
  let fwdEnd = heroPos + float3(heroFwdXZ.x, 0.0, heroFwdXZ.y) * 3.0
  draw_cached_debug_line(heroPos, fwdEnd, E3DCOLOR(0xFF00FF00))
  end_draw_cached_debug_lines()

  let closeRadius = sqrt(managed_sound_group__lodRadiusSq[0])
  let posCenter = heroPos + float3(heroFwdXZ.x, 0., heroFwdXZ.y) * 0.2
  add_debug_text_mark(posCenter, "{managed_sound_group__type} [{managed_sound_group__debugCloseLodCount}] r={closeRadius}", -1, 0.0, E3DCOLOR(0xC800FF00))

  if numLods <= FAR_LOD_IDX
    return

  let farRadius = sqrt(managed_sound_group__lodRadiusSq[FAR_LOD_IDX])
  let rightXZ = float2(heroFwdXZ.y, -heroFwdXZ.x)

  

  var sectorDirsXZ : float2[4]
  sectorDirsXZ[0] = heroFwdXZ + rightXZ
  sectorDirsXZ[1] = -heroFwdXZ + rightXZ
  sectorDirsXZ[2] = -heroFwdXZ - rightXZ
  sectorDirsXZ[3] = heroFwdXZ - rightXZ
  var sectorNames : string[4]
  sectorNames[0] = "FR"
  sectorNames[1] = "BR"
  sectorNames[2] = "BL"
  sectorNames[3] = "FL"


  for i in range(0, 4)
    let dir = sectorDirsXZ[i]
    let markPos = heroPos + float3(dir.x, 0.0, dir.y)
    add_debug_text_mark(markPos, "{sectorNames[i]}[{managed_sound_group__debugSectorCounts[i]}] r={farRadius}", -1, 0.0, E3DCOLOR(0xC8FFFF00))

  let isEnemy = managed_sound_group__isEnemy
  let closeRadiusSq = managed_sound_group__lodRadiusSq[0]
  let typeIdx = get_managed_sound_group_type_index(managed_sound_group__type)

  if typeIdx == int(ManagedSoundGroupType.MSND_HUMAN_STEPS) || typeIdx == int(ManagedSoundGroupType.MSND_HUMAN_STEPS_ENEMY)
    query() <| $ [es(REQUIRE=humanSteps, REQUIRE_NOT=(deadEntity, shootingRangeDummy, watchedHero))] (managed_sound__pos : float3;
                                                                                                      managed_sound__isStealed : bool;
                                                                                                      human_step_sound_grains__event : SoundEvent;
                                                                                                      team : int)
      let friendly = (team == heroTeam && team != -1 && heroTeam != -1)
      if isEnemy == friendly
        return
      let pos = managed_sound__pos + float3(0., 2., 0.)
      let dist = length(managed_sound__pos - heroPos)
      let distSq = dist * dist
      let sndState = is_playing(human_step_sound_grains__event) ? "snd" : "mute"
      let color = managed_sound__isStealed ? E3DCOLOR(0xC8FF0000) : (distSq <= closeRadiusSq ? E3DCOLOR(0xC800FF00) : E3DCOLOR(0xC8FFFF00))
      add_debug_text_mark(pos, "           {sndState} d={roundi(dist)}", -1, 0.0, color)

  if typeIdx == int(ManagedSoundGroupType.MSND_HUMAN_GUN) || typeIdx == int(ManagedSoundGroupType.MSND_HUMAN_GUN_ENEMY)
    query() <| $ [es(REQUIRE=humanGun, REQUIRE_NOT=(deadEntity, shootingRangeDummy))] (eid : EntityId;
                                                                                       managed_sound__isStealed : bool;
                                                                                       gun_sound__event : SoundEvent;
                                                                                       gun__owner : EntityId;
                                                                                       managed_sound_human_gun__team : int)
      var isAimingAtListener = false
      var isVisibleToListener = false
      var managedSoundPos = float3(0, 0, 0);
      if !filter_human_gun(eid, gun__owner, heroPos, managedSoundPos, isAimingAtListener, isVisibleToListener)
        return
      let friendly = (managed_sound_human_gun__team == heroTeam && managed_sound_human_gun__team != -1 && heroTeam != -1)
      if isEnemy == friendly
        return

      let pos = managedSoundPos + float3(0., 1.8, 0.)
      let dist = length(managedSoundPos - heroPos)
      let distSq = dist * dist
      let sndState = is_playing(gun_sound__event) ? "snd" : "mute"
      var color = E3DCOLOR(0xC8FFFF00)         
      if isVisibleToListener
        color = E3DCOLOR(0xC80000FF)           
      elif isAimingAtListener
        color = E3DCOLOR(0xC800BFFF)           
      elif managed_sound__isStealed
        color = E3DCOLOR(0xC8FF0000)           
      elif distSq <= closeRadiusSq
        color = E3DCOLOR(0xC800FF00)           
      add_debug_text_mark(pos, "{sndState} d={roundi(dist)}", -1, 0.0, color)
