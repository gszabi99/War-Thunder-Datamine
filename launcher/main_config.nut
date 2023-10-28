from "math" import rand, RAND_MAX
let { pp, concat } = require("system.nut")
let { select, he, input } = require("build_html.nut")
let { loc } = require("dagor.localize")

::showHdPackSelector <- @(...) null

::launcher_id <- "WarThunderLauncher"

if (platformMac)
  ::launcher_id = "WarThunderLauncherOSX"
else if (platformLinux)
  ::launcher_id = "WarThunderLauncherLinux"

::default_yuproject_name <- "warthunder"

let steamVersionOrRunFromSteam = ::is_launched_from_steam() || ::findAllFiles("*.vdf").len()>0
let nbsp = @(num=1) "".join(array(num, "&nbsp;"))


let curCircuit_prop = "yunetwork/curCircuit"

let isEacEnabled = @() ::getValue("use_eac", false)

::getCustomCSettings <- function() {
  let conf = ::launcherCONFIG
  let yupproject_prop = conf?.yupproject_prop ?? "yunetwork/yuproject"
  let yutag_prop = conf?.yutag_prop ?? "yunetwork/yutag"
  let expertMode_prop = conf?.expertMode_prop ?? "yunetwork/isExpertMode"
  let confname = ::getConfigPath()
  let config = ::create_and_load_blk(confname)
  let cProject =::get_blk_str(config, yupproject_prop, ::default_yuproject_name)
  local tag = ::default_yutag
  let use_release_candidate = ::getValue("use_release_candidate", false)
  if (::get_blk_bool(config, expertMode_prop, false)) {
    ::expertMode = true
  }
  else if (::expertMode) {
    ::set_blk_bool(config, expertMode_prop, true)
    config.saveToTextFile(confname)
  }
  if (use_release_candidate)
    pp("use_release_candidate is on")
  local selCircuit = ::get_blk_str(config, curCircuit_prop, ::curCircuit ?? ::initialCircuit)
  if (!selCircuit || selCircuit=="")
    selCircuit = ::curCircuit ?? ::initialCircuit
  if (selCircuit != ::productionCircuit) {
    tag = ::curCircuit
    pp("tag set by circuit (" tag ")")
  }
  else if (use_release_candidate && selCircuit == ::productionCircuit) {
    pp("using release candidate, tag" ::production_rc_tag)
    tag = ::production_rc_tag
  }
  else {
    pp("tag set to default '" tag "' because of production circuit and not using release-candidate")
  }

  let cTag =::get_blk_str(config, yutag_prop, tag)

  let res = {project=cProject, tag=cTag}
  return res
}

let function checkEacInstalled() {
  let installScripts = getroottable()?["InstallScripts"]
  if (installScripts) {

    if (isEacEnabled()) { //Let's check EAC installed
      foreach (script in installScripts) {
        if (script?.name == "EasyAntiCheat" && ::type(script?.isInstalled) == "function") {
           ::display("eac_warn", !script.isInstalled())
          return
        }
      }
    }
    else { //Remove EAC from install scripts
      foreach (script in installScripts) {
        if (script?.name == "EasyAntiCheat") {
           break
        }
      }
    }
  }

  ::display("eac_warn", false)
}


let extraLauncherScheme = {
  use_release_candidate = {
    type="bool" defVal=false blk="use_release_candidate"
    setToBlk = function(blk, desc, val){
      ::set_blk_bool(blk, desc.blk, val)
      ::set_blk_str(blk, "releaseChannel", val ? "ReleaseCandidate" : "")
    }
  }
  use_eac = { type="bool" defVal=false blk="use_eac"}
}


::windowCreatedCallback <- function(){
  ::setOuterHtml("reviews_banner", ::getResourceLocalized("reviews.html"))

  ::launcher_settings_scheme.__update(extraLauncherScheme)
}

