let {loc} =  require("dagor.localize")
let {concat, parsedCommandLine} = require("system.nut")

::onNewsReady <- function(html) {
  ::setHtml("news_frame", html)
  ::hidePartialOverflow("news_frame")
}

::launcherVerState <- -1
::gameVerState <- -1
::fastCheckState <- -1
::filesCheckState <- -2
::paused <- false
::downloadingTicks <- 0
::downlTickProgress <- 0.0
::completePacks <- {}
::obligatoryPacksDone <- false
::lockedFiles <- {}
::cacheDeleted <- false
::establishingProgressSec <- 10
::runGameEpicBlock <- false

::runGameStates <- [ "ver_progress", "load_launcher", "downloading_launcher",
                     "need_check", "checking_files", "downloading_files",
                     "need_download", "run_game", "uninstall" ]

::doCheckLauncherUpdates <- function(dont_check) {
  ::switchFrame(::runGameStates, "ver_progress", true)

  if (dont_check)
    ::onLauncherVersion(false)
  else {
    ::setHtml("progress_desc", loc("launcher/checking_version"))

    ::checkLauncherUpdates(::onLauncherVersion)
  }
}


::shouldSkipGameUpdate <- function() {
  return ::fileExists(::makeFullPath(::getGameFolder(), "ignoreGameUpdate"))
}


::doCheckGameVersion <- function() {
  ::setHtml("progress_desc", loc("yuplay/checking_version"))

  println("checkGameVersion: gameFolder = {0} project = {1} tag = {2}".subst(
    ::getGameFolder(), ::getYupProject(), ::getYupProjectTag()))

  local checkVerTime = 1200
  if (::shouldSkipGameUpdate())
    checkVerTime = 0

  ::checkGameVersion(::getGameFolder(), ::getYupProject(), ::getYupProjectTag(), ::onGameVersion, checkVerTime)
}


::onNoLauncherUpdate <- function() {
  ::launcherVerState = 1
  ::doCheckGameVersion()
}


::onLauncherUpdateError <- function() {
  ::show("launcher_upd_error")
  ::hideProgress()
  ::onNoLauncherUpdate()
}


::onLauncherVersion <- function(new_ver) {
  if (new_ver) {
    ::launcherVerState = 0

    ::switchFrame(::runGameStates, "downloading_launcher")
    ::updateLauncher(::getGameFolder(), ::onProgress, ::hideProgress, ::onLauncherUpdateError)
  }
  else {
    ::onNoLauncherUpdate()
  }
}


::fastCheckAfterPurify <- function() {
  if (!(parsedCommandLine.argv.indexof("force_timestamp_check"))) {
    if ("forceFileTimeInFastCheck" in getroottable() && ::launcherCONFIG?.forceFileTimeInFastCheck) {
      ::forceFileTimeInFastCheck(::getGameFolder(), ::getYupProject())
    } else if ("ignoreFileTimeInFastCheck" in getroottable() && ::launcherCONFIG?.ignoreFileTimeInFastCheck) {
      ::ignoreFileTimeInFastCheck(::getGameFolder(), ::getYupProject())
    }
  }

  ::checkFilesFast(::getGameFolder(), ::getYupProject(), ::nullProgress,
    ::onCheckFilesFast, ::doDownloadFiles)

  ::gameVerState = 1

  ::tryShowRunGame()
}


::doPurify <- function(next_action) {
  //Do purify only if need so and .yup exist
  let purifyTargets = getroottable()?["PurifyTargets"]
  if (!purifyTargets ||
    !::yupExist(::getGameFolder(), ::getYupProject())) {
      next_action()
      return
  }

  //Skip purification in develop mode
  if (::develop) {
    next_action()
    return
  }

  ::purifyGame(::getGameFolder(), ::getYupProject(), purifyTargets, (getroottable()?["PurifyIgnore"] ?? []), next_action)
}


