require ecs
require soundEvent
require DagorDataBlock
require DagorMath
require DagorSystem
require math.base
require strings
require app
require %game.events
require %game.sound.sound_events
require Sound
require DagorConsole


let EXPLOSION_SOUND_COOLDOWN = 0.7
let EXPLOSION_SOUND_SECTORS = 4
let EXPLOSION_SOUND_RESERVE = 32


def get_explosion_sector_index(listener_pos : float3; sound_pos : float3) : int
  let east = sound_pos.x >= listener_pos.x
  let north = sound_pos.z >= listener_pos.z
  return (east ? 1 : 0) + (north ? 2 : 0)


[es(tag=sound, on_appear)]
def explosion_sound_manager_init(evt : Event;
                                 var explosion_sound_manager__lodRadiusSq : FloatList&;
                                 var explosion_sound_manager__lodMaxPerSector : IntList&;
                                 var explosion_sound_manager__maxRadiusSq : float&;
                                 var explosion_sound_manager__slotCount : IntList&;
                                 var explosion_sound_manager__soundSlot : IntList&;
                                 var explosion_sound_manager__soundCooldown : FloatList&;
                                 var explosion_sound_manager__typeNames : StringList&;
                                 var explosion_sound_manager__eventNames : StringList&;
                                 var explosion_sound_manager__debugPos : Point3List&;
                                 var explosion_sound_manager__debugLod : IntList&;
                                 var explosion_sound_manager__debugCooldown : FloatList&;
                                 var explosion_sound_manager__debugStealed : BoolList&)
  explosion_sound_manager__maxRadiusSq = 0.0

  explosion_sound_manager__soundSlot |> reserve(EXPLOSION_SOUND_RESERVE)
  explosion_sound_manager__soundCooldown |> reserve(EXPLOSION_SOUND_RESERVE)
  explosion_sound_manager__debugPos |> reserve(EXPLOSION_SOUND_RESERVE)
  explosion_sound_manager__debugLod |> reserve(EXPLOSION_SOUND_RESERVE)
  explosion_sound_manager__debugCooldown |> reserve(EXPLOSION_SOUND_RESERVE)
  explosion_sound_manager__debugStealed |> reserve(EXPLOSION_SOUND_RESERVE)

  datablock_load_cached("config/sound_studio.blk") <| $(sndBlk : DataBlock)
    let managerBlk = sndBlk |> datablock_get_block_by_name("explosion_sounds")
    if managerBlk == null
      logerr("explosion_sound_manager_init: 'explosion_sounds' block not found in sound_studio.blk")
      return

    let lodsBlk = *managerBlk |> datablock_get_block_by_name("lods")
    if lodsBlk == null
      logerr("explosion_sound_manager_init: 'lods' block not found in 'explosion_sounds'")
      return

    var maxRadiusSq = 0.0
    for blk_i in 0u..lodsBlk.blockCount
      let lodBlk = *lodsBlk |> datablock_get_block(blk_i)
      if lodBlk == null
        continue
      let radius = *lodBlk |> datablock_getReal("radius", 0.0)
      let maxSounds = *lodBlk |> datablock_getInt("maxSounds", 0)
      let radiusSq = radius * radius
      push(explosion_sound_manager__lodRadiusSq, radiusSq)
      push(explosion_sound_manager__lodMaxPerSector,
           max(1, (maxSounds + EXPLOSION_SOUND_SECTORS - 1) / EXPLOSION_SOUND_SECTORS))
      if radiusSq > maxRadiusSq
        maxRadiusSq = radiusSq

    explosion_sound_manager__maxRadiusSq = maxRadiusSq
    explosion_sound_manager__slotCount |> resize(length(explosion_sound_manager__lodRadiusSq) * EXPLOSION_SOUND_SECTORS)

    let explosionsBlk = sndBlk |> datablock_get_block_by_name("explosions")
    if explosionsBlk == null
      logerr("explosion_sound_manager_init: 'explosions' block not found in sound_studio.blk")
      return

    let infantryPath = *explosionsBlk |> datablock_getStr("infantryPath", "")

    for param_i in 0u..explosionsBlk.paramCount
      let eventName = *explosionsBlk |> datablock_getStr(int(param_i))
      if eventName == ""
        continue
      var fullName = ""
    
    
    
      fullName = "{infantryPath}/{eventName}"
      if fullName == ""
        continue
      explosion_sound_manager__typeNames |> push(string(*explosionsBlk |> datablock_getParamName(param_i)))
      explosion_sound_manager__eventNames |> push(fullName)


[es(tag=sound, on_appear)]
def explosion_sound_on_effect_appear(evt : Event;
                                     explosion_sound_type : string;
                                     transform : float3x4)
  if explosion_sound_type == ""
    return

  broadcastEvent(EventPlayExplosionSound(pos = transform[3], explosionSoundType = explosion_sound_type))