::launcherCONFIG <-{
  onInitComplete = function(){
    if (platformWindows) {
      ::display("eac_selector", true)
    }
    else {
      ::display("eac_selector", false)
    }
    ::display("use_release_candidate_div", ::curCircuit == ::productionCircuit)
  }
  onCheckFilesFast = checkEacInstalled
  onPackComplete = checkEacInstalled
  backgroundUpdate_prop = "launcher/bg_update"
  hide_to_tray_prop = "launcher/hide_to_tray_option"
  winstartup_prop = "launcher/startup_with_windows"
  config_name = "config.blk"
  expertMode_prop = "yunetwork/isExpertMode"
  curCircuit_prop
  yutag_prop = "yunetwork/yutag"
  yupproject_prop = "yunetwork/yuproject"
  bgUpdateInitial = !steamVersionOrRunFromSteam
  bgUpdateEnabled = !steamVersionOrRunFromSteam
  startupWithWindowsEnabled = !steamVersionOrRunFromSteam
  usingStartapp = true
  noRegisterUnderSteam = true
  hideToTray = platformMac || platformLinux || !steamVersionOrRunFromSteam
  forceFileTimeInFastCheck = steamVersionOrRunFromSteam
  appName = "War Thunder"
  macFolderName = "WarThunder.app"
  macFolderGame = "game"
  macResName = "warThunder"
  exitAfterRun = true
  showRunGameAfterMainPackComplete = true
  showRunGameAfterLangPackComplete = true

  epicAppName = "War Thunder"
  epicProductId = "63aa054b42ff4ac0a3cdae753f328312"
  epicSandboxId = "45baf6c4e5df46f0b21593d5b2268769"
  epicDeploymentId = "026d94346efa4788a40f168af01a8484"
  epicCliId = "xyza7891yjKrnjOF1GMTjnREwtjmlkZZ"
  epicCliSecret = "LcXkp0Q7eYqrFkCHmoCvnUAALY/ZK3WAnhSrPBVMmbU"
}
let function bannerCtr(){
  let textCtr = @(text, color) he("div", {class_="banner_text", style=(color ? "color:{0}".subst(color) : "")}, text)
  let banner = function(p={}){
    return he("div",
      {class_="banner", href=(p?.href ?? ""), style="background-color:{0};foreground-image:{1}".subst(p?.bg ?? "", p?.img ?? "")},
      textCtr(p?.text ?? "", p?.color))
  }

  let r = he("div", {class_="c" id="banners"},
            banner({href="https://live.warthunder.com/feed/all/?utm_source=launcher&utm_medium=bnnr_live&utm_campaign=launcherbnnr", color="#8987FF", bg="rgba(142, 56, 252, 0.26)", img="url(img/community.svg)", text=loc("wt_live")}),
            banner({href="https://store.gaijin.net/catalog.php?category=GoldenEagles?utm_source=launcher&utm_medium=bnnr_store&utm_campaign=launcherbnnr", color="#FFDC98", bg="rgba(217, 191, 142, 0.19)", img="url(img/wt_eagle.png)", text=loc("get_gold")})
           )
  pp(r)
  return r
}

let defHdOptions = [
  { value="minimal", locid=["client/minimal", "Minimal"] contents=["-"]}
  { value="hd", locid=["client/hd", "HD Client"], contents=["-", "pkg_main"] }
  { value="uhd_ground", locid = ["client/uhd_ground", "Ultra HQ ground models"], contents=["-", "pkg_main", "pkg_uhq_vehicles", "pkg_uhq_environment"] }
  { value="uhd_aircraft", locid = ["client/uhd_aircraft", "Ultra HQ aircraft"], contents=["-", "pkg_main", "pkg_uhq_aircraft", "pkg_uhq_environment"] }
  { value="uhd_all", locid = ["client/uhd_all", "Full Ultra HQ"], contents=["-", "pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"] }
]

