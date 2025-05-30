from "%scripts/dagui_library.nut" import log
from "%scripts/controls/controlsConsts.nut" import optionControlType
let { override, hasFeature, setOverrideFeature } = require("%scripts/user/features.nut")
let { dgs_get_settings } = require("dagor.system")
let { register_command } = require("console")

let devFeatures = {
  PremiumSubscription = {
    title = "Enable premium by subscription"
  }
}

let hasDevFeature = @(name) name in devFeatures

function setDevFeatureValue(name, value) {
  if (name not in devFeatures)
    return

  setOverrideFeature(value, name)
}

function updateDevFeaturesFromSystemConfig() {
  foreach(name, _devFeature in devFeatures) {
    let configOverride = dgs_get_settings()?.devFeatures[name]
    if (override.get()?[name] != null || configOverride == null )
      return

    setDevFeatureValue(name, configOverride)
  }
}

function getDevFeatures() {
  return devFeatures
}

function getDevFeaturesList() {
  if (!hasFeature("DevFeatures"))
    return []
  return devFeatures.reduce(function(res, val) {
    res.append([val.idx, "spinner"])
    return res
  }, [["options/header/features"]])
}

function getDevFeaturesOptionsMap() {
  let res = {}
  foreach(key, devFeature in devFeatures) {
    let name = key
    let title = devFeature?.title ?? key
    res[devFeature.idx] <- function(_optionId, descr, _context) {
      descr.id = name
      descr.title = title
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = hasFeature(name)
      descr.prevValue = hasFeature(name)
    }
  }
  return res
}

function getDevFeaturesOptionsSetMap() {
  let res = {}
  foreach(key, devFeature in devFeatures) {
    let name = key
    res[devFeature.idx] <- @(value, _descr, _optionId) setDevFeatureValue(name, value)
  }
  return res
}

updateDevFeaturesFromSystemConfig()

register_command(function(featureName) {
  if (!hasDevFeature(featureName)) {
    log($"the {featureName} feature does not exist")
    return
  }
  let newValue = !hasFeature(featureName)

  setDevFeatureValue(featureName, newValue)
  log($"feature: {featureName} is {newValue ? "ON" : "OFF"}")
}, "debug.developer_feature_switch")

return {
  getDevFeatures
  getDevFeaturesList
  getDevFeaturesOptionsMap
  getDevFeaturesOptionsSetMap
}