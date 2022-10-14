from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let function getUnlockConditions(modeBlk) {
  return modeBlk
    ? (modeBlk % "condition").extend(modeBlk % "hostCondition").extend(modeBlk % "visualCondition")
    : []
}

return {
  getUnlockConditions
}