local function makeHdClientHtml(options = null) {
  let curHdMode = ::getCurHdMode()
  if (options==null) {
    options = defHdOptions.map(function(v) {
      //we need to localize it here. Cause otherwise localizations are not loaded yet
      let text = loc(v.locid[0], v.locid[1])
      return v.value==curHdMode
        ? v.__merge({selected="yes" text})
        : v.__merge({text})
    })
  }
  return he("div", {id="hd_client_holder" style="text-align:right;margin:0 0 5dip 0;flow:horizontal"},
    he("div", {id="hd_client_label" title=loc("settings/hd_client_title") style="width:100%%;white-space:nowrap;color:white;vertical-align:bottom;padding:0 1em 4dip 0"}, loc("settings/client")),
    select({id="hd_client_sel" onChange="hdClientClick" size="1" align="right" title=loc("settings/hd_client_title") options})
  )
}

::style <- {
//  onInitComplete = @() ::hd_pack_value <- ::getCurHdMode()
  banner = bannerCtr
  common_front_settings =  function() {
    let r = he("div", {style="padding:0;line-height:20dip;position:fixed;text-align:left;right:20dip;vertical-align:bottom;bottom:124dip;"},
      makeHdClientHtml(defHdOptions),
      he("div", {class_="hidden" id="use_release_candidate_div" style="text-align:right;margin:0 0 5dip 0"},
        he("span", {style="color:white" title=loc("use_release_candidate/hint")}, loc("use_release_candidate")),
        nbsp(),
        input({type="checkbox" style="margin-top:-1dip;" id="use_release_candidate" onClick="set_use_release_candidate" title=loc("use_release_candidate/hint") tabindex="-1"})
      ),
      he("div", {class_="hidden" id="eac_selector" style="text-align:right;"},
        he("a", {style="color:white" href=loc("eac_explain_url") class_="ext_ref"}, loc("settings/use_eac")),
        nbsp(),
        input({type="checkbox" style="margin-top:-1dip;" id="use_eac" onClick="onEacSelected" tabindex="-1"})
      )
    )
    pp(r)
    return r
  }
}
::links<-{
  text = {
    def = [
      {text =@()loc("gamesite") url=@()loc("game_site") }
      {text =@()loc("signup") id="signup_link" url = @() ::is_launched_from_steam() ? loc("register_url_steam"): loc("register_url")}
      {text =@()loc("eula") url=@()loc("eula_url") }
    ]
  }
  icons = {
    def = [
      { img = "img/social/youTube_Icon.svg" url=@()loc("youtube_url")}
      { img = "img/social/fb_ico.svg" url="http://www.facebook.com/WarThunder" restrictedRegions=["ru"]}
      { img = "img/social/instagram_ico.svg" url="https://www.instagram.com/warthunder/" restrictedRegions=["ru"]}
      { img = "img/social/twitterIcon.svg" url=@()loc("twitter_url")}
    ]
    Russian = [
      { img = "img/social/vkontakteIcon.svg" url="http://vk.com/club13137988"}
      { img = "img/social/youTube_Icon.svg" url="http://www.youtube.com/c/warthunderru"}
      { img = "img/social/fb_ico.svg" url="http://www.facebook.com/WarThunder" restrictedRegions=["ru"]}
      { img = "img/social/instagram_ico.svg" url="https://www.instagram.com/warthunder/" restrictedRegions=["ru"]}
      { img = "img/social/twitterIcon.svg" url="https://twitter.com/WarThunder"}
      { img = "img/social/ok_ico.svg" url="https://ok.ru/warthunder"}
    ]
  }
}
::InstallScripts<-[
//  {name = "stub", isInstalled = @() true, exe = "", params=""} //required constants like 'gameDir', 'home', 'temp'
  {
    name="EasyAntiCheat" //Keep this name unchanged or change checkEacInstalled() for it
    isInstalled = function() {
      if (!isEacEnabled())
        return true
      return ::isEacInstalled("45")
    }
    exe = "EasyAntiCheat\\EasyAntiCheat_Setup.exe"
    params = "install 45 -console"
    async = function(_ok) {
      if ("runGame" in getroottable())
        ::runGame()
    }
  }
]

::UninstallScripts<-[
    {
      name = "EasyAntiCheat"
      commandline = "EasyAntiCheat\\EasyAntiCheat_Setup.exe uninstall 45 -console"
      async = @(_ok) null
    }
]

