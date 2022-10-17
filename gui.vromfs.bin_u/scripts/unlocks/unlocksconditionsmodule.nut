let function getUnlockConditions(modeBlk) {
  return modeBlk
    ? (modeBlk % "condition").extend(modeBlk % "hostCondition").extend(modeBlk % "visualCondition")
    : []
}

return {
  getUnlockConditions
}