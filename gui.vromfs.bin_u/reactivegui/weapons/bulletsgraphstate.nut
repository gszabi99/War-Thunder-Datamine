from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")

let bulletsGraphParams = Watched({ graphParams = [], graphSize = [0, 0] })

eventbus_subscribe("update_bullets_graph_state", @(v) bulletsGraphParams.set(v))

return {
  bulletsGraphParams
}
