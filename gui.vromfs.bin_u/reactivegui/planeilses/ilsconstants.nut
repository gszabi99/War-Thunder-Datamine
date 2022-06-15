const mpsToKnots = 1.94384
const metrToFeet = 3.28084
const mpsToFpm = 196.8504
const mpsToKmh = 3.6
const metrToMile = 0.000621371
const metrToNavMile = 0.000539957
let baseLineWidth = hdpx(4 * LINE_WIDTH)

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
  RESULT_LOCK_AFTER_LAUNCH = 4
}

return {
  mpsToKnots
  metrToFeet
  mpsToFpm
  mpsToKmh
  baseLineWidth
  GuidanceLockResult
  metrToMile
  metrToNavMile
}