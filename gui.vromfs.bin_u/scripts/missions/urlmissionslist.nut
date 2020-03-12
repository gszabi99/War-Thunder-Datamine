const MAX_URL_MISSIONS = 100
const MAX_URL_MISSION_NAME_LENGHT = 24

::g_url_missions <- {
  list = []
  isLoaded = false

  listSavePath = "url_missions_list"
}

g_url_missions.loadBlk <- function loadBlk(curMission, callback = null)
{
  ::gui_start_modal_wnd(::gui_handlers.LoadingUrlMissionModal, {curMission = curMission, callback = callback})
}

g_url_missions.loadOnce <- function loadOnce()
{
  if (isLoaded)
    return

  local listBlk = ::loadLocalByAccount(listSavePath)
  if (::u.isDataBlock(listBlk))
    foreach(misUrlBlk in listBlk % "mission")
      if (::u.isDataBlock(misUrlBlk))
      {
        list.append(::UrlMission(misUrlBlk))
        if (list.len() >= MAX_URL_MISSIONS)
          break
      }

  isLoaded = true

  fixUrlMissionNames()
}

g_url_missions.fixUrlMissionNames <- function fixUrlMissionNames()
{
  local hasFixedMissionNames = false
  foreach(mission in list)
    if (hasMissionWithSameName(mission, mission.name))
      for (local i = 1; i < MAX_URL_MISSIONS; i++)
      {
        local newName = mission.name
        local namePostFix = "[" + i.tostring() + "]"
        local newNameLen = utf8(newName + namePostFix).charCount()
        local unlimitCharCount = newNameLen - MAX_URL_MISSION_NAME_LENGHT
        if (unlimitCharCount > 0)
          newName = utf8(newName).slice(0, MAX_URL_MISSION_NAME_LENGHT - unlimitCharCount)
        newName += namePostFix
        if (!hasMissionWithSameName(mission, newName))
        {
          mission.name = newName
          hasFixedMissionNames = true
          break
        }
      }

  if (hasFixedMissionNames)
    save()
}

g_url_missions.save <- function save()
{
  if (!isLoaded)
    return

  local saveBlk = ::DataBlock()
  foreach(mission in list)
    saveBlk.mission <- mission.getSaveBlk()
  ::saveLocalByAccount(listSavePath, saveBlk)
}

g_url_missions.getList <- function getList()
{
  loadOnce()
  return list
}

g_url_missions.openCreateUrlMissionWnd <- function openCreateUrlMissionWnd()
{
  if (checkCanCreateMission())
    ::handlersManager.loadHandler(::gui_handlers.modifyUrlMissionWnd)
}

g_url_missions.openModifyUrlMissionWnd <- function openModifyUrlMissionWnd(urlMission)
{
  ::handlersManager.loadHandler(::gui_handlers.modifyUrlMissionWnd, { urlMission = urlMission })
}

g_url_missions.openDeleteUrlMissionConfirmationWnd <- function openDeleteUrlMissionConfirmationWnd(urlMission)
{
  local text = ::loc("urlMissions/msgBox/deleteConfirmation" {name = urlMission.name})
  local defButton = "no"
  local buttons = [
      ["yes", (@(urlMission) function() { ::g_url_missions.deleteMission(urlMission) })(urlMission)],
      ["no", function() {}]
    ]
  ::scene_msg_box("delete_url_mission_confirmation", null, text, buttons, defButton)
}

g_url_missions.hasMissionWithSameName <- function hasMissionWithSameName(checkingMission, name)
{
  foreach(mission in getList())
    if (mission != checkingMission && mission.name == name)
      return true

  if (::get_meta_mission_info_by_name(name) != null)
    return true

  return false
}

g_url_missions.checkDuplicates <- function checkDuplicates(name, url, urlMission = null)
{
  local errorMsg = ""
  foreach(mission in getList())
  {
    if (mission == urlMission)
      continue

    if (mission.name == name)
    {
      errorMsg = ::loc("urlMissions/nameExist", mission)
      break
    }
    if (mission.url == url)
    {
      errorMsg = ::loc("urlMissions/urlExist", mission)
      break
    }
  }

  if (errorMsg == "" && ::get_meta_mission_info_by_name(name) != null)
    errorMsg = ::loc("urlMissions/nameExist", { name = name })

  if (errorMsg == "")
    return true

  ::showInfoMsgBox(errorMsg)
  return false
}

g_url_missions.modifyMission <- function modifyMission(urlMission, name, url)
{
  if (urlMission.name == name && urlMission.url == url)
    return true

  if (!checkDuplicates(name, url, urlMission))
    return false

  urlMission.name = name
  if (urlMission.url != url)
  {
    urlMission.fullMissionBlk = null
    urlMission.hasErrorByLoading = false
  }
  urlMission.url = url
  save()
  ::broadcastEvent("UrlMissionChanged", { mission = urlMission })
  return true
}

g_url_missions.deleteMission <- function deleteMission(urlMission)
{
  local idx = list.indexof(urlMission)
  if (idx == null)
    return

  list.remove(idx)
  save()
  ::broadcastEvent("UrlMissionChanged", { mission = urlMission })
}

g_url_missions.checkCanCreateMission <- function checkCanCreateMission()
{
  loadOnce()
  if (list.len() < MAX_URL_MISSIONS)
    return true
  ::showInfoMsgBox(::loc("urlMissions/tooMuchMissions", { max = MAX_URL_MISSIONS }))
  return false
}

g_url_missions.createMission <- function createMission(name, url)
{
  if (!checkCanCreateMission())
    return false
  if (!checkDuplicates(name, url))
    return false

  local urlMission = ::UrlMission(name, url)
  list.append(urlMission)
  save()
  ::broadcastEvent("UrlMissionAdded", { mission = urlMission })
  return true
}

g_url_missions.toggleFavorite <- function toggleFavorite(urlMission)
{
  if (!urlMission)
    return
  urlMission.isFavorite = !urlMission.isFavorite
  save()
}

g_url_missions.setLoadingCompeteState <- function setLoadingCompeteState(urlMission, hasErrorByLoading, blk)
{
  if (!urlMission)
    return

  urlMission.fullMissionBlk = hasErrorByLoading ? null : blk
  if (urlMission.hasErrorByLoading != hasErrorByLoading)
  {
    urlMission.hasErrorByLoading = hasErrorByLoading
    save()
  }
  ::broadcastEvent("UrlMissionLoaded", { mission = urlMission })
}

g_url_missions.findMissionByUrl <- function findMissionByUrl(url)
{
  loadOnce()
  return ::u.search(list, (@(url) function(m) { return m.url == url })(url))
}

g_url_missions.findMissionByName <- function findMissionByName(name)
{
  loadOnce()
  return ::u.search(list, (@(name) function(m) { return m.name == name })(name))
}