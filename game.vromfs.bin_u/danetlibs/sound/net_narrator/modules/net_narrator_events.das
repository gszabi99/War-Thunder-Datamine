module net_narrator_events shared
require ecs

[event(broadcast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdNetNarratorAboutTeam 
  team : int
  phrase : string
  replace : bool

[event(broadcast)]
struct CmdNarratorAboutLocalTeam 
  phrase : string
  replace : bool

[event(broadcast)]
struct CmdNarratorAboutTeam 
  team : int
  phrase : string
  replace : bool

[event(broadcast)]
struct CmdNarratorTextEvent
  event : string
  text : string
  myTeamScores : bool
