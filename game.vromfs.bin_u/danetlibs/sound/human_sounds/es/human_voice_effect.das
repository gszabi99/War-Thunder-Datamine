require ecs
require ecs.safe
require ecs.common
require app 
require AnimV20
require soundHash
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require human_sounds.modules.human_sounds_events
require human_sounds.modules.human_voice_effect_common
require human_sounds_net.modules.human_sounds_net_events
require human_sounds.modules.human_sound_geomtree_nodes_common

require strings
require DagorSystem


[es(tag=sound, track=is_watched_sound)]
def human_voice_effect_on_watched(evt : Event;
                                  sound_control__state : int = default_sound_control_state();
                                  human_voice_effect__type : string;
                                  is_watched_sound = false;
                                  human_sound_geomtree_nodes__headNodeId = -1;
                                  animchar : AnimcharBaseComponent const?;
                                  @shared_comp human_voice_sound__path : Object;
                                  @shared_comp human_voice_sound__descs : Object;
                                  var human_voice_effect__event : SoundEvent&;
                                  sound_tags : Object;
                                  transform : float3x4)
  if have_sound(sound_control__state) && is_playing(human_voice_effect__event) && !is_oneshot(human_voice_effect__event)
    release(human_voice_effect__event)
    let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
    human_voice_effect__event |> reset(play(human_voice_effect__type, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, pos, false))


def abandon_or_release(var human_voice_effect__event : SoundEvent&; _abandon : bool)
  if _abandon
    abandon(human_voice_effect__event)
  else
    release(human_voice_effect__event)





[es(tag=sound, on_appear, track=(human_voice_effect__activeEffects, sound_control__state))]
def human_voice_effect_on_change(evt : Event;
                                 var human_voice_effect__type : das_string&;
                                 var human_voice_effect__isInited : bool&;
                                 var human_voice_effect__event : SoundEvent&;
                                 var human_voice_effect__isActive : bool&;
                                 human_voice_effect__activeEffects : Object;

                                 @shared_comp human_voice_effect__allOrderedEffects : StringList;
                                 @shared_comp human_voice_sound__path : Object;
                                 @shared_comp human_voice_sound__descs : Object;

                                 sound_control__state : int = default_sound_control_state();
                                 is_watched_sound = false;
                                 human_sound_geomtree_nodes__headNodeId = -1;
                                 animchar : AnimcharBaseComponent const?;

                                 sound_tags : Object;
                                 transform : float3x4)

  let newId = get_top_active_effect(human_voice_effect__activeEffects, human_voice_effect__allOrderedEffects)
  let curId = string(human_voice_effect__type)

  if !have_sound(sound_control__state)
    human_voice_effect__isInited = false
    human_voice_effect__type := newId
    human_voice_effect__isActive = !empty(human_voice_effect__type)
    if is_valid_handle_value(human_voice_effect__event)
      release(human_voice_effect__event)
    return

  if !human_voice_effect__isInited || newId != curId
    human_voice_effect__type := newId

    if is_valid_handle_value(human_voice_effect__event)
      if !keyoff(human_voice_effect__event)
        abandon_or_release(human_voice_effect__event, empty(newId))

    if !empty(newId)
      let newDesc = human_voice_sound__descs[newId] ?as Object
      abandon_or_release(human_voice_effect__event, newDesc?.abandoner != null)
      if newDesc != null
        let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
        human_voice_effect__event |> reset(play_desc(*newDesc, human_voice_sound__path, sound_tags, is_watched_sound, pos, false))

    human_voice_effect__isInited = true

  human_voice_effect__isActive = !empty(human_voice_effect__type) || is_valid_handle_value(human_voice_effect__event)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_effect_update(evt : Event;
                              human_sound_geomtree_nodes__headNodeId = -1;
                              is_watched_sound : bool = false;
                              animchar : AnimcharBaseComponent const?;
                              transform : float3x4;
                              var human_voice_effect__event : SoundEvent&;
                              var human_voice_effect__isActive : bool&;
                              human_voice_effect__type : string)
  if is_valid_handle_value(human_voice_effect__event)
    if is_playing(human_voice_effect__event)
      let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
      set_pos(human_voice_effect__event, pos)
      human_voice_effect__isActive = true
      return
    release(human_voice_effect__event)
  human_voice_effect__isActive = !empty(human_voice_effect__type)





def play_oneshot_effect(phrase : string;
                        ignore_disabled_sound_control : bool;

                        sound_control__state : int;
                        var human_voice_effect__oneshotEvent : SoundEvent&;
                        human_voice_sound__path : Object;
                        human_voice_sound__descs : Object;
                        human_voice_effect__type : string;
                        var human_voice_effect__oneshotType : das_string&;
                        human_speech__isSpeaking : bool;
                        is_watched_sound : bool;
                        human_sound_geomtree_nodes__headNodeId : int;
                        animchar : AnimcharBaseComponent const?;
                        sound_tags : Object;
                        transform : float3x4)

  if human_speech__isSpeaking
    return

  if !ignore_disabled_sound_control && !have_sound(sound_control__state)
    return

  let desc = get_desc(human_voice_sound__descs, phrase)
  if desc == null
    return

  if !empty(human_voice_effect__oneshotType)

    if phrase == human_voice_effect__oneshotType
      return

    if (desc?.replaceAnyOneshot ?as Object) == null && get_desc(*desc, string(human_voice_effect__oneshotType)) == null
      
      return

  if !empty(human_voice_effect__type)
    if (desc?.parallelToAnyEffect ?as Object) == null && get_desc(*desc, human_voice_effect__type) == null
      
      return

  let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
  human_voice_effect__oneshotEvent |> reset(play(phrase, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, pos, false))
  human_voice_effect__oneshotType := phrase
  


