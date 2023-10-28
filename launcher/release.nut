let {pp} = require("system.nut")
let {loc} = require("dagor.localize")

let function doUninstallScripts(){
  let uninsscr = getroottable()?["UninstallScripts"]
  if (!uninsscr)
    return true
  try {
    let gameDir = ::getGameDir()
    foreach (script in uninsscr) {
      pp("uninstall: ", script?.name, ", commandline: ", script?.commandline)
      if (script?.commandline)
        if (script?.async)
          ::shellExecuteAsync(script.commandline, script?.params ?? "", script?.workdir ?? gameDir, script.async)
        else
          ::shellExecute(script.commandline, script?.params ?? "", script?.workdir ?? gameDir, script?.show ?? 0)
    }
    return true
  }
  catch(e) {
    pp("uninstall error", e)
    return false
  }
  return false
}

::uninstall <- function() {
  doUninstallScripts()
  ::switchFrame(::runGameStates, "uninstall", true)

  ::uninstallBgUpdate(::getGameDir())

  ::uninstallGame(::getGameDir(), ::getYupProject(), ::onUninstallProgress, ::onUninstallDone,
    ::onUninstallError)
}

::onUninstallProgress <- function(val) {
  ::setProgress(val)
}

::onUninstallDone <- function() {
  ::exit()
}

::onUninstallError <- function(_err_code) {
  ::exit()
}

::onSeedingChange <- function() {
  let seedingOn = ::isChecked("seeding_on")
  ::setSeedingOn(seedingOn)
}

::onApplicationClose <- function(){}

::exitBtnMouseDown <- function() {
  ::exit()
}

::exitAndSaveBtnMouseDown <- function() {
  let msg =
    "exit button pressed, launcherVerState = {0}; gameVerState = {1}; filesCheckState = {2}".subst(
    ::launcherVerState, ::gameVerState, ::filesCheckState)

  println(msg);

  if (::projectState == YU2_STATE_DONE || ::projectState == YU2_STATE_SEEDING ||
    ::projectState == YU2_STATE_UNKNOWN || ::projectState == -1) {
      ::exit()
      return
  }

  if (::isChecked("hide_to_tray_option")) {
    ::minimizeToTray()

    let ballonText = loc("launcher/still_running")
    ::displayTrayBalloon(::launcherCONFIG.appName, ballonText)
  }
  else {
    let quest = loc("error/exit_confirm_while_download")

    if (::questMessage(quest, "")) {
      println("save and exit while downloading")
      ::exit()
    }
  }
}

::getSettingsBlkLoadPath <- function(path) {
  return ::isFullPath(path) ? path : ::makeFullPath(::getGameDir(), path)
}


::getSettingsBlkSavePath <- function(path) {
  return ::isFullPath(path) ? path : ::makeFullPath(::getGameDir(), path)
}

::fastCheckWait <- false

let function defExePath(params={}){
  let launchModes = ::launcherCONFIG?[params?.mode] ?? ::launcherCONFIG["launchAppDefault"]
  let config = ::create_and_load_blk(::getConfigPath())
  local isWin64Enabled = ::isWindows64() && !::isWindowsXP() && ::haveSSE41()
  if (::get_blk_bool(config, "forceWin64", false))
    isWin64Enabled = true
  println(isWin64Enabled ? "win64 enabled" : "win64 disabled")
  return launchModes?[isWin64Enabled ? "win64" : "win32"] ?? launchModes.unknown
}

let function defcmdline(_params={}){
  let cmdParams = [
    "-forcestart",
    "-add_file_to_report",
    "\"{0}\"".subst(::getLauncherLogPath())
  ]

  let dmmUserId = ::getDmmUserId()
  let dmmToken = ::getDmmToken()

  if (dmmUserId.len() > 0 && dmmToken.len() > 0)
    cmdParams.append("-dmm_user_id", dmmUserId, "-dmm_token", dmmToken)

  return " ".join(cmdParams)
}

if (!("getLaunchCommandLine" in getroottable()))
  ::getLaunchCommandLine <- defcmdline
if (!("getLaunchExePath" in getroottable()))
  ::getLaunchExePath <- defExePath

let function doInstallScripts(){
  let insScripts = getroottable()?["InstallScripts"]
  if (!insScripts)
    return true
  try {
    let gameDir = ::getGameDir()
    local ret = true

    foreach (script in insScripts) {
      pp("checking installed", script?.name)

      if (::type(script?.isInstalled)=="function" && script.isInstalled())
        pp("check passed", script?.name)
      else if (::type(script?.exe)=="string") {
        if (::fileExists(::makeFullPath(gameDir, script.exe))) {
          if (script?.async) {
            ::shellExecuteAsync(script.exe, script?.params ?? "", gameDir, script.async)
            ret = false //Don't run game, it will be run from script.async
          }
          else
            ::shellExecute(script.exe, script?.params ?? "", gameDir)
        }
        else
          pp("install file doesnt exist: ", script.exe)
      }
      else
        pp("incorrect commandline")
    }

    return ret
  }
  catch(e){
    pp("installation scripts error happend: ", e)
  }

  return true
}


::isEacInstalled <- function(game_id) {
  let function findStringInString(key,id) {
    return ::split_by_chars(key, ";").indexof(id) != null
  }

  let eacString = ::getRegString(HKEY_LOCAL_MACHINE, "SOFTWARE\\WOW6432Node\\EasyAntiCheat",
    "GamesInstalled","")

  return findStringInString(eacString, game_id)
}


::runGame <- function() {
  let params = {mode=(::develop ? "develop" : null)}

  local cmdLine = ::getLaunchCommandLine(params)
  let gameExe = ::getLaunchExePath(params)
  let gameDir = ::getGameDir()
  let gamePath = ::isFullPath(gameExe) ? gameExe : ::makeFullPath(gameDir, gameExe)

  //It is fix for few specific buggy versions, it may be removed sometime later
  if (typeof(cmdLine) == "array")
    cmdLine = " ".join(cmdLine)

  if (::shellExecute(gamePath, cmdLine, gameDir, SW_SHOWNORMAL))
    ::statsdCount("on_exit_after_run")

  let exitAfterRun = ::launcherCONFIG?.exitAfterRun ?? true
  if (exitAfterRun)
    ::exit()
}


::runGameBtnMouseDown <- function() {
  if (::fastCheckState == -1  && !::ignoreGameUpdate) {
    ::fastCheckWait = true
    ::display("run_wait", true)
    ::disable("RUN_BUTTON")
    return
  }

  if (!::saveAllSettings() && !::questMessage(loc("error/save_settings_run"), "")) {
    ::appStats.sendEvent("first_game_settings_fail")
    return
  }

  ::statsdCount("on_play_button_pressed")

  ::appStats.onGameRun()

  let runExe = ::getLaunchExePath({mode=::develop ? "develop" : null})
  let runPath = ::makeFullPath(::getGameDir(), runExe)

  if (!::fileExists(runPath)) {
    ::errorMessage("{0}\n\n{1}".subst(loc("error/noFileFound"), runPath),
      loc("error/noAppExists"))
    return
  }

  if (doInstallScripts())
    ::runGame()
}
