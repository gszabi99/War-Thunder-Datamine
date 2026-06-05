require ecs
require ecs.safe
require ecs.common
require app 
require strings
require AnimV20
require soundEvent
require soundSystem
require math.random
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_desc_common
require human_net_speech.modules.human_net_speech_events
require human_sounds.modules.human_sound_geomtree_nodes_common
require Localization

let private TEAM_UNASSIGNED = -1
let SPEECH_WATCHED_VOLUME = 1.5
let SPEECH_TEAM_VOLUME = 1.5
let SPEECH_MAX_NET_DELAY = 4.
let private LOCALE_SENTINEL = "_"
let private LOCALE_FALLBACK = "en"


def language_to_speech_locale(lang : string; locale_map : Object const) : string
  
  if length(lang) <= 3
    return lang
  return locale_map[lang] ?? LOCALE_FALLBACK

def resolve_speech_locale(human_speech_locale : string; locale_map : Object const) : string
  if human_speech_locale == LOCALE_SENTINEL
    return language_to_speech_locale(get_current_language(), locale_map)
  return human_speech_locale

def is_hero_team(cur_team : int)
  var ret = false
  if cur_team != TEAM_UNASSIGNED
    query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
      ret = cur_team == hero_team
  return ret

def get_phrase(eid : EntityId; phrase_idx : int; speeches : Array; human_voice_effect__isActive : bool) : Object const?
  if !sound_banks_is_master_preset_loaded()
    return null
  if phrase_idx < 0 || phrase_idx >= int(speeches.size)
    return null
  let desc = speeches[phrase_idx] as Object
  if human_voice_effect__isActive
    var allow = false
    let parallelTo = desc?.parallelTo ?as Object
    if parallelTo != null
      if empty(*parallelTo)
        return desc
      query(eid) <| $ [es] (human_voice_effect__type : string = "")
        if !empty(human_voice_effect__type)
          allow = ((*parallelTo)[human_voice_effect__type] ?as Object) != null
    return allow ? desc : null
  return desc

def start_speech(eid : EntityId;
                 phrase_idx : int;
                 human_voice_effect__isActive : bool;
                 human_speech__voices : Array;
                 sound_tags : Object;
                 human_speech__locale : string;
                 human_speech__voiceIdx : int;
                 @shared_comp human_speech__speeches : Array;
                 @shared_comp human_speech__localeMap : Object;
                 is_watched_sound : bool;
                 head_node_id : int;
                 animchar : AnimcharBaseComponent const?;
                 var human_speech__event : SoundEvent&;
                 var human_speech__curPhraseIdx : int&;
                 transform : float3x4;
                 team : int = TEAM_UNASSIGNED;
                 preferred_language : string = "")

  if uint(phrase_idx) >= uint(human_speech__speeches.size)
    return
  let desc = get_phrase(eid, phrase_idx, human_speech__speeches, human_voice_effect__isActive)
  if desc == null
    return
  if !(desc?.replace ?? false) && is_playing(human_speech__event)
    if (desc?.queueable ?? false)
      query(eid) <| $ [es] (var human_speech__queue : int2&; var human_speech__queuedPreferredLanguage : das_string)
        human_speech__queue.y = human_speech__queue.x
        human_speech__queue.x = phrase_idx
        human_speech__queuedPreferredLanguage := preferred_language
    return

  release(human_speech__event)
  human_speech__curPhraseIdx = -1

  let isWatchedSound = is_watched_sound || (desc?.treatAsWatched ?? false)
  let pos = get_human_voice_3d_pos(is_watched_sound, transform, head_node_id, animchar)

  if length(human_speech__voices) > 0 && human_speech__voiceIdx >= 0 && human_speech__voiceIdx < length(human_speech__voices)
    let voiceObj = human_speech__voices[human_speech__voiceIdx] as Object
    if voiceObj != null
      var path = ""
      if get_option_path(*voiceObj, sound_tags, isWatchedSound, path)

        var effectiveLocale = ""
        if !empty(preferred_language)
          effectiveLocale = language_to_speech_locale(preferred_language, human_speech__localeMap)
        if empty(effectiveLocale)
          effectiveLocale = resolve_speech_locale(human_speech__locale, human_speech__localeMap)
        let locPath = empty(effectiveLocale) ? path : "{path}/{effectiveLocale}"

        human_speech__event |> reset(play_desc_path(*desc, locPath, is_watched_sound, pos, false))
        human_speech__curPhraseIdx = phrase_idx

        if isWatchedSound
          set_volume(human_speech__event, SPEECH_WATCHED_VOLUME)
        elif is_hero_team(team)
          set_volume(human_speech__event, SPEECH_TEAM_VOLUME)

        sendEvent(eid, EventOnHumanSpeak())


