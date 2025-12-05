module human_net_speech_common shared

require ecs
require ecs.safe
require sound_utils_net.modules.sound_desc_common


def get_speech_last_time(idx : int; human_net_speech__lastNextTime : Point2List)
  return idx < length(human_net_speech__lastNextTime) ? human_net_speech__lastNextTime[idx].x : 0.


def get_speech_next_time(idx : int; human_net_speech__lastNextTime : Point2List)
  return idx < length(human_net_speech__lastNextTime) ? human_net_speech__lastNextTime[idx].y : 0.


def set_speech_time(idx : int; last_time : float; next_time : float; var human_net_speech__lastNextTime : Point2List&)
  assert(uint(idx) < 100u)
  while idx >= length(human_net_speech__lastNextTime)
    push(human_net_speech__lastNextTime, float2(-100., 0.))
  human_net_speech__lastNextTime[idx] = float2(last_time, next_time)


def should_skip_after_another_speech(desc : Object; speeches : Array; human_net_speech__lastNextTime : Point2List; cur_time : float)
  let comp = desc["skipAfterSpeech"]
  if comp != null
    for it in *get_ecs_array(*comp)
      let obj = it as Object
      let otherName = get_ecs_string((*obj)["name"])
      if otherName != null
        let otherTime = (*obj).time ?? 10.
        let otherPhraseIdx = find_desc_idx(string(*otherName), speeches)
        if otherPhraseIdx >= 0 && cur_time < get_speech_last_time(otherPhraseIdx, human_net_speech__lastNextTime) + otherTime
          return true
  return false
