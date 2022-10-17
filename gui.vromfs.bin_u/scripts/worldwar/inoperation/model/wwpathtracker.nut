::WwPathTracker <- class
{
  status = ""
  currentPosition = null
  moveType = -1

  path = null
  points = null

  constructor(blk = null)
  {
    update(blk)
  }

  function update(blk = null)
  {
    if (!blk)
      return

    status = blk.status
    currentPosition = blk.pos
    moveType = blk.moveType

    path = blk.getBlockByName("path")
    checkPoints(path?.points)
  }

  function checkPoints(pointsBlk)
  {
    points = []
    if (!pointsBlk)
      return

    for (local i = 0; i < pointsBlk.blockCount(); i++)
      points.append(::u.copy(pointsBlk.getBlock(i)))
  }

  function isMove()
  {
    return ::g_ww_army_move_state.getMoveParamsByName(status).isMove
  }

  function getCurrentPos()
  {
    return currentPosition
  }
}
