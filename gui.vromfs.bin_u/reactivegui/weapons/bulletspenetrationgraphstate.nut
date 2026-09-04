from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

let bulletsPenetrationGraphParams = Watched({
  graphParams = []
  graphSize = [0, 0]
})




eventbus_subscribe("update_bullets_penetration_graph_state", function(p) {
  let { graphData = null } = p
  bulletsPenetrationGraphParams.mutate(@(params) params.__update(graphData))
})

return {
  bulletsPenetrationGraphParams
}