::onGameVersion <- function(new_ver) {
  if ((::curCircuit == "test") || ::ignoreGameUpdate || (::curCircuit == "experimental")) {
    ::gameVerState = 1

    //Time to call in-yup section handler because we do not update existing .yup file
    if (!::yupHandleZipSection(::getGameFolder(), ::getYupProject())) {
      println("Couldn't handle in-yup settings, internal version")
      ::initGameVersionSettings(true, 0 )
    }

    ::doPurify(::tryShowRunGame)
    return
  }

  if (::fileExists(::makeFullPath(::getGameFolder(), "ignoreGameUpdate")))
    new_ver = false

  if (!new_ver) {
    //Time to call in-yup section handler because we do not update existing .yup file and .yup exists
    //If .yup doesn't exist it will be updated later (and zip-callback will be called after update)
    if (::yupExist(::getGameFolder(), ::getYupProject()) &&
      !::yupHandleZipSection(::getGameFolder(), ::getYupProject())) {
        println("Couldn't handle in-yup settings, yup doesn't have ZipSection")
        ::initGameVersionSettings(true, 0)
    }
  }

  if (new_ver) {
    ::gameVerState = 0

    ::fastCheckState = 0
    ::filesCheckState = 0

    ::doUpdateGame()
  }
  else if (::fileExists(::getYupResume())) {
    ::gameVerState = 1

    ::filesCheckState = 0
    ::fastCheckState = 0

    ::doDownloadFiles()
  }
  else if (::getValue("forcedLauncher", 0) > 1) {
    ::gameVerState = 1
    ::filesCheckState = 0
    ::fastCheckState = 0

    ::doDownloadFiles()
  }
  else if (::getValue("forcedLauncher", 0) == 1) {
    ::gameVerState = 1

    if (::questMessage(loc("error/incorrectExit"),"")) {
      ::filesCheckState = 0
      ::fastCheckState = 0

      ::doDownloadFiles()
    }
    else {
      ::doPurify(::fastCheckAfterPurify)
    }
  }
  else {
    ::doPurify(::fastCheckAfterPurify)
  }
}

::switchFrame <- function(frames, select, progress = false) {
  println("current frame = {0}".subst(select))
  foreach (id in frames)
    ::display(id, id == select)

  if (progress) {
    let imgId = "{0}_i".subst(select)
    ::setHtml(imgId, "<small_img id='{0}' src='img/progress_sm.gif'>".subst(imgId))
  }
}



::hideProgress <- function() {
  ::switchFrame(::runGameStates, "")
}

::tryShowRunGame <- function() {
  //Game can't be properly run under Epic before Epic login complete
  if (::isLaunchedFromEpic() && !::isEpicLoggedIn()) {
    ::runGameEpicBlock = true
    println("Couldn't show run game button due to Epic login incomplete")
    return
  }

  if (::develop) {
    println("Develop game. Show run game button anyway")
    ::showRunGame()
    return
  }

  if ((::curCircuit == "test") || ::ignoreGameUpdate || (::curCircuit == "experimental")) {
    println("Test version of game. Show run game button anyway")

    ::backgroundComplete()
    ::showRunGame()

    return
  }

  if (::gameVerState <= 0 || ::launcherVerState <= 0) { //not checked app/game version
    println("Version check has not been performed")
    return
  }

  if (::fastCheckState < 1) { //corrupted files or fast files check not yet finished
    println("Couldn't show run game button due to files seems corrupted or fast check hasn't performed yet")
    return
  }

  if (::filesCheckState == -1 || !::filesCheckState) { //files check in progress or failed
    println("Check in progress")
    return
  }

  ::showRunGame()
}


::showRunGameButton <- function() {
  ::display("pauseButton", false)
  ::display("resumeButton", false)

  println("Enable run game button")
  ::enable("RUN_BUTTON")
  ::statsdCount("on_play_button_enabled")

  ::appStats.onGameRunShown()
}

::showRunGame <- function() {
  ::showRunGameButton()

  ::display("progressbar_bar", false)
  ::display("check_files", true)

  ::switchFrame(::runGameStates, "run_game")

  let statusText = loc("yuplay/download_complete")
  ::setCaption("{0} - {1}".subst(loc("header"), statusText))
  ::setTrayIconTooltip(statusText)
  ::displayTrayBalloon(::launcherCONFIG.appName, statusText)
}


::nullProgress <- function(_progress) {}

::onCheckFilesFast <- function(files_ok) {
  if (files_ok) {
    ::fastCheckState = 1

    if (::isBackground()) {
      println("It's background mode and there is nothing to do. Time to exit")
      ::exit()
      return
    }

    if (::isChecked("seeding_on")) {
      ::forceSeeding(::getGameFolder(), ::getYupProject(), ::onDownloadStatus)
      ::show("speed_info")
    }
    if ("onCheckFilesFast" in ::launcherCONFIG)
      ::launcherCONFIG["onCheckFilesFast"]()

    if (::fastCheckWait)
      ::runGameBtnMouseDown()
    else
      ::tryShowRunGame()
  }
  else {
    ::fastCheckState = 0
    ::switchFrame(::runGameStates, "need_check")
  }
}

