options no_aot
require ecs
require ecs.safe
require DagorConsole
require DagorDebug3D
require Sound
require DagorMath
require Dacoll
require PhysMat
require strings
require DagorMath
require ecs.ecs_template
require soundSystem

[ecs_template]
struct debug_reverb_enemy_template
  debugReverbEnemy : bool


[console_cmd(name="snd.debug_reverb_enemy")]
def sound_debug_reverb_console_cmd()
  var entEid = INVALID_ENTITY_ID
  find_query() <| $ [es, unused_argument(wt_enemy_reverb_sound_calculator__distSq)] (eid : EntityId, wt_enemy_reverb_sound_calculator__distSq : float)
    entEid = eid
    return true
  if entEid != INVALID_ENTITY_ID
    if !has(entEid, "debugReverbEnemy")
      addSubTemplate(entEid, "debug_reverb_enemy_template")
      sound_debug("snd.debug_reverb_enemy=1")
    else
      removeSubTemplate(entEid, "debug_reverb_enemy_template")
      sound_debug("snd.debug_reverb_enemy=0")

[es(no_order, tag=sound, on_event=EventSoundDrawDebug, REQUIRE=debugReverbEnemy)]
def wt_enemy_reverb_sound_calculator_debug_draw(evt : Event;
                                                
                                                wt_enemy_reverb_sound_calculator__eids : EidList)
  begin_draw_cached_debug_lines(false, false, false)
  for eid in wt_enemy_reverb_sound_calculator__eids
    query(eid) <| $ [es(REQUIRE_NOT = (deadEntity, watchedByPlr))] (transform : float3x4;
                                                                    
                                                                    
                                                                    wt_enemy_reverb_sound__value : float)
      let begin = transform[3]
      let end = begin + float3(0, 2, 0)
      add_debug_text_mark(end, "{format("%.0f", wt_enemy_reverb_sound__value)}", -1, 0., E3DCOLOR(0xffffffff))

    
    
    
    

  end_draw_cached_debug_lines()
