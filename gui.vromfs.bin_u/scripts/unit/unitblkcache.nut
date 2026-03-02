let { blkFromPath, blkOptFromPath } = require("%sqstd/datablock.nut")
let blkCache = { unitName = "", blks = {} }

function getBlkCached(path, unitName, fn) {
  if (blkCache.unitName != unitName) {
    blkCache.unitName = unitName
    blkCache.blks.clear()
  }
  if (path in blkCache.blks)
    return blkCache.blks[path]

  blkCache.blks[path] <- fn(path)
  return blkCache.blks[path]
}

return {
  blkFromPathCachedByUnit = @(path, unitName) getBlkCached(path, unitName, blkFromPath)
  blkOptFromPathCachedByUnit = @(path, unitName) getBlkCached(path, unitName, blkOptFromPath)
}