::onCheckFilesProgress <- function(val) {
  ::setProgress(val)
}


::downloadFilesProc <- function() {
  ::switchFrame(::runGameStates, "downloading_files", true)

  ::display("progressbar_bar", true)
  ::display("check_files", false)
  ::disable("RUN_BUTTON")

  let statusText = loc("yuplay/before_download")
  ::setHtml("downl_state", statusText)
  ::setCaption("{0} - {1}".subst(loc("header"), statusText))
  ::setTrayIconTooltip(statusText)

  ::setPackPriority(::getGameFolder(), ::getYupProject(), "-", 7)
  ::setPackPriority(::getGameFolder(), ::getYupProject(), "pkg_{0}".subst(::curLanguage), 7)

  ::downloadFiles(::getGameFolder(), ::getYupProject(), ::onProgress, ::onDownloadStateChange,
    ::onDownloadComplete, ::onDownloadError, ::onDownloadStatus, ::onPackComplete)
}


::purifyBeforeDownload <- function() {
  ::doPurify(::downloadFilesProc)
}


::doDownloadFiles <- function() {
  if (::yupExist(::getGameFolder(), ::getYupProject())) //There is .yup and we can perform files check/download missed
    ::purifyBeforeDownload()
  else //.yup file lost and we have to download current .yup and update game to that version
    ::doUpdateGame()
}


::onPackComplete <- function(name) {
  if (name in ::completePacks)
    return

  ::completePacks[name] <- true

  ::setPackPriority(::getGameFolder(), ::getYupProject(), name, 1)

  let rootComplete = "-" in ::completePacks

  if (rootComplete && ("onPackComplete" in ::launcherCONFIG))
    ::launcherCONFIG["onPackComplete"]()

  if (!::launcherCONFIG?.showRunGameAfterMainPackComplete &&
    !::launcherCONFIG?.showRunGameAfterLangPackComplete)
      return

  let langPackName = "pkg_{0}".subst(::curLanguage)

  local canShow = true

  if (::launcherCONFIG?.showRunGameAfterMainPackComplete && !rootComplete)
    canShow = false

  if (::launcherCONFIG?.showRunGameAfterLangPackComplete && !(langPackName in ::completePacks))
    canShow = false

  if (canShow) {
    println("All basic packs are ready")

    ::obligatoryPacksDone = true
    ::showRunGameButton()
  }
}


::setProgress <- function(val) {
  local rest = 100

  if (val >= 100)
    rest = 0
  else if (val <= 0)
    rest = 100
  else
    rest = 100 - val

  ::setStyleAttribute("progressbar", "width", "{0}%".subst(rest))
}


::onProgress <- function(val) {
  if (::downloadingTicks > ::establishingProgressSec || ::projectState != YU2_STATE_DOWNLOADING)
    ::setProgress(val)
  else
    ::downlTickProgress = val
}


::setGameVersion <- function() {
  let gameVer = ::getLocalGameVersion(::getGameFolder(), ::getYupProject())
  local version

  if (::curCircuit == ::productionCircuit)
    version = gameVer
  else
    version = "{0} (<font color=red>{1} server</font>)".subst(gameVer, ::curCircuit)

  ::setHtml("game_version", version)
  println("game version: {0}".subst(version))
}


::onDownloadComplete <- function() {
  ::fillNetworkStatus()

  ::gameVerState = 1
  ::filesCheckState = 1
  ::fastCheckState = 1

  ::setGameVersion()
  ::setValue("forcedLauncher",0)

  ::tryShowRunGame()
}


::onDownloadError <- function(err_code) {
  ::filesCheckState = 0

  if (::showTorrentErrorMessage(err_code))
    ::doDownloadFiles()
  else {
    ::display("progressbar_bar", true)
    ::setProgress(0)
    ::switchFrame(::runGameStates, "need_download")
  }
}