[es(tag=sound)]
def human_speech_cmd(evt : CmdNetHumanSpeech;
                     eid : EntityId;
                     human_voice_effect__isActive : bool;
                     human_speech__voices : Array;
                     sound_tags : Object;
                     human_speech__locale : string;
                     human_speech__voiceIdx : int;
                     @shared_comp human_speech__speeches : Array;
                     @shared_comp human_speech__localeMap : Object;
                     is_watched_sound : bool;
                     human_sound_geomtree_nodes__headNodeId = -1;
                     animchar : AnimcharBaseComponent const?;
                     var human_speech__event : SoundEvent&;
                     var human_speech__curPhraseIdx : int&;
                     transform : float3x4;
                     team : int = TEAM_UNASSIGNED)
  if get_sync_time() < evt.time + SPEECH_MAX_NET_DELAY
    start_speech(eid,
                 evt.phraseIdx,
                 human_voice_effect__isActive,
                 human_speech__voices,
                 sound_tags,
                 human_speech__locale,
                 human_speech__voiceIdx,
                 human_speech__speeches,
                 human_speech__localeMap,
                 is_watched_sound,
                 human_sound_geomtree_nodes__headNodeId,
                 animchar,
                 human_speech__event,
                 human_speech__curPhraseIdx,
                 transform,
                 team)


[es(tag=sound)]
def human_speech_cmd_hero_speech(evt : CmdClientHumanSpeech;
                                 eid : EntityId;
                                 human_voice_effect__isActive : bool;
                                 human_speech__voices : Array;
                                 sound_tags : Object;
                                 human_speech__locale : string;
                                 human_speech__voiceIdx : int;
                                 @shared_comp human_speech__speeches : Array;
                                 @shared_comp human_speech__localeMap : Object;
                                 is_watched_sound : bool;
                                 human_sound_geomtree_nodes__headNodeId = -1;
                                 animchar : AnimcharBaseComponent const?;
                                 var human_speech__event : SoundEvent&;
                                 var human_speech__curPhraseIdx : int&;
                                 transform : float3x4;
                                 team : int = TEAM_UNASSIGNED)
  let phraseIdx = find_desc_idx(evt.phrase, human_speech__speeches)
  if phraseIdx >= 0
    start_speech(eid,
                 phraseIdx,
                 human_voice_effect__isActive,
                 human_speech__voices,
                 sound_tags,
                 human_speech__locale,
                 human_speech__voiceIdx,
                 human_speech__speeches,
                 human_speech__localeMap,
                 is_watched_sound,
                 human_sound_geomtree_nodes__headNodeId,
                 animchar,
                 human_speech__event,
                 human_speech__curPhraseIdx,
                 transform,
                 team,
                 evt.prefferred_language)
  else
    sound_debug("There is no human speech desc for phrase '{evt.phrase}'")


