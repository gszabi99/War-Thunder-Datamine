from "%rGui/globals/ui_library.nut" import *
let { bulletsGraphParams } = require("%rGui/weapons/bulletsGraphState.nut")
let { mkBulletsArmorPiercingGraph, mkBulletsBallisticTrajectoryGraph,
  mkMissileTelemetryDistanceGraph, mkMissileTelemetrySpeedGraph,
  mkMissileTrajectoryGraph
} = require("%rGui/weapons/bulletsGraphComp.nut")

let mkCompByGraphId = {
  bulletPenetration            = mkBulletsArmorPiercingGraph
  bulletBallistics             = mkBulletsBallisticTrajectoryGraph
  missileTrajectory            = mkMissileTrajectoryGraph
  missileTelemetryDistance     = mkMissileTelemetryDistanceGraph
  missileTelemetrySpeed        = mkMissileTelemetrySpeedGraph
}

function graphComp() {
  let { graphParams, graphSize, graphId } = bulletsGraphParams.get()
  let children = graphParams.len() == 0 ? null
    : mkCompByGraphId?[graphId](graphParams, graphSize)
  return {
    watch = bulletsGraphParams
    size = flex()
    children = children
  }
}

return graphComp