::getTorrentStateDesc <- function(state) {
  local actId

  switch (state) {
    case YU2_STATE_COPYING:
      actId = "yuplay/copying"
      break;

    case YU2_STATE_CHECKING:
      actId = "yuplay/analyzing_files"
      break;

    case YU2_STATE_DOWNLOADING:
      ::downloadingTicks = 0
      actId = "yuplay/downloading"
      break;

    case YU2_STATE_DONE:
    case YU2_STATE_SEEDING:
      actId = "yuplay/after_download"
      break;

    case YU2_STATE_DOWNLOADING_YUP:
      actId = "yuplay/downloading_yup"
      break;

    case YU2_STATE_PATCH_PREPARING:
      actId = "yuplay/patch_preparing"
      break;

    case YU2_STATE_PATCH_GAMERES:
      actId = "yuplay/patch_gameres"
      break;

    case YU2_STATE_PATCH_TEX:
      actId = "yuplay/patch_tex"
      break;

    case YU2_STATE_PATCH_FINISHING:
      actId = "yuplay/patch_finishing"
      break;

    default:
      actId = "yuplay/before_download"
  }

  local ret = loc(actId)

  if (state == YU2_STATE_PATCH_GAMERES || state == YU2_STATE_PATCH_TEX) {
    local step = ::getRespatchStep()

    if (step[1] > 1)
      ret = "{0}/{1} {2}".subst(step[0], step[1], ret)
  }

  return ret
}


::onTorrentStateChange <- function(state, id, downl_status_id) {
  ::projectState = state

  let actionText = ::getTorrentStateDesc(state)
  ::setHtml(id, actionText)

  if (!::isEnabled("RUN_BUTTON")) { //Update title only if Run game button is inactive
    ::setCaption("{0} - {1}".subst(loc("header"), actionText))
    ::setTrayIconTooltip(actionText)
  }

  if (state == YU2_STATE_DOWNLOADING || state == YU2_STATE_SEEDING)
    ::show("speed_info")
  else if (state != YU2_STATE_DONE)
    ::hide("speed_info")

  if (state == YU2_STATE_DOWNLOADING) {
    ::display(downl_status_id, true)

    ::display("pauseButton", true)
    ::display("resumeButton", false)
  }
  else {
    ::display(downl_status_id, false)

    ::display("pauseButton", false)
    ::display("resumeButton", false)
  }
}


::pauseBtnMouseDown <- function() {
  local stateString

  if (!::paused) {
    if (::questMessage(loc("error/confirm_pause"), "")) {
      ::paused = ::pauseDownload(::getGameFolder(), ::getYupProject())
      stateString = loc("paused")
      ::getTimeDiff(true)
    }
  }
  else {
    ::paused = !::resumeDownload(::getGameFolder(), ::getYupProject())
    stateString = loc("yuplay/downloading")
  }

  ::setText("downl_state", stateString)
  ::setCaption("{0} - {1}".subst(loc("header"), stateString))
  ::setTrayIconTooltip(stateString)

  ::display("downl_status", !::paused)
  ::display("pauseButton", !::paused)
  ::display("resumeButton", ::paused)
}


::hasDownloadingYup <- false;

::onDownloadStateChange <- function(state) {
  println("torrent state = {0}".subst(state))

  ::onTorrentStateChange(state, "downl_state", "downl_status")

  if (!::appStats.active)
    return;

  if (state == YU2_STATE_DOWNLOADING_YUP)
    ::hasDownloadingYup = true;
  else {
    if (::hasDownloadingYup) {
      ::appStats.onFirstYup()

      ::hasDownloadingYup = false
    }

    switch (state) {
      case YU2_STATE_DOWNLOADING:
        ::appStats.onFirstDownload()
        break

      case YU2_STATE_DONE:
        ::appStats.onFirstDownloadComplete()
        break
    }
  }
}


::updateAfterPurify <- function() {
  let cb = {
    progress = ::onProgress
    state = ::onDownloadStateChange
    done = ::onDownloadComplete
    error = ::onDownloadError
    status = ::onDownloadStatus
    pack = ::onPackComplete
  }

  let gameDir = ::getGameFolder()
  let proj = ::getYupProject()

  ::setPackPriority(gameDir, proj, "-", 7)
  ::setPackPriority(gameDir, proj, "pkg_{0}".subst(::curLanguage), 7)

  ::updateGameVersion(gameDir, proj, cb)
}


::onYupUpdated <- function() {
  ::doPurify(::updateAfterPurify)
}


::doUpdateGame <- function() {
  ::filesCheckState = -1

  ::switchFrame(::runGameStates, "downloading_files", true)

  let statusText = loc("yuplay/downloading_yup")
  ::setHtml("downl_state", statusText)
  ::setCaption("{0} - {1}".subst(loc("header"), statusText))
  ::setTrayIconTooltip(statusText)

  ::updateYup(::getGameFolder(), ::getYupProject(), ::getYupProjectTag(),
    ::onProgress, ::onDownloadStateChange, ::onYupUpdated, ::onDownloadError)
}


