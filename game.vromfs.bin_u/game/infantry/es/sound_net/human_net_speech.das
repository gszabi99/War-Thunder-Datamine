require ecs
require ecs.safe
require app
require net
require human_net_speech.modules.human_net_speech_events
require human_net_speech.modules.human_net_speech_common
require sound_utils_net.modules.sound_desc_common
require %game.utils.net_utils
require math.base
require DagorRandom
require DagorSystem

require %appGame.wt_events
require %appGame.infantry.es.team_common


def check_range_and_cooldown(phrase_idx : int;
                             cur_eid : EntityId;
                             cur_pos : float3;
                             cur_team : int;
                             team_range : float;
                             cur_time : float;
                             var speech_next_time : float)

  if team_range > 0.
    if cur_team == TEAM_UNASSIGNED
      return false

    var isAlone : bool = true
    query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId; team : int; transform : float3x4; human_net_speech__lastNextTime : Point2List)
      if eid != cur_eid && team == cur_team && distance_sq(cur_pos, transform[3]) < square(team_range)
        speech_next_time = max(get_speech_next_time(phrase_idx, human_net_speech__lastNextTime), speech_next_time)
        isAlone = false

    if isAlone
      return false 

  if cur_time < speech_next_time
    return false 

  return true


def take_a_chance(chance : int)
  return chance >= rnd_int(0, 100)


def start_net_speech(phrase_idx : int;
                     cur_time : float;
                     eid : EntityId;
                     human_speech__speeches : Array;
                     var human_net_speech__lastNextTime : Point2List&;
                     team : int;
                     transform : float3x4;
                     is_downed : bool) : Object const?

  let desc = get_desc(phrase_idx, human_speech__speeches)
  if desc == null
    return null
  if is_downed && !((*desc).speakIfDowned ?? false)
    return null
  if !take_a_chance((*desc).chance ?? 100)
    return null
  if should_skip_after_another_speech(*desc, human_speech__speeches, human_net_speech__lastNextTime, cur_time)
    return null
  if !check_range_and_cooldown(phrase_idx,
                               eid,
                               transform[3],
                               team,
                               (*desc).teamRange ?? 0.,
                               cur_time,
                               get_speech_next_time(phrase_idx, human_net_speech__lastNextTime))
    return null
  let minMaxCooldown = (*desc).minMaxCooldown ?? float2(0., 0.)
  set_speech_time(phrase_idx, cur_time, cur_time + rnd_float(minMaxCooldown.x, minMaxCooldown.y), human_net_speech__lastNextTime)
  return desc


[es(tag=server, REQUIRE_NOT=(deadEntity, humanSpeechDisable))]
def human_net_speech_request(evt : CmdRequestHumanSpeech;
                             eid : EntityId;
                             @shared_comp human_speech__speeches : Array;
                             var human_net_speech__lastNextTime : Point2List&;
                             human_net_speech__defaultRcptFRange : float;
                             human_net_speech__defaultRcptFRangeEnemy : float;
                             transform : float3x4;
                             isDowned : bool;
                             team : int = TEAM_UNASSIGNED)

  let curTime = get_sync_time()
  let phraseIdx = find_desc_idx(evt.phrase, human_speech__speeches)
  let desc = start_net_speech(int(phraseIdx), curTime, eid, human_speech__speeches, human_net_speech__lastNextTime, team, transform, isDowned)
  if desc == null
    return

  let rcptFilter = get_string(*desc, "rcptFilter", "posRange")
  if !!evt.listener
    if !empty(rcptFilter)
      logerr("unexpected rcptFilter for phrase '{evt.phrase}'")
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_conn(evt.listener))
  elif rcptFilter == "team"
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_team(eid))
  elif rcptFilter == "squad"
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_squad(eid))
  elif rcptFilter == "posRangeTeam"
    let maxRange = get_float(*desc, "range") ?? human_net_speech__defaultRcptFRange
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), enum_connections_near_entity(eid, maxRange, get_target_entity_team(eid), INVALID_ENTITY_ID, evt.exceptPossessed))
  elif rcptFilter == "posRangeSquad"
    let maxRange = get_float(*desc, "range") ?? human_net_speech__defaultRcptFRange
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), enum_connections_near_entity(eid, maxRange, TEAM_UNASSIGNED, get_target_entity_squad(eid), evt.exceptPossessed))
  elif rcptFilter == "player"
    query(eid) <| $ [es] (possessedByPlr : EntityId)
      if !has(possessedByPlr, "playerIsBot")
        send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_conn(eid))
  elif rcptFilter == "vehicle"
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_vehicle(eid))
  elif rcptFilter == "posRange"
    let maxRange = get_float(*desc, "range") ?? human_net_speech__defaultRcptFRange
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), enum_connections_near_entity(eid, maxRange, TEAM_UNASSIGNED, INVALID_ENTITY_ID, evt.exceptPossessed))
  elif rcptFilter == "posRangeFriendlyEnemy"
    let maxRange = get_float(*desc, "range") ?? human_net_speech__defaultRcptFRange
    let maxRangeEnemy = get_float(*desc, "rangeEnemy") ?? human_net_speech__defaultRcptFRangeEnemy
    send_net_event(eid, CmdNetHumanSpeech(phraseIdx = phraseIdx, time = curTime), target_entity_pos_range_friendly_enemy(eid, maxRange, maxRangeEnemy))
  else
    logerr("unknown rcptFilter '{rcptFilter}' for phrase '{evt.phrase}'")
