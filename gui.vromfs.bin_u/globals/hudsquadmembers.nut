import "%globalScripts/sharedWatched.nut" as sharedWatched
import "%sqstd/ecs.nut" as ecs
from "frp" import Computed

let watchedHeroSquadMembersRaw = sharedWatched("watchedHeroSquadMembersRaw", @() {
  watchedHeroSquadEid = 0
  controlledSquadEid = 0
  members = {}
})


let watchedHeroSquadEid = Computed(@() watchedHeroSquadMembersRaw.get().watchedHeroSquadEid)

let sortMembers = @(a,b) a.memberIdx <=> b.memberIdx

let watchedHeroSquadMembers = Computed(@()
  watchedHeroSquadMembersRaw.get().members.values().sort(sortMembers))


let localPlayerSquadMembers = Computed(@() 

 watchedHeroSquadMembers.get())

let hudSquadBlockCollapsed = sharedWatched("hudSquadBlockCollapsed", @() false)

let localPlayerHumanContext = sharedWatched("localPlayerHumanContext", @() {
  hasGroundVehicleAttackerAndTarget = false
  hasAirVehicleAttackerAndTarget = false
})

let selectedBotForOrderEid = sharedWatched("selectedBotForOrderEid", @() ecs.INVALID_ENTITY_ID)
let selectedBotForOrder = Computed(@()
  watchedHeroSquadMembersRaw.get().members?[selectedBotForOrderEid.get()])

let watchedHeroSquadMembersAliveCount = Computed(@()
  watchedHeroSquadMembers.get().reduce(@(acc, member) (member.isAlive ? acc + 1 : acc), 0))

return freeze({
  watchedHeroSquadMembersRaw
  watchedHeroSquadMembers
  watchedHeroSquadEid
  localPlayerSquadMembers
  hudSquadBlockCollapsed
  localPlayerHumanContext
  selectedBotForOrderEid
  selectedBotForOrder
  watchedHeroSquadMembersAliveCount
})