::PurifyTargets <- [
  "content/*",
  "res/*",
  "levels/*",
  "patch/*",
  "content.hq/*",
  "cache/*.#*", //Obsolete cache records
]

::PurifyIgnore <- [
  "content/warthunder.blk",
  "content/*.rq2",
  "content/*.ver",
  "content/userMissions/*",
  "content/pkg_local/*",
  "content/pkg_user/*"
]

let getIsWin64Enabled = function(){ //cached function
  local config_blk
  local isWin64
  let function getIsWin64(){
    if (isWin64 != null)
      return isWin64
    if (config_blk==null)
      config_blk = ::create_and_load_blk(::launcherCONFIG.config_name)
    isWin64 = ::isWindows64() && !::isWindowsXP()
    pp("isWin64=", ::isWindows64(), "isWindowsXP=", ::isWindowsXP(),"haveSSE41=")
    if (::get_blk_bool(config_blk, "forceWin64", false))
      isWin64 = true
    println(isWin64 ? "win64 enabled" : "win64 disabled")
    return isWin64
  }
  return getIsWin64
}()

let isMinCpuAvailable = function(){
  local res = null
  return function() {
    if (res == null)
      res = ::fileExists("EasyAntiCheat/Launcher/Settings64-min-cpu.json") && ::fileExists("win64/aces-min-cpu.exe")
    return res
  }
}()

::getLaunchExePath <- function(_params=null) {
  if (platformMac)
    return "../../.."

  if (platformLinux)
    return "linux64/aces"

  if (isEacEnabled())
    return "win32\\eac_launcher.exe"

  return getIsWin64Enabled()
    ? (!::haveSSE41() && isMinCpuAvailable())
      ? "win64\\aces-min-cpu.exe"
      : "win64\\aces.exe"
    : "win32\\aces.exe"
}

::getLaunchCommandLine <- function(_params=null){
  if (platformMac || platformLinux)
    return ""

  let cmdParams = [
    "-forcestart",
    "-add_file_to_report",
    "\"{0}\"".subst(::getLauncherLogPath())
  ]

  if (isEacEnabled()) {
    if (getIsWin64Enabled()) {
      if (!::haveSSE41() && isMinCpuAvailable())
        cmdParams.append("-eac_launcher_settings", "Settings64-min-cpu.json", "-eac_dir", "..\\EasyAntiCheat")
      else
        cmdParams.append("-eac_launcher_settings", "Settings64.json", "-eac_dir", "..\\EasyAntiCheat")
    }
    else
      cmdParams.append("-eac_launcher_settings", "Settings32.json", "-eac_dir", "..\\EasyAntiCheat")
  }

  let dmmUserId = ::getDmmUserId()
  let dmmToken = ::getDmmToken()

  if (dmmUserId.len() > 0 && dmmToken.len() > 0)
    cmdParams.append("-dmm_user_id", dmmUserId, "-dmm_token", dmmToken)

  return " ".join(cmdParams)
}


::promo_plugin <- "warthunder_promo"
::promoPluginId <- "WarThunderLauncherSciPromo"
::promo_script_path <- "warthunder_promo/warthunder.promo.nut"

::launchersettings_yup_section <- "scilauncher2"
::launchersettings_mount_path <- "launcher_settings"
::obsolete_settings_script <- "fallback_settings.nut"
::dev_launcher_settings_path <- "_scilauncher2_settings"
::yup_settings_script_path <- "warthunder.launcher.nut"
::usePromo <- true

::expertMode <- false
::production_rc_tag <-"production-rc"
::pkg_main_pack <- "pkg_main"
::default_yutag <- ""
::productionCircuit <- "production"
::initialCircuit <- ::productionCircuit
::rc_version_exists <- true

::newsEnabled <- true //fixme: need to customize position and other also!
::newsUrl <- {
  def = "https://warthunder.com/news3-en.html"
  French = "https://warthunder.com/news3-fr.html"
  German = "https://warthunder.com/news3-de.html"
  Spanish = "https://warthunder.com/news3-es.html"
  Czech = "https://warthunder.com/news3-cz.html"
  Portugese = "https://warthunder.com/news3-pt.html"
  Ukranian = "https://warthunder.ru/news3-ru.html"
  Belarusian = "https://warthunder.ru/news3-ru.html"
  Russian = "https://warthunder.ru/news3-ru.html"
  Polish = "https://warthunder.com/news3-pl.html"
  Chinese = "https://warthunder.com/news3-zh.html"
  Korean = "https://warthunder.com/news3-ko.html"
}


