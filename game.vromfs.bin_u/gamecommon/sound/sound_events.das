module sound_events shared
require ecs
require DagorDataBlock

[cpp_event(unicast)]
struct CmdEngineStartSound
{}

[cpp_event(unicast)]
struct CmdEngineStopSound
{}

[cpp_event(unicast)]
struct CmdEnginePlayStartSound
{}

[cpp_event(unicast)]
struct CmdEnginePlayStopSound
{}

[cpp_event(unicast)]
struct CmdEngineStealSound
{}

[cpp_event(unicast)]
struct CmdEngineUnstealSound
{}

[cpp_event(unicast)]
struct CmdEngineReinitSound
  modelBlk : DataBlock?
  forHero : bool