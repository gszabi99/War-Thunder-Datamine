module human_net_speech_request_common shared

require ecs
require human_net_speech.modules.human_net_speech_events


def request_net_speech(eid : EntityId; phrase : string)
  sendEvent(eid, CmdRequestHumanSpeech(phrase = phrase))


def request_net_speech_except_possessed(eid : EntityId; phrase : string; except_possessed : EntityId)
  sendEvent(eid, CmdRequestHumanSpeech(phrase = phrase, listener = INVALID_ENTITY_ID, exceptPossessed = except_possessed))


def request_net_speech_for_specific_listener(speaker : EntityId; phrase : string; listener : EntityId)
  sendEvent(speaker, CmdRequestHumanSpeech(phrase = phrase, listener = listener))
