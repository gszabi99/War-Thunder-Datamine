from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")

const HIDE_STAT_TIME_SEC = 1
const HIDE_STAT_WITH_FAILED_TIME_SEC = 10

::on_show_dldata_stat <- function(stat)    //called from native code
{
  elemModelType.DL_DATA_STATE.updateStat(stat)
}

elemModelType.addTypes({
  DL_DATA_STATE = {
    displayStatTimer = -1
    prevStat = null
    curStat = null
    statText = null

    needShowStat = @() this.curStat != null

    updateStat = function(newStat)
    {
      this.curStat = newStat
      this.statText = null

      if (this.curStat?.filesInFlight == 0)
      {
        let delayed = this.curStat?.filesDelayed ?? 0
        let displayStatTimeSec = ((this.curStat?.filesFailed ?? 0) - (this.prevStat?.filesFailed ?? 0) > 0) && delayed > 0
          ? HIDE_STAT_WITH_FAILED_TIME_SEC
          : HIDE_STAT_TIME_SEC
        this.refreshDisplayStat(displayStatTimeSec)
      }

      this.notify([])
    }

    getLocText = function()
    {
      if (this.statText)
        return this.statText

      let inFlightText = loc("loadDlDataStat/inFlight",
        { filesInFlight = this.curStat?.filesInFlight ?? 0
          filesInFlightSizeKB = this.curStat?.filesInFlightSizeKB ?? 0 })

      local delayedText = ""
      let filesDelayed = this.curStat?.filesDelayed ?? 0
      if (filesDelayed > 0)
        delayedText = loc("ui/comma") +
          colorize("newTextBrightColor", loc("loadDlDataStat/delayed",
          { filesDelayed = filesDelayed
            filesDelayedSizeKB = this.curStat?.filesDelayedSizeKB ?? 0 }))


      local failedText = ""
      let filesFailed = (this.curStat?.filesFailed ?? 0) - (this.prevStat?.filesFailed ?? 0)
      let filesFailedSizeKB = (this.curStat?.filesFailedSizeKB ?? 0) - (this.prevStat?.filesFailedSizeKB ?? 0)
      if (filesFailed > 0)
        failedText = loc("ui/comma") +
          colorize("badTextColor", loc("loadDlDataStat/failed",
          { filesFailed, filesFailedSizeKB }))

      this.statText = inFlightText + delayedText + failedText
      return this.statText
    }

    refreshDisplayStat = function(timeSec)
    {
      this.removeDisplayStatTimer()
      this.displayStatTimer = ::periodic_task_register( this,
        this.updateDisplayStat, timeSec )
    }

    removeDisplayStatTimer = function()
    {
      if ( this.displayStatTimer >= 0 )
      {
        ::periodic_task_unregister( this.displayStatTimer )
        this.displayStatTimer = -1
      }
    }

    updateDisplayStat = function(_dt = 0)
    {
      this.removeDisplayStatTimer()
      this.prevStat = this.curStat
      this.curStat = null
      this.statText = null
      this.notify([])
    }
  }
})

elemViewType.addTypes({
  DL_DATA_STATE_TEXT = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, _params)
    {
      let needShowStat = this.model.needShowStat()
      let objAnimText = obj.getChild(0)
      objAnimText.fade = needShowStat ? "in" : "out"

      if (!needShowStat)
        return

      objAnimText.setValue(this.model.getLocText())
    }
  }

  DL_DATA_WAIT_MSG = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, _params)
    {
      obj.fade = ((this.model.curStat?.filesInFlight ?? 0) !=0) ? "in" : "out"
    }
  }
})

return {
}