::strReplaceOnce <- function(str, repl, repl_to) {
  let pos = str.indexof(repl)
  if (pos != null) {
    return (pos > 0) ?
      concat(str.slice(0, pos), repl_to, str.slice(pos + repl.len())) :
      concat(repl_to, str.slice(repl.len()))
  }

  return str
}


::onSpeedChange <- function() {
  local downloadLimit=0
  local uploadLimit=0

  if (::isChecked("upl_limit")) {
    println("upl_limit enabled")
    uploadLimit = ::getValue("upl_speed_rate") * 1024
    println("upl_speed_rate = {0}".subst(uploadLimit))
    ::setUploadLimit(uploadLimit)
  }
  else {
    println("upl_speed_rate = 0")
    ::setUploadLimit(0)
  }

  if (::isChecked("dnl_limit")) {
    println("dnl_limit enabled")
    downloadLimit = ::getValue("dnl_speed_rate") * 1024
    println("dnl_speed_rate = {0}".subst(downloadLimit))
    ::setDownloadLimit(downloadLimit)
  }
  else {
    println("dnl_speed_rate = 0")
    ::setDownloadLimit(0)
  }
}

::onDnlLimit <- function() {
  ::display("dnl_speed_rate", ::isChecked("dnl_limit"))
  ::onSpeedChange()
}

::onUplLimit <- function() {
  ::display("upl_speed_rate", ::isChecked("upl_limit"))
  ::onSpeedChange()
}

::setDownloadParams <- function() {
  ::onDnlLimit()
  ::onUplLimit()
  ::onSpeedChange()
}


::onUTPChange <- function() {
  let utp = ::getValue("UTP")
  ::setUTP(utp)

  println(utp ? "UTP: on" : "UTP: off")
}

::onDHTChange <- function() {
  let dht = ::getValue("DHT")
  ::setDHT(dht)

  println(dht ? "DHT: on" : "DHT: off")
  ::setDHT(false) //temporary disabled DHT
}

::onPeerExchangeChange <- function() {
  let pe = ::getValue("peer_exchange")
  ::setPeerExchange(pe)

  println(pe ? "Peer exchange: on" : "Peer exchange: off")
}

let sizeNames = [ loc("size_b"), loc("size_kb"), loc("size_mb"), loc("size_gb") ]
let speedNames = [ loc("speed_b"), loc("speed_kb"), loc("speed_mb"), loc("speed_gb") ]
::bytesToLocString <- function bytesToLocString(sizeBytes){
  local meas = sizeBytes / 1073741824.0 //GB
  let [b, kb, mb, gb] = sizeNames
  local desc = b
  if (meas > 0.5)
    desc = gb
  else {
    meas = sizeBytes / 1048576.0 //MB
    if (meas > 0.5)
      desc = mb
    else {
      meas = sizeBytes / 1024.0 //KB
      desc = meas > 0.5 ? kb : b
    }
  }

  return ::format("%.1f%s", meas, desc)
}

::getStatusStr <- function(total, ts, downl, ds, speed, ss, rest, rs, eta) {
  local statusMask = "download_progress"

  if (::downloadingTicks < 180)
    statusMask = "download_progress_noeta"

  local statusStr = loc(statusMask)
  let totalStr = "{0} {1}".subst(total, sizeNames[ts])
  let downlStr = "{0} {1}".subst(downl, sizeNames[ds])
  let speedStr = "{0} {1}".subst(speed, speedNames[ss])
  let restStr = "{0} {1}".subst(rest, sizeNames[rs])

  statusStr = ::strReplaceOnce(statusStr, "[total]", totalStr)
  statusStr = ::strReplaceOnce(statusStr, "[done]", downlStr)
  statusStr = ::strReplaceOnce(statusStr, "[speed]", speedStr)
  statusStr = ::strReplaceOnce(statusStr, "[rest]", restStr)
  statusStr = ::strReplaceOnce(statusStr, "[eta]", ::getETAStr(eta))

  return statusStr
}