::circuits <- [
  {value = ::productionCircuit}
  {value = "dev" style="color:red;" file="matchingDevMode"}
  {value = "dev-stable" style="color:red;"}
  {value = "test" id="testCircuitOpt" style="color:gray;" file = "matchingTestingMode" showOnlyOnIgnoreUpdate=true hidden=true}
  {value = "nightly" id="nightly" style="color:gray;" showOnlyWhenSet=true hidden=true}
  {value = "tournament" id="tournament" style="color:gray;" showOnlyWhenSet=true hidden=true}
  {value = "experimental" id="experimentalCircuitOpt" style="color:gray;" showOnlyOnIgnoreUpdate=true hidden=true}
]

::supported_languages<-[
  {value="English" img="img/flags/usa.svg" text="English"}
  {value="Russian" img="img/flags/russia.svg" text="Русский"}
  {value="French" img="img/flags/france.svg" text="Français"}
  {value="Italian" img="img/flags/italy.svg" text="Italiano"}
  {value="German" img="img/flags/germany.svg" text="Deutsch"}
  {value="Spanish" img="img/flags/spain.svg" text="Español"}
  {value="Portuguese" img="img/flags/portugal_and_brazil.svg" text="Português"}
  {value="Polish" img="img/flags/poland.svg" text="Polski"}
  {value="Czech" img="img/flags/czech.svg" text="Česky"}
  {value="Hungarian" img="img/flags/hungary.svg" text="Magyar"}
  {value="Serbian" img="img/flags/serbia.svg" text="Srpski"}
  {value="Romanian" img="img/flags/romania.svg" text="Română"}
  {value="Belarusian" img="img/flags/belarus.svg" text="Беларуская"}
  {value="Ukrainian" img="img/flags/ukraine.svg" text="Українська"}
  {value="Turkish" img="img/flags/turkey.svg" text="Türkçe"}
  {value="Chinese" img="img/flags/china.svg" text="简体中文"}
  {value="TChinese" img="img/flags/taiwan.svg" text="繁體字"}
  {value="Korean" img="img/flags/korea.svg" text="한국어"}
  {value="Japanese" img="img/flags/japan.svg" text="日本語"}
]

::bgImagesMap <- {
    ru = "img/main_window_bg_art_ussr.jpg"
    by = "img/main_window_bg_art_ussr.jpg"
    kz = "img/main_window_bg_art_ussr.jpg"
    us = "img/main_window_bg_art_usa.jpg"
    gb = "img/main_window_bg_art_uk.jpg"
    fr = "img/main_window_bg_art_france.jpg"
    de = "img/main_window_bg_art_germany.jpg"
    it = "img/main_window_bg_art_italy.jpg"
    jp = "img/main_window_bg_art_japan.jpg"
    cn = "img/main_window_bg_art_china.jpg"
  }

::set_use_release_candidate <- function() {
  let msg = loc("use_release_candidate/warning")
  let use_release_candidate = ::getValue("use_release_candidate", false)
  local needRestart = true
  let rnd = rand() * 8 // 12% percentile to show warning
  pp("throwing coin =", rnd)
  if (rnd < RAND_MAX) {
    if (use_release_candidate && !::questMessage(msg, "")) {
      ::setValue("use_release_candidate", false)
      needRestart = false
    }
  }

  if (::curCircuit != ::productionCircuit)
    needRestart = false

  if (needRestart) {
    if (::isChecked("bg_update") && (::launcherCONFIG?.bgUpdateEnabled ?? true))
      ::configureBgUpdate(true, ::rcAutoupdateConfigured)
    else
      ::rcAutoupdateConfigured(true)
  }
}

