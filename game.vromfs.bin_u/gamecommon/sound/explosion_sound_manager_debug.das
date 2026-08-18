options no_aot
require ecs
require DagorDebug3D
require DagorMath
require DagorConsole
require DagorRandom
require math.base
require %game.sound.sound_events
require Sound
require WTCamera


let EXPLOSION_TEST_CONE_HALF_ANGLE = 40.0 * PI / 180.0


[console_cmd(name="snd.debug_explosions", hint="Toggle explosion sound manager debug draw")]
def explosion_sound_manager_debug_toggle()
  query() <| $ [es] (var explosion_sound_manager__debugEnabled : bool&;
                     var explosion_sound_manager__debugPos : Point3List&;
                     var explosion_sound_manager__debugLod : IntList&;
                     var explosion_sound_manager__debugCooldown : FloatList&;
                     var explosion_sound_manager__debugStealed : BoolList&)
    explosion_sound_manager__debugEnabled = !explosion_sound_manager__debugEnabled
    if !explosion_sound_manager__debugEnabled
      clear(explosion_sound_manager__debugPos)
      clear(explosion_sound_manager__debugLod)
      clear(explosion_sound_manager__debugCooldown)
      clear(explosion_sound_manager__debugStealed)
    console_print("snd.debug_explosions {explosion_sound_manager__debugEnabled ? "ON" : "OFF"}")


def get_camera_dir_angle_xz() : float
  let camDir = get_camera_orig_dir()
  let dirXZ = float2(camDir.x, camDir.z)
  if length_sq(dirXZ) < 1e-6
    return 0.0
  return atan2(dirXZ.x, dirXZ.y)


[console_cmd(name="snd.test_explosion", hint="Play random explosion sound at random pos inside lod, in front of the camera. Usage: snd.test_explosion <lod>")]
def explosion_sound_manager_test_explosion(lod_no : int)
  query() <| $ [es] (explosion_sound_manager__lodRadiusSq : FloatList;
                     explosion_sound_manager__typeNames : StringList)
    let numLods = length(explosion_sound_manager__lodRadiusSq)
    if lod_no < 0 || lod_no >= numLods
      console_print("snd.test_explosion: lod {lod_no} is out of range, lods count is {numLods}")
      return

    let numTypes = length(explosion_sound_manager__typeNames)
    if numTypes == 0
      console_print("snd.test_explosion: explosion sound types are not configured")
      return

    let outerRadius = sqrt(explosion_sound_manager__lodRadiusSq[lod_no])
    let innerRadius = lod_no > 0 ? sqrt(explosion_sound_manager__lodRadiusSq[lod_no - 1]) : 0.0
    let radius = innerRadius + gfrnd() * (outerRadius - innerRadius)
    let angle = get_camera_dir_angle_xz() + (gfrnd() * 2.0 - 1.0) * EXPLOSION_TEST_CONE_HALF_ANGLE
    let pos = get_cached_listener_pos() + float3(sin(angle) * radius, 0.0, cos(angle) * radius)
    let explosionSoundType = string(explosion_sound_manager__typeNames[rnd_int(0, numTypes - 1)])

    broadcastEvent(EventPlayExplosionSound(pos = pos, explosionSoundType = explosionSoundType))
    console_print("snd.test_explosion lod={lod_no} type={explosionSoundType} dist={radius}")


[es(tag=sound, no_order)]
def explosion_sound_manager_debug_draw(evt : UpdateStageInfoRenderDebug;
                                       explosion_sound_manager__debugEnabled : bool;
                                       explosion_sound_manager__debugPos : Point3List;
                                       explosion_sound_manager__debugLod : IntList;
                                       explosion_sound_manager__debugStealed : BoolList)
  if !explosion_sound_manager__debugEnabled
    return

  for i in range(0, length(explosion_sound_manager__debugLod))
    add_debug_text_mark(explosion_sound_manager__debugPos[i],
                        "{explosion_sound_manager__debugLod[i]}", -1, 0.0,
                        explosion_sound_manager__debugStealed[i] ? E3DCOLOR(0xC8FF0000) : E3DCOLOR(0xC800FF00))
