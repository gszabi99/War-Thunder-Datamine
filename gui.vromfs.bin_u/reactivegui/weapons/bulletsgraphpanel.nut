from "%rGui/globals/ui_library.nut" import *
let { bulletsGraphParams } = require("%rGui/weapons/bulletsGraphState.nut")
let { mkBulletsArmorPiercingGraph, mkBulletsBallisticTrajectoryGraph
} = require("%rGui/weapons/bulletsGraphComp.nut")

function graphComp() {
  let { graphParams, graphSize } = bulletsGraphParams.get()
  let children = graphParams.len() == 0 ? null
    : ("armorPiercing" in graphParams[0]) ? mkBulletsArmorPiercingGraph(graphParams, graphSize)
    : ("ballisticsData" in graphParams[0]) ? mkBulletsBallisticTrajectoryGraph(graphParams, graphSize)
    : null
  return {
    watch = bulletsGraphParams
    size = flex()
    children = children
  }
}

return graphComp
