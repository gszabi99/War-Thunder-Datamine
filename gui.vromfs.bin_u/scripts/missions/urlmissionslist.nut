from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let DataBlock = require("DataBlock")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_meta_mission_info_by_name } = require("guiMission")

const MAX_URL_MISSIONS = 100
const MAX_URL_MISSION_NAME_LENGTH = 24

let g_url_missions = {
  list = []
  isLoaded = false

  listSavePath = "url_missions_list"
}

g_url_missions.loadBlk <- function loadBlk(curMission, callback = null) {
  loadHandler(gui_handlers.LoadingUrlMissionModal, { curMission = curMission, callback = callback })
}

g_url_missions.loadOnce <- function loadOnce() {
  if (this.isLoaded)
    return

  let listBlk = loadLocalByAccount(this.listSavePath)
  if (u.isDataBlock(listBlk))
    foreach (misUrlBlk in listBlk % "mission")
      if (u.isDataBlock(misUrlBlk)) {
        this.list.append(::UrlMission(misUrlBlk))
        if (this.list.len() >= MAX_URL_MISSIONS)
          break
      }

  this.isLoaded = true

  this.fixUrlMissionNames()
}

g_url_missions.fixUrlMissionNames <- function fixUrlMissionNames() {
  local hasFixedMissionNames = false
  foreach (mission in this.list)
    if (this.hasMissionWithSameName(mission, mission.name))
      for (local i = 1; i < MAX_URL_MISSIONS; i++) {
        local newName = mission.name
        let namePostFix = "".concat("[", i.tostring(), "]")
        let newNameLen = utf8("".concat(newName, namePostFix)).charCount()
        let unlimitCharCount = newNameLen - MAX_URL_MISSION_NAME_LENGTH
        if (unlimitCharCount > 0)
          newName = utf8(newName).slice(0, MAX_URL_MISSION_NAME_LENGTH - unlimitCharCount)
        newName += namePostFix  //-plus-string
        if (!this.hasMissionWithSameName(mission, newName)) {
          mission.name = newName
          hasFixedMissionNames = true
          break
        }
      }

  if (hasFixedMissionNames)
    this.save()
}

g_url_missions.save <- function save() {
  if (!this.isLoaded)
    return

  let saveBlk = DataBlock()
  foreach (mission in this.list)
    saveBlk.mission <- mission.getSaveBlk()
  saveLocalByAccount(this.listSavePath, saveBlk)
}

g_url_missions.getList <- function getList() {
  this.loadOnce()
  return this.list
}

g_url_missions.openCreateUrlMissionWnd <- function openCreateUrlMissionWnd() {
  if (this.checkCanCreateMission())
    loadHandler(gui_handlers.modifyUrlMissionWnd)
}

g_url_missions.openModifyUrlMissionWnd <- function openModifyUrlMissionWnd(urlMission) {
  loadHandler(gui_handlers.modifyUrlMissionWnd, { urlMission = urlMission })
}

g_url_missions.openDeleteUrlMissionConfirmationWnd <- function openDeleteUrlMissionConfirmationWnd(urlMission) {
  let text = loc("urlMissions/msgBox/deleteConfirmation" { name = urlMission.name })
  scene_msg_box("delete_url_mission_confirmation", null, text, [
      [ "yes", @() g_url_missions.deleteMission(urlMission) ],
      [ "no", @() null ]
    ], "no", { cancel_fn = @() null })
}

g_url_missions.hasMissionWithSameName <- function hasMissionWithSameName(checkingMission, name) {
  foreach (mission in this.getList())
    if (mission != checkingMission && mission.name == name)
      return true

  if (get_meta_mission_info_by_name(name) != null)
    return true

  return false
}

g_url_missions.checkDuplicates <- function checkDuplicates(name, url, urlMission = null) {
  local errorMsg = ""
  foreach (mission in this.getList()) {
    if (mission == urlMission)
      continue

    if (mission.name == name) {
      errorMsg = loc("urlMissions/nameExist", mission)
      break
    }
    if (mission.url == url) {
      errorMsg = loc("urlMissions/urlExist", mission)
      break
    }
  }

  if (errorMsg == "" && get_meta_mission_info_by_name(name) != null)
    errorMsg = loc("urlMissions/nameExist", { name = name })

  if (errorMsg == "")
    return true

  showInfoMsgBox(errorMsg)
  return false
}

g_url_missions.modifyMission <- function modifyMission(urlMission, name, url) {
  if (urlMission.name == name && urlMission.url == url)
    return true

  if (!this.checkDuplicates(name, url, urlMission))
    return false

  urlMission.name = name
  if (urlMission.url != url) {
    urlMission.fullMissionBlk = null
    urlMission.hasErrorByLoading = false
  }
  urlMission.url = url
  this.save()
  broadcastEvent("UrlMissionChanged", { mission = urlMission })
  return true
}

g_url_missions.deleteMission <- function deleteMission(urlMission) {
  let idx = this.list.indexof(urlMission)
  if (idx == null)
    return

  this.list.remove(idx)
  this.save()
  broadcastEvent("UrlMissionChanged", { mission = urlMission })
}

g_url_missions.checkCanCreateMission <- function checkCanCreateMission() {
  this.loadOnce()
  if (this.list.len() < MAX_URL_MISSIONS)
    return true
  showInfoMsgBox(loc("urlMissions/tooMuchMissions", { max = MAX_URL_MISSIONS }))
  return false
}

g_url_missions.createMission <- function createMission(name, url) {
  if (!this.checkCanCreateMission())
    return false
  if (!this.checkDuplicates(name, url))
    return false

  let urlMission = ::UrlMission(name, url)
  this.list.append(urlMission)
  this.save()
  broadcastEvent("UrlMissionAdded", { mission = urlMission })
  return true
}

g_url_missions.toggleFavorite <- function toggleFavorite(urlMission) {
  if (!urlMission)
    return
  urlMission.isFavorite = !urlMission.isFavorite
  this.save()
}

g_url_missions.setLoadingCompeteState <- function setLoadingCompeteState(urlMission, hasErrorByLoading, blk) {
  if (!urlMission)
    return

  urlMission.fullMissionBlk = hasErrorByLoading ? null : blk
  if (urlMission.hasErrorByLoading != hasErrorByLoading) {
    urlMission.hasErrorByLoading = hasErrorByLoading
    this.save()
  }
  broadcastEvent("UrlMissionLoaded", { mission = urlMission })
}

g_url_missions.findMissionByUrl <- function findMissionByUrl(url) {
  this.loadOnce()
  return u.search(this.list,  function(m) { return m.url == url })
}

g_url_missions.findMissionByName <- function findMissionByName(name) {
  this.loadOnce()
  return u.search(this.list,  function(m) { return m.name == name })
}
return { g_url_missions }