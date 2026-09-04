from "%rGui/globals/ui_library.nut" import *
from "%rGui/weapons/bulletsPenetrationGraphState.nut" import bulletsPenetrationGraphParams
from "%rGui/weapons/bulletsGraphComp.nut" import mkBulletsArmorPiercingGraph, graphGridColor, graphGridLineThickness, mkGraphLine

const REDUCED_MARK_COUNT_X = 20
let LEGEND_HEIGHT = fpx(30)
let LEGEND_PADDING_X = fpx(10)
let LEGEND_GAP = fpx(8)

let mkAngleText = @(text, color = null) {
  rendObj = ROBJ_TEXT
  text
  color = color ?? 0xFFB0B0B0
}

function mkAngleLegend(graphParams) {
  let children = [mkAngleText($"{loc("bullet_properties/hitAngle")}{loc("ui/colon")}", graphGridColor)]
  foreach (series in graphParams) {
    let angleText = $"{series.angle}{loc("measureUnits/deg")}"
    children.append(mkAngleText(angleText, series.graphColor))
  }
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = LEGEND_GAP
    size = [FLEX, LEGEND_HEIGHT]
    children
  }
}

let mkDivider = @() {
  size = [FLEX, graphGridLineThickness]
  children = mkGraphLine([[VECTOR_LINE, 0, 0, 100, 0]], graphGridColor, graphGridLineThickness)
}

let legendBlockHeight = LEGEND_HEIGHT + 2 * LEGEND_PADDING_X

function mkLegendBlock(graphParams) {
  return {
    rendObj = ROBJ_SOLID
    color = 0xCC03070C
    padding = LEGEND_PADDING_X
    size = [FLEX, legendBlockHeight]
    children = mkAngleLegend(graphParams)
  }
}

function graphComp() {
  let { graphParams, graphSize } = bulletsPenetrationGraphParams.get()
  let hasData = graphParams.len() > 0
  let graphAreaHeight = max(graphSize[1] - legendBlockHeight - graphGridLineThickness, 0)
  let graphAreaSize = [graphSize[0], graphAreaHeight]
  let children = !hasData ? null : [
    { size = [FLEX, graphAreaHeight]
      children = mkBulletsArmorPiercingGraph(
        graphParams, graphAreaSize, false, loc("measureUnits/mm"), loc("measureUnits/meters_dist"), REDUCED_MARK_COUNT_X)
    }
    mkDivider()
    mkLegendBlock(graphParams)
  ]
  return {
    watch = bulletsPenetrationGraphParams
    flow = FLOW_VERTICAL
    size = FLEX
    children
  }
}

return graphComp
