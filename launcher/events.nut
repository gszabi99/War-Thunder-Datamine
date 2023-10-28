let function log(...){
  ::debug(" ".join(vargv))
}

let class AppStats {
  active = false

  statsUrl = "https://launcher-bq.gaijin.net/launcher"

  confPath = null
  appName = null
  distr = null

  events = { //Don't forget to init all these values in setup.iss
    firstRun = { send=false, order=2, name="first_run" }
    firstYup = { send=false, order=3, name="first_yup_downloaded" }
    firstDownload = { send=false, order=4, name="first_download_started" }
    firstDownloaded = { send=false, order=5, name="first_download_done" }
    firstGameShow = { send=false, order=6, name="first_game_run_enabled" }
    firstGameRun = { send=false, order=7, name="first_game_run" }
  }

  constructor(path, app_name) {
    this.confPath = path
    this.appName = app_name

    let blk = ::create_and_load_blk(this.confPath)

    foreach (id, evt in this.events) {
      let send = blk.getBool(id, evt.send)

      this.events[id].send = send

      if (send)
        this.active = true
    }

    if (!this.active)
      log("No pending events")

    local distrDef = "0000000001"

    if (platformMac)
      distrDef = (::is_launched_from_steam() ? "00000StMac" : "0000000Mac")
    else if (platformLinux)
      distrDef = (::is_launched_from_steam() ? "000StLinux" : "00000Linux")
    else if (::is_launched_from_steam())
      distrDef = "0000000003"

    this.distr = blk.getStr("distr", distrDef)
  }

  function onFirstRun() {
    this.onBqEvent("firstRun")
  }

  function onFirstYup() {
    this.onBqEvent("firstYup")
  }

  function onFirstDownload() {
    this.onBqEvent("firstDownload")
  }

  function onFirstDownloadComplete() {
    this.onBqEvent("firstDownloaded")
  }

  function onGameRunShown() {
    this.onBqEvent("firstGameShow")
  }

  function onGameRun() {
    this.onBqEvent("firstGameRun", true)
  }


  function sendEvent(name, sync = false) {
    if (!this.active)
      return

    let json = { event=name, distr=this.distr, app=this.appName }

    log("Sent event" name)

    this.sendJson(json, sync);
  }

  function sendJson(json, sync) {
    if (sync)
      ::httpPostJsonSync(this.statsUrl, json, null)
    else
      ::httpPostJson(this.statsUrl, json, null)
  }


  function onBqEvent(name, sync = false) {
    if (!this.active)
      return

    if (this.events[name].send) {
      if (this.dropConfigFlag(name))
        this.events[name].send = false

      foreach (id, evt in this.events)
        if (evt.send && evt.order < this.events[name].order) {
          this.dropConfigFlag(id)

          this.events[id].send = false

          log("Event" evt.name "cancelled due to next" this.events[name].name)
        }

      this.sendEvent(this.events[name].name, sync)
    }
  }


  function dropConfigFlag(name) {
    let blk = ::create_and_load_blk_only_if_exist(this.confPath)

    if (blk) {
      blk.setBool(name, false);
      return blk.saveToTextFile(this.confPath)
    }

    return false
  }
}

::appStats <- AppStats(::getConfigPath(), ::launcherCONFIG?.appName ?? "Unknown")
