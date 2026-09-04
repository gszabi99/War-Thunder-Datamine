from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

let bulletsGraphParams = Watched({ graphParams = [], graphSize = [0, 0], graphId = "" })
let graphPlayerParams = Watched({ maxPlayTimeMs = 0, curPlayTimeMs = 0, startPlayingTimeMs = 0 })

eventbus_subscribe("update_bullets_graph_state", function(v) {
  let { graphData = null, graphPlayerData = null } = v
  if (graphData != null)
    bulletsGraphParams.set(graphData)
  if (graphPlayerData != null)
    graphPlayerParams.mutate(@(params) params.__update(graphPlayerData))
})

return {
  bulletsGraphParams
  graphPlayerParams
}
