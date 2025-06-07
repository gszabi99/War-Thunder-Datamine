let sharedWatched = require("%globalScripts/sharedWatched.nut")
let { Computed } = require("frp")

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

return {
  watchedHeroSquadMembersRaw
  watchedHeroSquadMembers
  watchedHeroSquadEid
  localPlayerSquadMembers
}