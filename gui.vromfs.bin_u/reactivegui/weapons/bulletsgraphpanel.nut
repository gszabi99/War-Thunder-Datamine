from "%rGui/weapons/bulletsGraphState.nut" import bulletsGraphParams
from "%rGui/weapons/bulletsGraphComp.nut" import mkBulletsArmorPiercingGraph, mkBulletsBallisticTrajectoryGraph, mkMissileTelemetryDistanceGraph, mkMissileTelemetrySpeedGraph, mkMissileTrajectoryGraph
from "%rGui/globals/ui_library.nut" import *

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
    size = FLEX
    children = children
  }
}

return graphComp
