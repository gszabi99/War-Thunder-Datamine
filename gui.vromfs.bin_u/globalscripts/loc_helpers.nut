from "logs.nut" import logerr
from "dagor.localize" import loc, doesLocTextExist
from "types" import String
from "%sqstd/platform.nut" import isSony, platformAlias

let reportedMissingLocKeys = {}

function loc_checked(key, ...) {
  let hasDefault = vargv.findindex(@(v) v instanceof String) != null
  if (!hasDefault && !doesLocTextExist(key)) {
    if (reportedMissingLocKeys?[key] == null) {
      logerr($"SQ [LANG] error: no key '{key}' in localization table")
      reportedMissingLocKeys[key] <- key
    }
  }
  return loc.acall([null, key].extend(vargv))
}

let vendorPrefix = { sony = "sony/", xbox = "xbox/" }?[platformAlias]

function getVendorLocId(locId) {
  if (vendorPrefix == null)
    return locId
  let vendorLocId = $"{vendorPrefix}{locId}"
  return doesLocTextExist(vendorLocId) ? vendorLocId : locId
}

let locByVendor = @(locId, ...) loc.acall([null, getVendorLocId(locId)].extend(vargv))

let gamepadSuffix = isSony ? "_sony" : "_xinput"

function getCtrlLocId(locId) {
  let gamepadLocId = $"{locId}{gamepadSuffix}"
  return doesLocTextExist(gamepadLocId) ? gamepadLocId : locId
}

let locCtrlId = @(locId, ...) loc.acall([null, getCtrlLocId(locId)].extend(vargv))

return freeze({
  loc_checked
  getVendorLocId
  locByVendor
  locCtrlId
})

