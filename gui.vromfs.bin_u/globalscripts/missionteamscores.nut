from "%sqstd/ecs.nut" import TYPE_INT
from "ecs.computed" import mkEcsComputed

let mkTeamValue = @(comp) mkEcsComputed({ comps = [[comp, TYPE_INT]], defVal = 0 })

return freeze({
  scoreTeamA = mkTeamValue("mission_score__scoreTeamA")
  scoreTeamB = mkTeamValue("mission_score__scoreTeamB")
  ticketsTeamA = mkTeamValue("mission_score__ticketsTeamA")
  ticketsTeamB = mkTeamValue("mission_score__ticketsTeamB")
})
