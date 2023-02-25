//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::WwPathTracker <- class {
  status = ""
  currentPosition = null
  moveType = -1

  path = null
  points = null

  constructor(blk = null) {
    this.update(blk)
  }

  function update(blk = null) {
    if (!blk)
      return

    this.status = blk.status
    this.currentPosition = blk.pos
    this.moveType = blk.moveType

    this.path = blk.getBlockByName("path")
    this.checkPoints(this.path?.points)
  }

  function checkPoints(pointsBlk) {
    this.points = []
    if (!pointsBlk)
      return

    for (local i = 0; i < pointsBlk.blockCount(); i++)
      this.points.append(::u.copy(pointsBlk.getBlock(i)))
  }

  function isMove() {
    return ::g_ww_army_move_state.getMoveParamsByName(this.status).isMove
  }

  function getCurrentPos() {
    return this.currentPosition
  }
}
