module net_events shared

require ecs

[cpp_event(broadcast)]
struct EventOnConnectedToServer {}

[event(broadcast)]
struct MatchingRoomExtraParams
  routeEvaluationChance : float

[cpp_event(broadcast, with_scheme)]
struct ChangeServerRoute
  currentIsUnresponsive : bool

[cpp_event(broadcast)]
struct NetEchoReponse
  routeId : uint
  result : int
  rttOrTimeout : uint
