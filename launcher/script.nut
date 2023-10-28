
from "math" import RAND_MAX

::loc <- require("dagor.localize").loc

let loc = ::loc //-ident-hides-ident
::launchersettings_yup_section <- "scilauncher2"
::default_yuproject_name <- "__undefined__" //should be set in main_config.nut per project
::default_yutag <- "production" //should be set in main_config.nut per project
::productionCircuit <- "production" //should be set in main_config.nut per project
::production_rc_tag <- "production-rc" //should be set in main_config.nut per project
::dev_launcher_settings_path <- "_scilauncher2_settings" //should be set in main_config.nut per project
::yup_launcher_settings_path <- "launcher_settings" //should be set in main_config.nut per project
::launchersettings_mount_path <- "launcher_settings" //should be set in main_config.nut per project
::yup_settings_script_path <- null //should be set in main_config.nut per project
::promo_script_path <- null //should be set in main_config.nut per project
::bgImagesMap <- {}//should be set in main_config.nut per project

let Observable = require("observable.nut")
require("blk.nut")
let {print_file_to_debug, parsedCommandLine, pp, unpack, concat} = require("system.nut")
let {he, select} = require("build_html.nut")
let {rand} = require("math")
require("main_config.nut")


::getGameFolder <- ::getGameDir

//Remove this backward compatibility fix somewhere in 2023 or later
::pp <- pp //-ident-hides-ident
::print_file_to_debug <- print_file_to_debug //-ident-hides-ident
::DataBlock <- require("DataBlock")


local cachedYupmasterUrl = null
let function getYupmasterUrl(){
  println("getting yupmaster url from optional yupmaster.blk, 'host' param")
  if (cachedYupmasterUrl!=null) {
    println($"yupmaster url from cache {cachedYupmasterUrl}")
    return cachedYupmasterUrl
  }
  const defYupmasterUrl = "https://yupmaster.gaijinent.com"
  local yupmasterUrl = defYupmasterUrl
  try{
    let pathToYpmasterBlk = ::makeFullPath(::getGameFolder(),"yupmaster.blk")
    println("trying to load yupmaster.blk")
    if (::fileExists(pathToYpmasterBlk)){
      let yupmasterBlk = ::create_and_load_blk(pathToYpmasterBlk)
      println("successfully loaded yupmaster.blk")
      yupmasterUrl = yupmasterBlk.getStr("host", defYupmasterUrl)
      println($"yupmaster url from yupmaster.blk {yupmasterUrl}")
      cachedYupmasterUrl = yupmasterUrl
      ::overrideYupmaster(yupmasterUrl)
    }
  }
  catch(e){
    ::debug($"error loading yupmaster.blk: {e}")
    cachedYupmasterUrl = defYupmasterUrl
  }
  return yupmasterUrl
}
getYupmasterUrl()

if (::launcherCONFIG?.macFolderName && platformMac) {
  ::setMacGameFolder(::launcherCONFIG.macFolderName, ::launcherCONFIG.macFolderGame,
    ::launcherCONFIG.macResName)
}

if (::launcherCONFIG?.epicAppName) {
  if ("setEpicApi" in getroottable())
    ::setEpicApi(::launcherCONFIG.epicAppName, ::launcherCONFIG.epicProductId,
      ::launcherCONFIG.epicSandboxId, ::launcherCONFIG.epicDeploymentId,
      ::launcherCONFIG.epicCliId, ::launcherCONFIG.epicCliSecret)
}


::getConfigPath <- function() {
  let fname = ::launcherCONFIG?.config_name ?? "config.blk"

  return ::makeFullPath(::getGameDir(), fname)
}

require("events.nut")