::fillNetworkStatus <- function(data = null) {
  local speed = "0"
  local uspeed = "0"
  local p2pSpeed = "0"
  local p2pSeeds = "0"
  local httpSpeed = "0"
  local httpSeeds = "0"

  if (data != null) {
    speed = "{0} {1}".subst(data.speed, speedNames[data.speed_m])
    uspeed = "{0} {1}".subst(data.uspeed, speedNames[data.uspeed_m])
    p2pSpeed = "{0} {1}".subst(data.p2p, speedNames[data.p2p_m])
    httpSpeed = "{0} {1}".subst(data.http, speedNames[data.http_m])
    p2pSeeds = data.p2p_seeds.tostring()
    httpSeeds = data.http_seeds.tostring()
  }

  ::setText("net_speed", speed)
  ::setText("net_uspeed", uspeed)
  ::setText("net_p2p_speed", p2pSpeed)
  ::setText("net_http_speed", httpSpeed)
  ::setText("net_p2p_seeds", p2pSeeds)
  ::setText("net_http_seeds", httpSeeds)
}

::onDownloadStatus <- function(data) {
  ++::downloadingTicks

  if (::isVisible("downl_status")) {
    local statusString

    if (::downloadingTicks > ::establishingProgressSec || ::projectState != YU2_STATE_DOWNLOADING) {
      statusString = ::getStatusStr(data.total, data.total_m, data.downloaded,
        data.downloaded_m, data.speed, data.speed_m, data.rest,
        data.rest_m, data.eta)

      if (::downloadingTicks == 61 && ::downlTickProgress > 0.0)
        ::setProgress(::downlTickProgress)
    }
    else {
      statusString = loc("yuplay/fake_connection")

      let prog = ::downloadingTicks * (100.0 / ::establishingProgressSec)
      ::setProgress(prog.tointeger())
    }

    ::setHtml("downl_status", statusString)

    if (!::isEnabled("RUN_BUTTON")) { //Update title only if Run game button is inactive
      ::setCaption("{0} - {1}".subst(loc("header"), statusString))
      ::setTrayIconTooltip(statusString)
    }
  }

  ::fillNetworkStatus(data)
}


::showTorrentErrorMessage <- function(err_code) {
  local msgId = ""
  local errorDesc = ""
  local restartLoad = false

  switch (err_code) {
    case YU2_ERROR_ACCESS_RIGHTS:
      msgId = "yuplay/err_access_rights"
      break;

    case YU2_ERROR_SPACE:
      msgId = "yuplay/err_free_space"
      break;

    case YU2_ERROR_YUP_ACCESS:
      msgId = "yuplay/err_write_yup"
      break;

    case YU2_ERROR_NO_YUP_DOWNLOADED:
      msgId = "yuplay/err_yup_download"
      break;

    case YU2_ERROR_DISK:
      msgId = "yuplay/err_disk"
      restartLoad = true
      errorDesc = ::getErrorDesc(::getGameFolder(), ::getYupProject())
      break;

    case YU2_ERROR_UNPACKING_ARCHIVE:
      msgId = "yuplay/err_unpack"
      errorDesc = ::getErrorDesc(::getGameFolder(), ::getYupProject())
      break;

    case YU2_ERROR_FILE_LOCKED:
      errorDesc = ::getErrorDesc(::getGameFolder(), ::getYupProject())

      if (errorDesc in ::lockedFiles) {
        msgId = "yuplay/err_disk"
        restartLoad = true
      }
      else {
        ::lockedFiles[errorDesc] <- true
        return true
      }

      break;
  }

  if (msgId.len()) {
    ::lockedFiles = {}

    local message = loc(msgId)
    if (errorDesc)
      message = concat(message, "\n", errorDesc)

    if (restartLoad)
      return ::questMessage(message, "")
    else
      ::errorMessage(message, "")
  }

  return false
}

local timeNames = [
  loc("time_day"), loc("time_hour"),
  loc("time_min"), loc("time_sec")
]

::getETAStr <- function(sec) {
  if (sec < 0)
    return loc("time_inf")

  let days = sec / 86400
  sec -= days * 86400

  let hours = sec / 3600
  sec -= hours * 3600

  let mins = sec / 60
  sec -= mins * 60

  let times = [ days, hours, mins, sec ]

  for (local i = 0; i < 3; ++i) {
    if (times[i]) {
      if (times[i + 1])
        return "{0} {1} {2} {3}".subst(times[i], timeNames[i], times[i + 1], timeNames[i + 1])

      return "{0} {1}".subst(times[i], timeNames[i])
    }
  }

  return "{0} {1}".subst(times[3], timeNames[3])
}
