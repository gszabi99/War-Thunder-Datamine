options no_aot
require ecs
require %appGame.infantry.es.sound_net.squad_member_see_danger_human_net_speech_common
require DagorConsole


[console_cmd(name="snd.squad_member_see_danger_human_net_speech")]
def snd_debug_request_squad_member_see_danger_human_net_speech__console_cmd(danger_pos_x, danger_pos_y, danger_pos_z : float)
  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid, possessedByPlr : EntityId)
    if !possessedByPlr
      on_squad_member_see_danger_human_net_speech(eid, INVALID_ENTITY_ID, float3(danger_pos_x, danger_pos_y, danger_pos_z))
