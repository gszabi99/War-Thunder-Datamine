module human_net_speech_events shared
require ecs


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)] 
struct CmdNetHumanSpeech
  phraseIdx : int
  time : float

[cpp_event(unicast)] 
struct CmdRequestHumanSpeech
  phrase : string
  listener : EntityId
  exceptPossessed : EntityId

[cpp_event(unicast)] 
struct CmdRequestHumanSpeechAbout
  phrase : string
  aboutEid : EntityId

[event(unicast)] 
struct CmdClientHumanSpeech
  phrase : string

[event(unicast)] 
struct EventOnHumanSpeak {}
