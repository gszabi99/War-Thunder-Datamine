module input_events shared
require ecs

[cpp_event(broadcast)]
struct EventOnKeyDown
  eventId : int
  dt : float

[cpp_event(broadcast)]
struct EventOnKeyUp
  eventId : int
  dt : float

[cpp_event(broadcast)]
struct EventOnShortcutEnable
  shortcut : string
  enable : bool

[cpp_event(broadcast)]
struct EventOnAllShortcutsEnable
  enable : bool

[cpp_event(broadcast)]
struct EventOnAxisEnable
  axis : string
  enable : bool

[cpp_event(broadcast)]
struct UpdateStageUpdateInput
  curTime : float
  dt : float