[es(tag=sound, on_appear, track=(human_voice_effect__isActive, sound_preset__isLoaded), REQUIRE_NOT=humanSpeechDisable)]
def human_speech_can_speak(evt : Event;
                           eid : EntityId;
                           sound_preset__isLoaded : bool;
                           human_voice_effect__isActive : bool = false;
                           @shared_comp human_speech__speeches : Array;
                           var human_speech__queue : int2&;
                           var human_speech__queuedPreferredLanguage : das_string;
                           var human_speech__event : SoundEvent&;
                           var human_speech__curPhraseIdx : int&)
  if get_phrase(eid, human_speech__curPhraseIdx, human_speech__speeches, human_voice_effect__isActive) == null
    release(human_speech__event)
    human_speech__curPhraseIdx = -1
  if !sound_preset__isLoaded
    human_speech__curPhraseIdx = -1
    human_speech__queue = int2(-1, -1)
    human_speech__queuedPreferredLanguage := ""


[es(tag=sound, on_appear)]
def human_speech_init_voice_idx(evt : Event;
                                human_speech__voices : Array;
                                var human_speech__voiceIdx : int&;
                                squad_member__memberIdx : int;
                                squad_member__squad = INVALID_ENTITY_ID;
                                var sound_flags : Object&)
  human_speech__voiceIdx = max(0, squad_member__memberIdx)
  query(squad_member__squad) <| $ [es] (squad__id : int)
    human_speech__voiceIdx += squad__id
  let maxVoices = max(1, length(human_speech__voices))
  human_speech__voiceIdx = max(human_speech__voiceIdx, -human_speech__voiceIdx)
  human_speech__voiceIdx %= maxVoices
  if human_speech__voiceIdx > 0
    raise_sound_tag("voice{human_speech__voiceIdx + 1}", sound_flags)


[es(tag=sound, on_appear, REQUIRE_NOT=squad_member__memberIdx)]
def human_speech_init_voice_idx_no_squad(evt : Event;
                                         eid : EntityId;
                                         human_speech__voices : Array;
                                         var human_speech__voiceIdx : int&;
                                         var sound_flags : Object&)
  let maxVoices = max(1, length(human_speech__voices))
  human_speech__voiceIdx = int(eid_frnd(eid) * float(maxVoices - 1))
  human_speech__voiceIdx = max(human_speech__voiceIdx, -human_speech__voiceIdx)
  human_speech__voiceIdx %= maxVoices
  if human_speech__voiceIdx > 0
    raise_sound_tag("voice{human_speech__voiceIdx + 1}", sound_flags)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_speech_update(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        is_watched_sound : bool;
                        human_sound_geomtree_nodes__headNodeId = -1;
                        animchar : AnimcharBaseComponent const?;
                        var human_speech__event : SoundEvent&;
                        var human_speech__curPhraseIdx : int&;
                        var human_speech__queue : int2&;
                        var human_speech__queuedPreferredLanguage : das_string)

  if is_valid_handle_value(human_speech__event)
    if is_playing(human_speech__event)
      set_pos(human_speech__event, get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar))
      return
    release(human_speech__event)
    human_speech__curPhraseIdx = -1

  if !is_valid_handle_value(human_speech__event)
    let phraseIdx = human_speech__queue.y
    human_speech__queue.y = human_speech__queue.x
    human_speech__queue.x = -1
    let queuedLanguage = string(human_speech__queuedPreferredLanguage)
    if phraseIdx >= 0
      human_speech__queuedPreferredLanguage := ""
      query(eid) <| $ [es] (human_voice_effect__isActive : bool;
                            human_speech__voices : Array;
                            sound_tags : Object;
                            human_speech__locale : string;
                            human_speech__voiceIdx : int;
                            @shared_comp human_speech__speeches : Array;
                            @shared_comp human_speech__localeMap : Object;
                            is_watched_sound : bool;
                            team : int = TEAM_UNASSIGNED)
        start_speech(eid,
                     phraseIdx,
                     human_voice_effect__isActive,
                     human_speech__voices,
                     sound_tags,
                     human_speech__locale,
                     human_speech__voiceIdx,
                     human_speech__speeches,
                     human_speech__localeMap,
                     is_watched_sound,
                     human_sound_geomtree_nodes__headNodeId,
                     animchar,
                     human_speech__event,
                     human_speech__curPhraseIdx,
                     transform,
                     team,
                     queuedLanguage)