::rcAutoupdateConfigured <- function(success) {
  ::saveAllSettings()
  ::onBgUpdateConfigured(success)

  ::restartLauncher()
}

let function gameRqsExist(...){
  foreach (v in vargv)
    if (!::fileExists(::makeFullPath(::getGameDir(), $"content/{v}.rq2")))
      return false
  return true
}
::getCurHdMode <- function(){
  local curSelect = "minimal"
  if (gameRqsExist("pkg_main"))
    curSelect = "hd"
  if (gameRqsExist("pkg_uhq_vehicles", "pkg_uhq_aircraft"))
    curSelect = "uhd_all"
  else if (gameRqsExist("pkg_uhq_aircraft"))
    curSelect = "uhd_aircraft"
  else if (gameRqsExist("pkg_uhq_vehicles"))
    curSelect = "uhd_ground"
  pp("current curSelect", curSelect)
  return curSelect
}

::getHdClientMode <- function() {
  return ::getValue("hd_client_sel", "".concat(::getCurHdMode()))
}

::hd_pack_value <- ::getCurHdMode()

let getGpuMemoryCached = function(){
  local memoryCache = null
  if ("gpuInfo" in getroottable() && ::gpuInfo.memory > 0)
    memoryCache = ::gpuInfo.memory
  else {
    ::getGpuInfo(function(name, memory){
      memoryCache = memory
      println($"videoMemory: {memory}")
      if ("gpuInfo" in getroottable()){
        ::gpuInfo.name = name
        ::gpuInfo.memory = memory
        ::gpuInfo.name_underscore = ::getGpuNameUnderscore()
      }
    })
  }
  return function(){
    pp("get gpuMemoryCached", memoryCache)
    if (memoryCache != null)
      return memoryCache
    if (!("gpuInfo" in getroottable()))
      memoryCache = ("getGpuMemory" in getroottable()) ? getroottable()["getGpuMemory"](): 0
    else
      memoryCache = ::gpuInfo.memory
    pp("gpuMemoryCached updated", memoryCache)
    return memoryCache
  }
}()

