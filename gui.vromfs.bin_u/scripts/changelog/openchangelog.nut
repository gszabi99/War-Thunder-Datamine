local emptySceneWithDarg = require("scripts/wndLib/emptySceneWithDarg.nut")
local baseVersionsList = require("scripts/changelog/versions.nut")
local { mkVersionFromString, versionToInt } = require("std/version.nut")
local { targetPlatform, is_pc } = require("scripts/clientState/platform.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

const SAVE_ID = "changelog/lastSeenVersionInfoNum"
const maxPatchnotesNum = 10

local isShowedUnseenPatchnoteOnce = false
local lastSeenVersionInfoNumState = ::Watched(-1)

local function updateLastSeenVersionInfoNumState() {
  if (::g_login.isProfileReceived())
    lastSeenVersionInfoNumState(::load_local_account_settings(SAVE_ID, 0))
}
updateLastSeenVersionInfoNumState()

local versions = ::Watched([])
local function updateVersions() {
  versions(baseVersionsList
    .slice(0, maxPatchnotesNum)
    .filter(function(object){
      return object?.platform == null || object.platform.indexof(targetPlatform)!=null
        || (is_pc && object.platform.indexof("pc")!=null)
    })
    .map(function(v) {
      local version = mkVersionFromString(v.version)
      local title = v?.title?[::g_language.getLanguageName().tolower()] ?? v?.title?["english"] ?? v?.title["def"] ?? v?.title
      local tVersion = ".".join(version)
      if (::type(title)!="string")
        title = tVersion
      return {version = version, iVersion = versionToInt(version), tVersion = tVersion, versionType = v?.type, title=title}
    })
  )
}

versions.subscribe(function(value) {
  ::call_darg("updateExtWatched", {
    changelogsVersions = value
    languageName = ::g_language.getLanguageName()
  })
})

updateVersions()

local function findBestVersionToshow(versionsList = versions.value, lastSeenVersionNum=0) {
  //here we want to find first unseen Major version or last unseed hotfix version.
  lastSeenVersionNum = lastSeenVersionNum ?? 0
  versionsList = versionsList ?? []
  foreach (version in versionsList) {
    if (lastSeenVersionNum < version.iVersion && version.versionType=="major"){
      return version
    }
  }
  local res = null
  foreach(version in versionsList)
    if (version.iVersion > lastSeenVersionNum)
      res = version
    else
      break
  return res
}

local function markSeenVersion(v) {
  if (v == null || v.iVersion <= lastSeenVersionInfoNumState.value)
    return

  ::save_local_account_settings(SAVE_ID, v.iVersion)
  lastSeenVersionInfoNumState(v.iVersion)
}

local unseenPatchnote = ::Computed(function() {
  if (lastSeenVersionInfoNumState.value == -1)
    return null
  return findBestVersionToshow(versions.value, lastSeenVersionInfoNumState.value)
})

unseenPatchnote.subscribe(@(value) ::call_darg("updateExtWatched", { unseenPatchnote = value }))

local function openChangelog() {
  isShowedUnseenPatchnoteOnce = true
  local params = {
    widgetsList = [
      {
        widgetId = DargWidgets.CHANGE_LOG
      }
    ]
  }

  emptySceneWithDarg(params)
}

::cross_call_api.changelog <- {
  getVersions = @() versions.value
  getUnseenPatchnote = @() unseenPatchnote.value
  markSeenVersion = markSeenVersion
}

subscriptions.addListenersWithoutEnv({
  ProfileReceived = @(p) updateLastSeenVersionInfoNumState()
  GameLocalizationChanged = @(p) updateVersions()
})

return {
  openChangelog = openChangelog
  needShowChangelog = @() ::has_feature("Changelog") && !isShowedUnseenPatchnoteOnce
    && unseenPatchnote.value != null
}