let windowsVer = ::getRegString(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\", "CurrentVersionNumber", "6.1")
pp("windowsVer =", windowsVer)

::getWindowsVersion <- function(){
  let registerPath = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\"
  let windowsVerReg = ::getRegString(HKEY_LOCAL_MACHINE, registerPath, "CurrentVersion", "6.1")
  let windowsMajorVer = ::getRegInt(HKEY_LOCAL_MACHINE, registerPath, "CurrentMajorVersionNumber", 0)
  let windowsMinorVer = ::getRegInt(HKEY_LOCAL_MACHINE, registerPath, "CurrentMinorVersionNumber", 0)
  local numVer = 5.1
  local result = false
  try{
    numVer = windowsVerReg.tofloat()
    result = true
  }
  catch(e){
    pp("cannot convert Windows version to float:", windowsVer)
  }
  return {numVer, result, ver=windowsVer, majorVer = windowsMajorVer, minorVer = windowsMinorVer}
}

local curLauncherId = ::launcher_id

::projectState <- -1
::seederGaijinLanPing <- false
::curCircuit <- ""
::yupProject <- ""
::trackerUrl <- "udp://yuptracker.gaijinent.com:27022/announce"
::devTrackerUrl <- "udp://seeder.gaijin.lan:27022/announce"
::retrackerUrl <- "http://retracker.local/announce"


::promoPluginMountResult <- MOUNT_FAIL

::isLauncherFirstRun <- false
::curLanguage <- ::getRegString(HKEY_CURRENT_USER, ::getRegPath(), "language", "English")
let function __initDefaults(){
  let config = ::create_and_load_blk(::getConfigPath())
  pp("curLanguage by registry:",::curLanguage)
  ::curLanguage = ::get_blk_str(config, "language", ::supported_languages?[0]?.value ?? ::curLanguage)
  pp("curLanguage by config:",::curLanguage)
  let arc = parsedCommandLine.argv.indexof("arc")!=null
  let arc_lang = parsedCommandLine.kvargv?["locale"]
  if ( arc && arc_lang!=null)
    ::curLanguage = arc_lang
  ::isLauncherFirstRun = config.getBlockByName("launcher") == null
  let launcherReleaseSuffix = ::get_blk_str(config, "launcherRelease", "")
  pp("arc_lang:",arc_lang,"arc:",arc, "isLauncherFirstRun:",::isLauncherFirstRun)
  pp("launcherRelease:t=",launcherReleaseSuffix)
  local promoReleaseSuffix = launcherReleaseSuffix
  if (config.paramExists("promoReleaseSuffux")) {
    promoReleaseSuffix = ::get_blk_by_path(config, "promoReleaseSuffux", "")
  }
  else {
    pp("promoReleaseSuffix:t= is missed in config, set be default to launcherRelease:t=")
  }
  let prplid = getroottable()?["promoPluginId"]
  if (prplid)
    ::promoPluginId <- $"{prplid}{promoReleaseSuffix}"
  curLauncherId = curLauncherId + launcherReleaseSuffix
}
__initDefaults()

::setLanguage <- function(lang){
  pp("set language:" lang)
  ::curLanguage = lang
}

::addLocalization <- function(csv, lang=null){
  ::addLocalizationWithLang(csv, lang ?? ::curLanguage)
}
::addLocalization("common.csv",::curLanguage)
::addLocalization("main.csv",::curLanguage)

::gpuInfo <- {
  need_check = (!::getConfigPath() || ::isLauncherFirstRun)
  name = "unknown"
  name_underscore = "unknown"
  memory = 0
}


require("release.nut")

::ignoreGameUpdate <- ::fileExists(::makeFullPath(::getGameFolder(),"ignoreGameUpdate")) || (parsedCommandLine.argv.indexof("ignoreGameUpdate")!=null)
::expertMode <- ::fileExists(::makeFullPath(::getGameFolder(),"expertMode"))

require("updater_utils.nut")

let circuits = getroottable()?["circuits"]
foreach (i in circuits ?? []) {
  if (::fileExists(::makeFullPath(::getGameFolder(),i?.file ?? "?"))) {
    ::expertMode = true
    if (i?.file!=null)
      pp("expertMode by file =" i.file)
    else
      pp("expertMode by file is skipped")
    ::initialCircuit <- i.value
  }
}

::registry_path <- ::getRegPath()

::develop <- false
if (::fileExists(::makeFullPath(::getGameDir(), "developMode"))) {
  ::develop = true
  pp("develop mode by developMode")
}


::onApplicationExit <- function () {
  return ::saveAllSettings()
}

let getStartupWithWindows = @() ::launcherCONFIG?.startupWithWindowsEnabled ?? true

let function getAutoexecutionDefVal(){
  let result = ::regValueExists(HKEY_CURRENT_USER, ::getRegPath(), "StartupWithWindows")
  if (result)
    ::deleteRegValue(HKEY_CURRENT_USER, ::getRegPath(),"StartupWithWindows")
  return result && getStartupWithWindows()
}

::writeAutoexecution <- function(){
  ::setAutoexecution(::getValue("startup_with_windows", getAutoexecutionDefVal()) && getStartupWithWindows())
}
::saveAllSettingsFuncs <- [::writeAutoexecution]

::saveAllSettings <- function() {
  foreach (func in ::saveAllSettingsFuncs) {
    if(type(func)=="function")
      func()
    if(type(func)=="instance")
      func.save()
  }
  return true
}

::launcher_settings <- null
::launcher_settings_scheme <- {
  //updater_settings
  seeding_on={ type="bool" defVal=true blk="download/seeding_on" }
  UTP={ type="bool" defVal=false blk="download/UTP2" }
  upl_limit={ type="bool" defVal=false  blk="download/upl_limit" }
  dnl_limit={ type="bool" defVal=false  blk="download/dnl_limit" }
  upl_speed_rate={ type="int" defVal=1000  blk="download/upl_speed_rate" }
  rseed={ type="int" defVal=RAND_MAX+1  blk="rdseed"
    getFromBlk=function(blk,desc){
      local value = ::get_blk_int(blk, desc.blk, RAND_MAX+1)
      if (value > RAND_MAX) {
        value = rand()
      }
      return value
    }
    setToBlk=function(blk, desc, val){
      if (val > RAND_MAX) {
        val = rand()
      }
      ::set_blk_int(blk, desc.blk, val)
    }
  }
  dnl_speed_rate={ type="int" defVal=1000  blk="download/dnl_speed_rate" }
  DHT={ type="bool" defVal=true blk="download/DHT" }
  peer_exchange={ type="bool" defVal=true blk="download/peer_exchange" }
  bg_update = { type="bool" defVal=::launcherCONFIG?.bgUpdateInitial ?? true blk=::launcherCONFIG?.backgroundUpdate_prop ?? "launcher/bg_update"
    getFromBlk = function(blk, desc) {
      return ::launcherCONFIG?.bgUpdateEnabled && ::get_blk_bool(blk, desc.blk, ::launcherCONFIG?.bgUpdateInitial ?? true)
    }
    setToBlk = function(blk, desc, val) {
      ::set_blk_bool(blk, desc.blk, val && ::launcherCONFIG?.bgUpdateEnabled)
    }
  }
  bg_tray = { type="bool" defVal=true blk="launcher/bg_tray" }


  //launcher settings
  hide_to_tray_option={ type="bool" defVal=true blk=::launcherCONFIG?.hide_to_tray_prop ?? "launcher/hide_to_tray_option"
    getFromBlk = @(blk, desc) (::launcherCONFIG?.hideToTray ?? true) && ::get_blk_bool(blk, desc.blk, true)
  }
  startup_with_windows={ type="bool" defVal=getAutoexecutionDefVal() blk=::launcherCONFIG?.winstartup_prop ?? "launcher/startup_with_windows"
    getFromBlk = @(blk, desc) getStartupWithWindows() && ::get_blk_bool(blk, desc.blk, getStartupWithWindows())
  }
  enableWebStatus = { type="bool" defVal=false blk="yunetwork/enableWebStatus" }
  webStatusLocalhostOnly = { type="bool" defVal=true blk="yunetwork/webStatusLocalhostOnly" }
  webStatusPort = { type="int" defVal=55444 blk="yunetwork/webStatusPort" }
  curCircuitSel={ type="string" defVal=::initialCircuit  blk=::launcherCONFIG?.curCircuit_prop ?? "yunetwork/curCircuit"
    setToBlk=function(blk, desc, val) {
      local correctVal=false

      if (::expertMode) {
        foreach (i in (getroottable()?["circuits"] ?? []))
          if (val == i.value) {
            correctVal=true
            break
          }
      }

      if (!correctVal && "initialCircuit" in getroottable())
        val = getroottable()?["initialCircuit"]

      ::set_blk_str(blk, desc.blk, val)
    }
  }

  language={ type="string" defVal=::curLanguage blk="language"}
  forcedLauncher={ type="int" defVal=0 blk="forcedLauncher"}
}

local function getCircuitFromConfig(config=null, p={conf = ::launcherCONFIG, def=::curCircuit}){
  let conf = p?.conf ?? ::launcherCONFIG
  let curCircuit_prop = conf?.curCircuit_prop ?? "yunetwork/curCircuit"
  let def = p?.def ?? ::curCircuit ?? ::initialCircuit
  if (config==null)
    config = ::create_and_load_blk(::getConfigPath())
  pp("c =", curCircuit_prop, "::cc =",::curCircuit)
  let configCircuit = ::get_blk_str(config, curCircuit_prop, def)
  pp("cc =", configCircuit)
  return configCircuit
}
::curCircuit = getCircuitFromConfig()

if (!("getCustomCSettings" in getroottable())) {
  ::getCustomCSettings <- function() {
    let conf = ::launcherCONFIG
    let yupproject_prop = conf?.yupproject_prop ?? "yunetwork/yuproject"
    let yutag_prop = conf?.yutag_prop ?? "yunetwork/yutag"
    let expertMode_prop = conf?.expertMode_prop ?? "yunetwork/isExpertMode"
    let confname = ::getConfigPath()
    let config = ::create_and_load_blk(confname)
    let cProject =::get_blk_str(config, yupproject_prop, ::default_yuproject_name)
    local tag = ::default_yutag
    if (::get_blk_bool(config, expertMode_prop, false)) {
      ::expertMode = true
    }
    else if (::expertMode) {
      ::set_blk_bool(config, expertMode_prop, true)
      config.saveToTextFile(confname)
    }
    let selCircuit = getCircuitFromConfig(config,{def = ::curCircuit ?? ::initialCircuit})
    if (selCircuit != ::productionCircuit && ::curCircuit!="") {
      tag = ::curCircuit
      pp("tag set by circuit (" tag ")")
    }
    else {
      pp($"tag set to default {tag} because of production circuit")
    }

    let cTag =::get_blk_str(config, yutag_prop, tag)

    let res = {project=cProject, tag=cTag}
    return res
  }
}
::getYupProject <- function() {

  if (::yupProject.len())
    return ::yupProject

  ::yupProject = ::default_yuproject_name
  let cs = ::getCustomCSettings()
  if (::expertMode)
    ::yupProject = cs.project
  pp("yupProject =", ::yupProject)

  return ::yupProject
}

::getYupResume <- function() {
  let res = concat(::getYupProject() ".yup.resume")
  pp("yupResume = ", res)
  return res
}

::getYupProjectTag <- function() {
  local res = ::default_yutag ?? ""
  let cs = ::getCustomCSettings()
  if (((cs.tag == ::production_rc_tag) && (::curCircuit == ::productionCircuit)) || ::expertMode)
    res = cs.tag
  else
    pp("custom settings are not available")
  pp("yupProjectTag =", res)
  return res
}

let errorsLoadingSettings = Observable([])

let function showError(errors){
  pp("showError", errors)
  if (errors.len() > 0){
    ::display("settings_error", true)
    ::setAttribute("settings_error", "title", ", ".join(errors))
  }
  else{
    ::display("settings_error", false)
    ::setAttribute("settings_error", "title", "<")
  }
}
errorsLoadingSettings.subscribe(showError)

let function addError(e){
  pp("adding error", e)
  errorsLoadingSettings.mutate(@(v) v.append(e))
}

local gameVersionSettingsInitedVersion = null

::initGameVersionSettings <- function(use_default, yup_version) {
  println($"initGameVersionSettings: gameVersionSettingsInitedVersion {gameVersionSettingsInitedVersion}, yup_version = {yup_version}, use_default = {use_default}")
  pp(parsedCommandLine.argv, "parsedCommandLine.argv")
  let dev_folder =  ::makeFullPath(::getGameDir(), ::dev_launcher_settings_path)
  local dev_launcher_settings = ::fileExists(dev_folder) && parsedCommandLine.argv.contains("-devmount")
  const DEV_VERSION = -1
  const FALLBACK_VERSION = -2
  yup_version = dev_launcher_settings ? DEV_VERSION : yup_version

  local loadYupSettingsError = false

  if (gameVersionSettingsInitedVersion == yup_version)
    return

  if (dev_launcher_settings) {
    pp("Try to use dev settings")

    let mountRes = ::mountDir(::launchersettings_mount_path, dev_folder)
    pp("mountDir res:", mountRes)

    if (mountRes && ::yup_settings_script_path) {
      let devPath = concat(::launchersettings_mount_path, "/", ::yup_settings_script_path)

      try {
        require(devPath)
        gameVersionSettingsInitedVersion = DEV_VERSION
        return
      }
      catch (e) {
        loadYupSettingsError = true
        pp($"error loading script, {devPath}\n{e}")
        addError("error loading dev settings")
      }
    }
    else {
      dev_launcher_settings = false
    }
    pp("No dev settings")
  }

  if (!use_default && !dev_launcher_settings && ::yup_settings_script_path) {
    pp("Try to use in-yup settings")

    let inYupPath = concat(::launchersettings_mount_path, "/", ::yup_settings_script_path)

    try {
      require(inYupPath)
      gameVersionSettingsInitedVersion = yup_version
    }
    catch (e) {
      loadYupSettingsError = true
      pp($"{inYupPath}, error loading script\n{e}")
      addError("error loading yup settings")
    }

    pp("No in-yup settings")
  }

  if ((use_default || loadYupSettingsError) && "obsolete_settings_script" in getroottable()) {
    pp("Try to use default (possible obsolete) settings")
    let obsolete_settings_script = getroottable()["obsolete_settings_script"] ?? "_undefined"
    try {
      require(obsolete_settings_script)
      gameVersionSettingsInitedVersion = FALLBACK_VERSION
      return
    }
    catch (e) {
      pp($"error loading script, {obsolete_settings_script}\n{e}")
      addError("error loading fallback settings")
    }
  }
  pp("Launcher settings not initialized any way")
}


::onYupLauncherSettings <- function(result) {
  pp("yup launcher_settings section mount:", result ? "SUCCESS" : "FAILED")
  let yup_version = ::getLocalGameVersion(::getGameFolder(), ::getYupProject()) ?? "0"
  ::initGameVersionSettings(!result, yup_version)
}


let function onPromoPluginReady(mount_result) {
  ::promoPluginMountResult = mount_result

  local resStr = "failed"

  switch (mount_result) {
    case MOUNT_LOCAL:
      resStr = "used local"
      break;
    case MOUNT_UPDATE:
      resStr = "updated"
      break;
  }

  pp(::promoPluginId "plugin" resStr);

  if (mount_result != MOUNT_FAIL) {
    try {
      require(::promo_script_path)
    }
    catch(e) {
      pp($"Promo script error\n{e}")
    }
  }
}


let on3SecFuncsOnLauncherRestart = [
  ::saveAllSettings
]
let on3SecFuncs = [] // is it used???


::on3SecTick <- function() {
  if (::isLauncherRestartNeeded()) {
    foreach (func in on3SecFuncsOnLauncherRestart)
      func()
    ::restartLauncher()
  } else {
    foreach (func in on3SecFuncs)
      func()
  }

  let startapp = ::launcherCONFIG?.usingStartapp ?? false

  if (startapp && ::launcherHasUpdate())
    ::display("launcher_update", true);

  // auto unpause download after 30 minutes
  if (::paused && ::getTimeDiff(false) > 1800)
    ::pauseBtnMouseDown()

  if (::runGameEpicBlock && ::isEpicLoggedIn()) {
    ::runGameEpicBlock = false
    ::tryShowRunGame()
  }
}


let function setLanguageSpecificBg() {
  let geo = ::getSystemLocation()
  if (geo in ::bgImagesMap)
    ::setStyleAttribute("default_background", "background-image", concat("url(", ::bgImagesMap[geo],")"))
}

let defaultprojectSpecificUrls = {launcherid=curLauncherId, yupproject=::yupProject, yutag=null}
let function setProjectSpecificUrls(params) {
  let launcherid = params?.launcherid ?? defaultprojectSpecificUrls.launcherid
  let yupproject = params?.yupproject ?? defaultprojectSpecificUrls.yupproject
  let yutag = params?.yutag ?? ::getYupProjectTag() ?? ""
  ::setAttribute("latest_launcher_url","href", $"{getYupmasterUrl()}/launcher/current.php?id={launcherid}")
  ::setAttribute("torrent_url","href", $"{getYupmasterUrl()}/yuitem/current_yup.php?project={yupproject}&torrent=1&tag={yutag}")
}

let function setCircuitsHtml(){
  let cirselct = select({id="curCircuitSel" size="1" onChange="onCircuitChange" value=::initialCircuit options=(getroottable()?["circuits"] ?? [])})
  let circuits_html =  concat("<div id='server_option'>", cirselct, "</div>")
  ::setHtml("server_option", circuits_html)
}

let function setProjectStyle() {
  foreach (obj, o in (getroottable()?["style"] ?? {})) {
    if (type(o) == "function") {
      ::setHtml(obj, o())
      continue
    }
    else if (type(o) != "table") {
      pp("incorrect config type for style object:" type(o))
      continue
    }
    foreach (prop, val in o)
      ::setStyleAttribute(obj, prop, val)
  }
}


let function setSocialNetworks(lang){
  let systemLocation = ::getSystemLocation()

  let function img(src){return $"<img src='{src}' width=32 height=32 style='margin-right:3dip'>"}
  let function handleImage(v) {
    if (v) {
      local skip = false
      if (v?.restrictedRegions)
        skip = v.restrictedRegions.contains(systemLocation)

      if (!skip)
        return he("a", {class_="eh", href=unpack(v?.url,"")}, img(unpack(v?.img,"")))
    }

    return ""
  }
  local function buildHtmlImages(links) {
    links = links.map(handleImage)
    links = links.reduce(@(a,b) a+b)
    pp("imagelinks", links)
    return links ?? ""
  }
  let gLinks = getroottable()?["links"]
  if (!gLinks)
    return
  local links = gLinks?.icons?[lang] ?? gLinks?.icons?.def ?? []
  links = buildHtmlImages(links)
  let html = he("div",{}, links)
  ::setHtml("social", html)
}

let function setTextLinks(lang){
  let function span(obj){
    return he("a",{class_="eh" id=unpack(obj?.id,"") style="margin:0dip 30dip 0dip 0dip;padding:0;text-align:left;" href=unpack(obj?.url,"")},unpack(obj?.text, ""))
  }
  local function buildHtmlText(links){
    links = links.map(@(v) v!=null ? span(v) : "")
    links = links.reduce(@(a,b) a+b)
    pp("textlinks",links)
    links = links ?? ""
    links =concat(links, "<span id='launcher_upd_error' style='color:red; visibility:hidden; min-width:0dip;width:100%'>",
      loc("error/launcher_update"),
      "</span>")
    return links
  }
  let gLinks = getroottable()?["links"]
  if (!gLinks)
    return
  local links = gLinks?.text?[lang] ?? gLinks?.text?.def ?? []
  links = buildHtmlText(links)
  ::setHtml("text_link_holder", links)
}

let function setProjectLanguagesHtml(){
  let confname = ::getConfigPath()
  let config = ::create_and_load_blk(confname)
  let lang =::get_blk_str(config, "language", ::supported_languages?[0]?.value ?? "English")
  local langIsCustom = true
  let supportedlangs = clone ::supported_languages
  foreach (l in supportedlangs){
    if (l?.value == lang) {
      langIsCustom = false
      break
    }
  }
  if (langIsCustom)
    supportedlangs.append({value=lang, text=lang, img="img/flags/earth.png"})

  let function build_opt(lng){
    return lng.__merge({
      text = "".concat(he("img",{src=lng?.img, style="vertical-align:middle; width:32dip;height:18dip;"}), lng?.text ?? lng.value)
    })
  }
  let options = supportedlangs.map(build_opt)
  let langselect = select({id="language" size="1" onChange="langChanged" options=options value=options?[0]?.value})
  let lang_holder = he("div", {id="lang_holder" style="position:fixed;right:164dip;top:-2dip;margin:0dip"}, langselect)
  ::setHtml("lang_holder", lang_holder)
}


let function onGpuInfo(name, memory) {
  ::gpuInfo.name = name
  ::gpuInfo.memory = memory
  ::gpuInfo.name_underscore = ::getGpuNameUnderscore()
}


let function disableSeedingForNonProduction() {
  if (::curCircuit != ::productionCircuit) {
    ::setValue("DHT", false) //DHT off
    ::disable("DHT")
    ::setDHT(false)

    ::setValue("seeding_on", false) //Seeding off
    ::disable("seeding_on")
  }
}


::onWindowCreated <- function() {
  pp("onWindowCreated")

  getroottable()?["windowCreatedCallback"]?()

  local dmmLock = false

  if ("DMMFile" in getroottable()) {
    dmmLock = ::fileExists(::makeFullPath(::getGameFolder(), getroottable()["DMMFile"]))

    if (dmmLock)
      println("DMM lock on")
  }

  ::setCaption(loc("header"))
  setCircuitsHtml()
  setLanguageSpecificBg()
  setProjectSpecificUrls({launcherid=curLauncherId, yupproject=::getYupProject(), yutag=::getYupProjectTag()})
  setProjectLanguagesHtml()
  setSocialNetworks(dmmLock ? "DMM" : ::curLanguage)
  setTextLinks(dmmLock ? "DMM" : ::curLanguage)
  setProjectStyle()

  ::launcher_settings = ::Settings(::getConfigPath(), ::launcher_settings_scheme)
  ::launcher_settings.updateGui()
  ::saveAllSettingsFuncs.append(::launcher_settings)

  if (::isBackground() && ::isChecked("bg_tray"))
    ::setRunMinimizedToTray(true)
  if (::isLauncherFirstRun && ("getGpuInfo" in getroottable()))
    ::getGpuInfo(onGpuInfo)

  ::curCircuit = ::getValue("curCircuitSel") ?? ::productionCircuit
  disableSeedingForNonProduction()

  if (getroottable()?["usePromo"] && getroottable()?["promo_plugin"])
    ::mountPlugin(getroottable()?["promo_plugin"], ::promoPluginId, true, onPromoPluginReady);

  if (platformMac || platformLinux) {
    if (platformMac) {
      ::display("dnl_limit_container", false)
      ::display("upl_limit_container", false)
    }

    ::display("collect_info", false)
    ::display("shell_options", false)
    ::display("hide_window_btn", false)
    ::display("close_window_btn", false)
  }

  ::onSeedingChange()
}

let function getCircuitDescrByVal(value){
  foreach (c in (getroottable()?["circuits"] ?? [])){
    if (c?.value==value)
      return c
  }
  return {}
}


::isFirstRun <- function() {
  return ::launcher_settings.data.getBool("firstRun", false)
}


::onInitComplete <- function() {
  errorsLoadingSettings.trigger()
  pp("onInitComplete script")
  print_file_to_debug(::getConfigPath())

  if (platformWindows)
    println("Running under Windows")
  else if (platformMac)
    println("Running under MacOS")
  else if (platformLinux)
    println("Running under Linux")
  else
    println("Running under unknown platform")

  ::appStats.onFirstRun()

  local register_url = loc("register_url")

  if (::is_launched_from_steam()) {
    register_url = loc("register_url_steam")
    ::display("url_direct", false)
    ::display("url_gold", false)

    //If requested, hide Register link with "steam" Partner ID in URL
    if (::launcherCONFIG?.noRegisterUnderSteam)
      ::display("signup_link", false)
  }

  ::setHtml("signup_link",
    concat($"<a class='eh' href='{register_url}'>", loc("signup"), "</a>")
  )

  ::setValue("language", ::curLanguage)

  let gameFolder = ::getGameFolder()

  ::yupSectionZipHandler(gameFolder, ::getYupProject(),
    ::launchersettings_yup_section, ::launchersettings_mount_path, ::onYupLauncherSettings)

  let logsToClean = [ //path, max age in days, max count in folder, max size in MB
    [::makeFullPath(gameFolder, ".launcher_log"), 30, 100, 50],
    [::makeFullPath(gameFolder, "_debuginfo"), 30, 100, 1000],
    [::makeFullPath(gameFolder, ".game_logs"), 30, 100, 1000]
  ]

  ::cleanupLogs(logsToClean)

  if (::expertMode) {
    ::display("curCircuitSel", true)
    ::display("server_option", true)
  }
  else {
    ::display("server_option", false)
    ::display("curCircuitSel", false)
    ::setValue("curCircuitSel", ::productionCircuit)
  }

  let circuitDescr = getCircuitDescrByVal(::curCircuit)
  foreach (c in (getroottable()?["circuits"] ?? [])){
    if (c?.id != ::curCircuit && c?.id != null && (c?.showOnlyWhenSet || c?.showOnlyOnIgnoreUpdate))
      ::display(c.id, false)
  }
  if (::ignoreGameUpdate && circuitDescr?.showOnlyOnIgnoreUpdate && circuitDescr?.id != null) //fixme: make it data driven
    ::display(circuitDescr.id, true)

  if (::getUninstallGameFlag()) {
    ::uninstall()
    return
  }

  ::pingHostAsync("seeder.gaijin.lan", ::onSeederGaijinLanPing)

  pp("onInit: curCircuit =" ::curCircuit)
  pp("onInit: productionCircuit =" getroottable()?["productionCircuit"])

  pp("Windows XP ="::isWindowsXP())
  pp("SSE 4.1  =" ::haveSSE41())
  pp("Windows64  =" ::isWindows64())
  if (::isWindows64() && !::isWindowsXP() && ::haveSSE41()) {
    pp("Running under SSE4.1 64-bit Windows Vista+")
    ::display("WIN32_DESC", true)
  }
  else
    pp("Running under 32-bit Windows or WindowsXP or no SSE4.1")

  ::setDownloadParams()
  ::setupCDN(gameFolder, ::getYupProject(), ::getYupProjectTag(), ::onCDNSettings)

  pp("onInit: yupTag")
  if (((::curCircuit != getroottable()?["productionCircuit"]) && (::curCircuit != "")) && (::curCircuit != "test") &&
    (::curCircuit != "experimental"))
      ::forceAddPeer("seedrus-dev.gaijinent.com", 27032)

  if (!::isChecked("bg_update") && !::bgUpdateWasUsed() && (::launcherCONFIG?.bgUpdateEnabled ?? true)) {
    ::check("bg_update")
    ::display("bg_update_forced", true)
  }

  ::configureBgUpdate(::isChecked("bg_update") && (::launcherCONFIG?.bgUpdateEnabled ?? true))

  ::setGameVersion()

  let rqPath = ::makeFullPath(gameFolder, concat("content/pkg_", ::curLanguage, ".rq2"))
  ::saveFile(rqPath, "1")

  ::enableContentPacks(gameFolder, ::getYupProject())

  let clean = ["*.exe", "*.dll", "riDesc.bin"]
  let cleanIgnore = ["launcher*.exe", "updater*.exe", "gjagent*.exe",
    "gaijin_downloader.exe", "bpreport.exe", "unins*.exe",
    "sciter.dll", "dbghelp.dll", "WarThunderCDK", "pkg_user", "pkg_local",
    "EOSSDK-Win32-Shipping.dll",
    "cef/cefprocess.exe", "cef/chrome_elf.dll", "cef/d3dcompiler_43.dll", "cef/d3dcompiler_47.dll",
    "cef/libcef.dll", "cef/libEGL.dll", "cef/libGLESv2.dll"]

  ::addCleanupMask(gameFolder, ::getYupProject(), clean)
  ::addCleanupIgnoreMask(gameFolder, ::getYupProject(), cleanIgnore)
  let newsUrl = getroottable()?["newsUrl"]
  let newsEnabled = getroottable()?["newsEnabled"]
  if (newsUrl) {
    local newsurl = unpack(newsUrl,{def=""})
    newsurl = unpack(newsurl?[::curLanguage] ?? newsurl?.def, "")
    pp("newsurl", newsurl)
    if (newsEnabled)
      ::getGameNews(newsurl, ::onNewsReady)
    else
      ::setHtml("news_holder", "<div></div>")
  }

  if (::selfUpdateFallback()) {
    if (::fileExists(::makeFullPath(gameFolder, "ignoreLauncherUpdate")) || parsedCommandLine.argv.indexof("ignoreLauncherUpdate")!=null)
      ::doCheckLauncherUpdates(true)
    else
      ::doCheckLauncherUpdates(false)
  }
  else
    ::doCheckLauncherUpdates(true)

  if (::develop)
    ::tryShowRunGame()
  ::launcherCONFIG?.onInitComplete()
}


::onSeederGaijinLanPing <- function(ping_ok) {
  ::seederGaijinLanPing = ping_ok
  if (::seederGaijinLanPing) {
    ::forceHttpSeed("http://seeder.gaijin.lan/content/")
    ::forceAddPeer("seeder.gaijin.lan", 27032)
  }
}


::onCDNSettings <- function(params) {
  if (!params.len()){
   //Set up default params
    pp("Default CDN settings used")

    params["tracker_0"] <- ::trackerUrl
    params["tracker_1"] <- ::retrackerUrl
    params["min_speed"] <- 4194304
    params["good_speed"] <- 8388608
  }

  if (::seederGaijinLanPing) {
    params["min_speed"] <- 8500000
    params["good_speed"] <- 17000000

    local key = ""

    for (local i = 0; ; ++i) {
      key = "local_tracker_{0}".subst(i)

      if (!params.rawin(key)) {
        params[key] <- ::devTrackerUrl
        break
      }
    }
  }

  return params
}

::langChanged <- function() {
  let lang = ::getValue("language", ::curLanguage)
  if (lang != null) {
    pp("language changed to", lang)
    ::setLanguage(lang)
  }
  ::saveAllSettings()
  ::restartLauncher()
}

::onCircuitChange <- function() {
  let msg = loc("error/donot_change_circuit")

  if (::curCircuit == ::productionCircuit)
    if (!::questMessage(msg, "")) {
      ::curCircuit = ::productionCircuit
      ::setValue("curCircuitSel", ::curCircuit)
      return
    }
  ::setValue("isExpertMode", true)
  ::saveAllSettings()
  ::restartLauncher()
}

::settings_states <- ["news_holder", "social", "banner", "common_front_settings", "bottom_panel", "settings_dialog", "l_settings_dialog"]
::settings_close_states <- ["news_holder", "social", "banner", "common_front_settings", "bottom_panel"]

local cur_settings_state = "news_holder"

let function set_settings_state(state) {
  let st = type(state) == "array" ? state : [state]
  local stSet = false

  foreach (i in ::settings_states) {
    if (st.contains(i)) {
      ::display(i, true)

      if (!stSet) {
        cur_settings_state = i
        stSet = true
      }
    }
    else
      ::display(i, false)
  }
}

::toggle_settings <- function() {
  if (cur_settings_state == "settings_dialog")
    set_settings_state(::settings_close_states)
  else
    set_settings_state("settings_dialog")
}

::toggle_l_settings <- function() {
  if (cur_settings_state == "l_settings_dialog")
    set_settings_state(::settings_close_states)
  else
    set_settings_state("l_settings_dialog")
}
::open_settings <- function(){set_settings_state("settings_dialog")}
::open_l_settings <- function(){set_settings_state("l_settings_dialog")}
::close_settings <- function() {set_settings_state(::settings_close_states)}
::close_l_settings <- function() {set_settings_state(::settings_close_states)}
::close_bg_update_forced_info <- function() {::display("bg_update_forced",false)}
::close_bg_update_forced_info_and_toggle_l_settings <- function(){::close_bg_update_forced_info(); ::toggle_l_settings()}


::onBgUpdateConfigured <- function(_success) {
  ::enable("bg_update")
}

::emptyCallback <- function() {}


::configureBgUpdate <- function(turn_on, cb = ::onBgUpdateConfigured) {
  ::disable("bg_update")

  if (turn_on)
    ::enableBgUpdate(true, ::getGameFolder(), ::getYupProject(), ::getYupProjectTag(), ::curLanguage, cb)
  else
    ::enableBgUpdate(false, ::getGameFolder(), "", "", ::curLanguage, cb)

}

::onBgUpdateSwitch <- function(){
  ::configureBgUpdate(::isChecked("bg_update"))
}


::onCheckFiles <- function() {
  ::resetFastCheckResult(::getGameFolder(), ::getYupProject())
  ::doDownloadFiles()
  ::close_settings()
}


::onCollectInfo <- function(){
  let cinfo = require("collect_info_for_support.nut")
  cinfo.main(cinfo.what_to_gather)
}


::setVideoModes <- function(sel_id, min_w, min_h) {
  let res = ::getResolutions(min_w, min_h)
  let opt = ["<option value='auto'>{0}</option>".subst(loc("auto"))]

  foreach (mode in res)
    opt.append("<option value='{0}'>{0}</option>".subst(mode))

  ::setHtml(sel_id, "".join(opt))
}
::getVideoModes <- ::setVideoModes //backward compatibilty

if (getroottable()?.__argv != null && ::__argv.contains("-test") && ::yup_settings_script_path) {
  //offline tests for bs & csq
  require("/".concat("_scilauncher2_settings", ::yup_settings_script_path))
  if (getroottable()?["obsolete_settings_script"] != null)
    require(getroottable()?["obsolete_settings_script"])
  let g_promo_script_path = getroottable()?["promo_script_path"]
  if (g_promo_script_path != null) {
    try{
      require(g_promo_script_path)
    }
    catch(e){
      println(e)
      println($"promo file '{g_promo_script_path}' haven't loaded correctly!")
    }
  }
}