[es(tag=sound)]
def human_voice_effect_on_net_cmd(evt : CmdNetHumanVoiceEffect;
                                  sound_control__state : int = default_sound_control_state();
                                  var human_voice_effect__oneshotEvent : SoundEvent&;
                                  @shared_comp human_voice_sound__path : Object;
                                  @shared_comp human_voice_sound__descs : Object;
                                  human_voice_effect__type : string;
                                  var human_voice_effect__oneshotType : das_string&;
                                  human_speech__isSpeaking : bool = false;
                                  is_watched_sound : bool = false;
                                  human_sound_geomtree_nodes__headNodeId = -1;
                                  animchar : AnimcharBaseComponent const?;
                                  sound_tags : Object;
                                  transform : float3x4)
  let maxNetDelay = 3.
  if get_sync_time() < evt.time + maxNetDelay
    play_oneshot_effect(evt.phrase,
                        false,
                        sound_control__state,
                        human_voice_effect__oneshotEvent,
                        human_voice_sound__path,
                        human_voice_sound__descs,
                        human_voice_effect__type,
                        human_voice_effect__oneshotType,
                        human_speech__isSpeaking,
                        is_watched_sound,
                        human_sound_geomtree_nodes__headNodeId,
                        animchar,
                        sound_tags,
                        transform)


[es(tag=sound)]
def human_voice_effect_on_cmd(evt : CmdHumanVoiceEffect;
                              sound_control__state : int = default_sound_control_state();
                              var human_voice_effect__oneshotEvent : SoundEvent&;
                              @shared_comp human_voice_sound__path : Object;
                              @shared_comp human_voice_sound__descs : Object;
                              human_voice_effect__type : string;
                              var human_voice_effect__oneshotType : das_string&;
                              human_speech__isSpeaking : bool = false;
                              is_watched_sound : bool = false;
                              human_sound_geomtree_nodes__headNodeId = -1;
                              animchar : AnimcharBaseComponent const?;
                              sound_tags : Object;
                              transform : float3x4)
  play_oneshot_effect(evt.phrase,
                      evt.ignoreDisabledSoundControl,
                      sound_control__state,
                      human_voice_effect__oneshotEvent,
                      human_voice_sound__path,
                      human_voice_sound__descs,
                      human_voice_effect__type,
                      human_voice_effect__oneshotType,
                      human_speech__isSpeaking,
                      is_watched_sound,
                      human_sound_geomtree_nodes__headNodeId,
                      animchar,
                      sound_tags,
                      transform)
  if !empty(evt.varName)
    set_var(human_voice_effect__oneshotEvent, evt.varName, evt.varValue)



[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_effect_oneshot_update(evt : Event;
                                      human_sound_geomtree_nodes__headNodeId = -1;
                                      is_watched_sound : bool = false;
                                      animchar : AnimcharBaseComponent const?;
                                      transform : float3x4;
                                      var human_voice_effect__oneshotEvent : SoundEvent&;
                                      var human_voice_effect__oneshotType : das_string&)

  if is_valid_handle_value(human_voice_effect__oneshotEvent)
    if is_playing(human_voice_effect__oneshotEvent)
      let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
      set_pos(human_voice_effect__oneshotEvent, pos)
      return
    release(human_voice_effect__oneshotEvent)
  human_voice_effect__oneshotType := ""



[es(tag=sound, track=is_watched_sound, REQUIRE=is_watched_sound)]
def human_voice_effect_oneshot_on_watched(evt : Event;
                                          var human_voice_effect__oneshotEvent : SoundEvent&;
                                          var human_voice_effect__oneshotType : das_string&)
  release(human_voice_effect__oneshotEvent)
  human_voice_effect__oneshotType := ""



[es(tag=sound, track=human_voice_effect__activeEffects, REQUIRE=human_voice_effect__activeEffects, after=human_voice_effect_on_change)]
def human_voice_effect_oneshot_track_active(evt : Event;
                                            human_voice_effect__type : string;
                                            @shared_comp human_voice_sound__descs : Object;
                                            var human_voice_effect__oneshotEvent : SoundEvent&;
                                            var human_voice_effect__oneshotType : das_string&)
  if !empty(human_voice_effect__type)

    let desc = get_desc(human_voice_sound__descs, string(human_voice_effect__oneshotType))
    if desc != null

      if (desc?.parallelToAnyEffect ?as Object) == null && get_desc(*desc, human_voice_effect__type) == null
        

        release(human_voice_effect__oneshotEvent)
        human_voice_effect__oneshotType := ""
