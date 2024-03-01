let DataBlock = require("DataBlock")
let { Point2, IPoint2, Point3, IPoint3, Point4, Color3, Color4, TMatrix } = require("dagor.math")
let { isEqual } = require("%sqstd/underscore.nut")


let dagorClasses = {
  [DataBlock] = function(val1, val2) {
    if (val1.paramCount() != val2.paramCount() || val1.blockCount() != val2.blockCount())
      return false

    for (local i = 0; i < val1.paramCount(); i++)
      if (val1.getParamName(i) != val2.getParamName(i) || ! isEqual(val1.getParamValue(i), val2.getParamValue(i)))
        return false
    for (local i = 0; i < val1.blockCount(); i++) {
      let b1 = val1.getBlock(i)
      let b2 = val2.getBlock(i)
      if (b1.getBlockName() != b2.getBlockName() || !isEqual(b1, b2))
        return false
    }
    return true
  },
  [Point2] = @(val1, val2) val1.x == val2.x && val1.y == val2.y,
  [IPoint2] = @(val1, val2) val1.x == val2.x && val1.y == val2.y,
  [Point3] = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z,
  [IPoint3] = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z,
  [Point4] = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val1.w == val2.w,
  [Color4] = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b && val1.a == val2.a,
  [Color3] = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b,
  [TMatrix] = function(val1, val2) {
    for (local i = 0; i < 4; i++)
      if (!isEqual(val1[i], val2[i]))
        return false
    return true
  },
}

let customIsEqual = {}
function registerIsEqualClass(classRef, isEqualFunc) {
  customIsEqual[classRef] <- isEqualFunc
}

foreach (classRef, isEqualFunc in dagorClasses)
  registerIsEqualClass(classRef, isEqualFunc)

return {
  isEqual = @(val1, val2) isEqual(val1, val2, customIsEqual)
  registerIsEqualClass
}
