from "frp" import Watched, Computed
local DataBlock = require("DataBlock") //for debug purposes
local {TMatrix, Point2, Point3, Point4} = require("dagor.math")

local blk2str = require("%sqstd/blk2str.nut")
local {tostring_r} = require("%sqstd/string.nut")
local logLib = require("%sqstd/log.nut")

local log = logLib([
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
  {
    compare = @(val) val instanceof Computed
    tostring = @(val) "Computed: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
  {
    compare = @(val) val instanceof Point3
    tostring = function(val){
      return $"Point3: {val.x}, {val.y}, {val.z}"
    }
  }
  {
    compare = @(val) val instanceof Point4
    tostring = function(val){
      return $"Point4: {val.x}, {val.y}, {val.z}, {val.w}"
    }
  }
  {
    compare = @(val) val instanceof Point2
    tostring = function(val){
      return $"Point2: {val.x}, {val.y}"
    }
  }
  {
    compare = @(val) val instanceof TMatrix
    tostring = function(val){
      local o = []
      for (local i=0; i<4;i++)
        o.append("[{x}, {y}, {z}]".subst({x=val[i].x,y=val[i].y, z=val[i].z}))
      o = " ".join(o)
      return "TMatrix: [{0}]".subst(o)
    }
  }
  {
    compare = @(val) val instanceof DataBlock
    tostring = blk2str
  }
])

local logs = {
  dlog = log.dlog //warning disable: -dlog-warn
  log
  log_for_user = log.dlog //warning disable: -dlog-warn
  dlogsplit = log.dlogsplit //warning disable: -dlog-warn
  vlog = log.vlog
  console_print = log.console_print
  wlog = log.wlog
  wdlog = @(watched, prefix = "") log.wlog(watched, prefix, log.dlog) //disable: -dlog-warn
}

return require("daRg").__merge(require("frp"), require("darg_library.nut"), require("%sqstd/functools.nut"), logs)