::hdPackSelector <- function(mode) {
  let undoHdPackSelector = getroottable()?["undoHdPackSelector"] ?? @(...) null
  pp("current hdPackSelector, mode ", mode)
  let gpuMemoryForUhq = 2.6*1000*1000*1000 //a bit less than 3GB
  let packConf = {
    minimal = { packages = [], dontCheckSpace = true}
    hd = { packages = ["pkg_main"] }
    uhd_ground = { packages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
    uhd_aircraft = { packages = ["pkg_main", "pkg_uhq_aircraft", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
    uhd_all = { packages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"], gpuMemoryNeeded = gpuMemoryForUhq }
  }
  let allPackages = ["pkg_main", "pkg_uhq_vehicles", "pkg_uhq_aircraft", "pkg_uhq_environment"]
  local doRestart = false

  let gameDir = ::getGameDir()
  let freeDiskSpace = ::getFreeDisk(gameDir)
  if (mode in packConf) {
    let pack = packConf[mode]
    let packagesToDelete = allPackages.filter(@(v) !pack.packages.contains(v))
    let packagesToAdd = allPackages.filter(@(v) pack.packages.contains(v))
    let gpuMemoryNeeded = pack?.gpuMemoryNeeded ?? 0
    packagesToDelete.extend(pack?.del ?? [])
    packagesToDelete.extend(pack?.add ?? [])

    if (packagesToDelete.len() > 0) {
      local willDel = false

      foreach (name in packagesToDelete) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (::fileExists(path)) {
          willDel = true
          break
        }
      }

      if (willDel) {
        if (!::questMessage(loc("confirm_delete_hd_client"), "")) {
          undoHdPackSelector()
          return
        }
      }

      foreach (name in packagesToDelete) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (::fileExists(path) && ::removeFile(path)) {
          let verPath = ::makeFullPath(gameDir, $"content/{name}.ver")

          if (::fileExists(verPath))
            ::removeFile(verPath)

          doRestart = true
        }
      }
    }

    if (packagesToAdd.len()>0) {
      local totalSize = 0

      foreach (name in packagesToAdd)
        totalSize += ::getPackFilesSize(gameDir, ::getYupProject(), name)
      let curGpuMemory = getGpuMemoryCached()
      pp("curGpuMemory", curGpuMemory, "neededMemory", gpuMemoryNeeded)

      if ( gpuMemoryNeeded > curGpuMemory && curGpuMemory!=0) {
        if (!::questMessage(loc("not_enough_gpu_memory"),"")) {
          undoHdPackSelector()
          return
        }
      }
      let requiredDiskSpace = (pack?.useExtraSpace ?? true)
         ? min(totalSize*2, totalSize+1*1000*1000*1000) //1GB extra space to make it possible to work for game
         : totalSize
      pp($"requiredDiskSpace = {requiredDiskSpace}, packTotalSize = {totalSize}, freeDiskSpace = {freeDiskSpace}")
      if ( requiredDiskSpace > freeDiskSpace ) {
        ::errorMessage("\n".concat(loc("yuplay/err_free_space"), ::bytesToLocString(requiredDiskSpace - freeDiskSpace)),"") //incorrect localizaton but launcer do not have correct localizatin module AT ALL!
        undoHdPackSelector()
        return
      }

      foreach (name in packagesToAdd) {
        let path = ::makeFullPath(gameDir, $"content/{name}.rq2")

        if (!::fileExists(path)) {
          if (::saveFile(path, "1"))
            doRestart = true
        }
      }
    }
  }

  ::hd_pack_value = mode

  if (doRestart) {
    ::saveAllSettings()
    ::restartLauncher()
  }
}

::undoHdPackSelector <- function() {
  ::setValue("hd_client_sel", ::hd_pack_value)
}

::hdClientCheckboxClicked <- function(){
  let gameFolder = ::getGameFolder()
  let rqPath = ::makeFullPath(gameFolder, concat("content/", ::pkg_main_pack, ".rq2"))
  let verPath = ::makeFullPath(gameFolder, concat("content/", ::pkg_main_pack, ".ver"))

  if (::isChecked("hdClientCheckbox")) {
    pp("HD client on")

    if (!::fileExists(rqPath))
      ::saveFile(rqPath, "1")

    if (::fileExists(verPath))
      ::removeFile(verPath)
  }
  else {
    pp("click on HD client off")
    let msg = loc("confirm_delete_hd_client")
    if (::questMessage(msg, "")) {
      pp("HD client off")

      if (::fileExists(rqPath))
        ::removeFile(rqPath)

      if (::fileExists(verPath))
        ::removeFile(verPath)
    }
    else{
      pp("user decided not to set HD client")
      ::setValue("hdClientCheckbox",true)
      return
    }
  }

  ::saveAllSettings()
  ::restartLauncher()
}

::hdClientClick <- function() {
  let mode = ::getHdClientMode()

  pp("click HD client", mode)
  ::hdPackSelector(mode)
}

::setHdPackSelector <- function(sel) {
  let curSelect = ::getCurHdMode()
  pp("curSelect", curSelect)

  let gameDir = ::getGameDir()
  let yupProj = ::getYupProject()

  let options = sel.map(function(option) {
    if (option.contents.len()) {
      let getPacksFilesSize = getroottable()?["getPacksFilesSize"]
      if (!getPacksFilesSize)
        return option
      let totalBytes = getPacksFilesSize(gameDir, yupProj, option.contents)
      if (totalBytes > 0) {
        let total = ::bytesToLocString(totalBytes)
        option.text = $"{option.text} ({total})"
      }
    }

    return curSelect==option.value
      ? {value=option.value text=option.text selected="1"}
      : {value=option.value text=option.text}
  })

  let html = makeHdClientHtml(options)
  pp("hd_client_holder", html)
  ::setHtml("hd_client_holder", html)
}

::onEacSelected <- function() {
  let use = isEacEnabled()

  if (use) {
    if (::fastCheckState > 0 || ("-" in ::completePacks))
      checkEacInstalled()
  }
  else
    ::display("eac_warn", false)
}


