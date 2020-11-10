local elemModelType = require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")

const HIDE_STAT_TIME_SEC = 1
const HIDE_STAT_WITH_FAILED_TIME_SEC = 10

getroottable().on_show_dldata_stat <- function(stat)    //called from native code
{
  elemModelType.DL_DATA_STATE.updateStat(stat)
}

elemModelType.addTypes({
  DL_DATA_STATE = {
    displayStatTimer = -1
    prevStat = null
    curStat = null
    statText = null

    needShowStat = @() curStat != null

    updateStat = function(newStat)
    {
      curStat = newStat
      statText = null

      if (curStat?.filesInFlight == 0)
      {
        local displayStatTimeSec = ((curStat?.filesFailed ?? 0) - (prevStat?.filesFailed ?? 0) > 0)
          ? HIDE_STAT_WITH_FAILED_TIME_SEC
          : HIDE_STAT_TIME_SEC
        refreshDisplayStat(displayStatTimeSec)
      }

      notify([])
    }

    getLocText = function()
    {
      if (statText)
        return statText

      local inFlightText = ::loc("loadDlDataStat/inFlight",
        { filesInFlight = curStat?.filesInFlight ?? 0
          filesInFlightSizeKB = curStat?.filesInFlightSizeKB ?? 0 })

      local failedText = ""
      local filesFailed = (curStat?.filesFailed ?? 0) - (prevStat?.filesFailed ?? 0)
      local filesFailedSizeKB = (curStat?.filesFailedSizeKB ?? 0) - (prevStat?.filesFailedSizeKB ?? 0)
      if (filesFailed > 0)
        failedText = ::loc("ui/comma") +
          ::colorize("badTextColor", ::loc("loadDlDataStat/failed",
          { filesFailed = filesFailed
            filesFailedSizeKB = filesFailedSizeKB }))

      statText = inFlightText + failedText
      return statText
    }

    refreshDisplayStat = function(timeSec)
    {
      removeDisplayStatTimer()
      displayStatTimer = ::periodic_task_register( this,
        updateDisplayStat, timeSec )
    }

    removeDisplayStatTimer = function()
    {
      if ( displayStatTimer >= 0 )
      {
        ::periodic_task_unregister( displayStatTimer )
        displayStatTimer = -1
      }
    }

    updateDisplayStat = function(dt = 0)
    {
      removeDisplayStatTimer()
      prevStat = curStat
      curStat = null
      statText = null
      notify([])
    }
  }
})

elemViewType.addTypes({
  DL_DATA_STATE_TEXT = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, params)
    {
      local needShowStat = model.needShowStat()
      local objAnimText = obj.getChild(0)
      objAnimText.fade = needShowStat ? "in" : "out"

      if (!needShowStat)
        return

      objAnimText.setValue(model.getLocText())
    }
  }

  DL_DATA_WAIT_MSG = {
    model = elemModelType.DL_DATA_STATE

    updateView = function(obj, params)
    {
      obj.fade = ((model.curStat?.filesInFlight ?? 0) !=0) ? "in" : "out"
    }
  }
})

return {
}