[es(tag=sound)]
def explosion_sound_manager_play(evt : EventPlayExplosionSound;
                                 explosion_sound_manager__lodRadiusSq : FloatList;
                                 explosion_sound_manager__lodMaxPerSector : IntList;
                                 explosion_sound_manager__maxRadiusSq : float;
                                 explosion_sound_manager__typeNames : StringList;
                                 explosion_sound_manager__eventNames : StringList;
                                 explosion_sound_manager__debugEnabled : bool;
                                 var explosion_sound_manager__slotCount : IntList&;
                                 var explosion_sound_manager__soundSlot : IntList&;
                                 var explosion_sound_manager__soundCooldown : FloatList&;
                                 var explosion_sound_manager__debugPos : Point3List&;
                                 var explosion_sound_manager__debugLod : IntList&;
                                 var explosion_sound_manager__debugCooldown : FloatList&;
                                 var explosion_sound_manager__debugStealed : BoolList&)
  let numLods = length(explosion_sound_manager__lodRadiusSq)
  if numLods == 0
    return

  let listenerPos = get_cached_listener_pos()
  let distSq = length_sq(evt.pos - listenerPos)
  if distSq > explosion_sound_manager__maxRadiusSq
    return

  var lodNo = -1
  for i in range(0, numLods)
    if distSq <= explosion_sound_manager__lodRadiusSq[i]
      lodNo = i
      break
  if lodNo < 0
    return

  var explosionType = -1
  for i in range(0, length(explosion_sound_manager__typeNames))
    if string(explosion_sound_manager__typeNames[i]) == evt.explosionSoundType
      explosionType = i
      break
  if explosionType < 0
    return

  let sector = get_explosion_sector_index(listenerPos, evt.pos)
  let slot = lodNo * EXPLOSION_SOUND_SECTORS + sector
  if slot < 0 || slot >= length(explosion_sound_manager__slotCount)
    return
  let isStealed = explosion_sound_manager__slotCount[slot] >= explosion_sound_manager__lodMaxPerSector[lodNo]
  if explosion_sound_manager__debugEnabled
    explosion_sound_manager__debugPos |> push(evt.pos)
    explosion_sound_manager__debugLod |> push(lodNo)
    explosion_sound_manager__debugCooldown |> push(EXPLOSION_SOUND_COOLDOWN)
    explosion_sound_manager__debugStealed |> push(isStealed)
  if isStealed
    return

  let delay = get_sound_speed_delay(evt.pos)

  explosion_sound_manager__slotCount[slot] = explosion_sound_manager__slotCount[slot] + 1
  explosion_sound_manager__soundSlot |> push(slot)
  explosion_sound_manager__soundCooldown |> push(EXPLOSION_SOUND_COOLDOWN)

  delayed_oneshot(string(explosion_sound_manager__eventNames[explosionType]), evt.pos, delay)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def explosion_sound_manager_update(info : ParallelUpdateFrameDelayed;
                                   var explosion_sound_manager__slotCount : IntList&;
                                   var explosion_sound_manager__soundSlot : IntList&;
                                   var explosion_sound_manager__soundCooldown : FloatList&;
                                   var explosion_sound_manager__debugPos : Point3List&;
                                   var explosion_sound_manager__debugLod : IntList&;
                                   var explosion_sound_manager__debugCooldown : FloatList&;
                                   var explosion_sound_manager__debugStealed : BoolList&)
  let dt = info.dt
  var count = length(explosion_sound_manager__soundCooldown)
  var i = count
  while --i >= 0
    explosion_sound_manager__soundCooldown[i] -= dt
    if explosion_sound_manager__soundCooldown[i] > 0.0
      continue
    let slot = explosion_sound_manager__soundSlot[i]
    if slot >= 0 && slot < length(explosion_sound_manager__slotCount)
      explosion_sound_manager__slotCount[slot] = max(0, explosion_sound_manager__slotCount[slot] - 1)
    let last = count - 1
    if i != last
      explosion_sound_manager__soundSlot[i] = explosion_sound_manager__soundSlot[last]
      explosion_sound_manager__soundCooldown[i] = explosion_sound_manager__soundCooldown[last]
    explosion_sound_manager__soundSlot |> pop()
    explosion_sound_manager__soundCooldown |> pop()
    count = last

  var debugCount = length(explosion_sound_manager__debugCooldown)
  var debugNo = debugCount
  while --debugNo >= 0
    explosion_sound_manager__debugCooldown[debugNo] -= dt
    if explosion_sound_manager__debugCooldown[debugNo] > 0.0
      continue
    let lastDebug = debugCount - 1
    if debugNo != lastDebug
      explosion_sound_manager__debugPos[debugNo] = explosion_sound_manager__debugPos[lastDebug]
      explosion_sound_manager__debugLod[debugNo] = explosion_sound_manager__debugLod[lastDebug]
      explosion_sound_manager__debugCooldown[debugNo] = explosion_sound_manager__debugCooldown[lastDebug]
      explosion_sound_manager__debugStealed[debugNo] = explosion_sound_manager__debugStealed[lastDebug]
    explosion_sound_manager__debugPos |> pop()
    explosion_sound_manager__debugLod |> pop()
    explosion_sound_manager__debugCooldown |> pop()
    explosion_sound_manager__debugStealed |> pop()
    debugCount = lastDebug
