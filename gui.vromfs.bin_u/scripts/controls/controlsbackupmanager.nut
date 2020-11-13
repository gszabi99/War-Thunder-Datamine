local DataBlock = require("DataBlock")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

class ::gui_handlers.ControlsBackupManager extends ::gui_handlers.SaveDataDialog
{
  function initScreen()
  {
    if (!isAvailable())
      return

    getSaveDataContents = ::request_list_controls_backup
    base.initScreen()
  }


  function doSave(descr)
  {
    showWaitAnimation(true)
    local blk = DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    local cb = ::Callback(onBackupSaved, this)
    ::request_save_controls_backup(@(result) cb(result), blk)
  }


  function onBackupSaved(params)
  {
    showWaitAnimation(false)
    if (!params.success)
      ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
    goBack()
  }


  function doLoad(descr)
  {
    showWaitAnimation(true)
    local blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    local cb = ::Callback(onBackupLoaded, this)
    ::request_load_controls_backup(@(result) cb(result), blk)
  }


  function onBackupLoaded(params)
  {
    showWaitAnimation(false)
    if (params.success)
    {
      ::preset_changed = true
      ::broadcastEvent("PresetChanged")
    }
    else
      ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
    goBack()
  }


  function doDelete(descr)
  {
    showWaitAnimation(true)
    local blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    local cb = ::Callback(onBackupDeleted, this)
    ::request_delete_controls_backup(@(result) cb(result), blk)
  }


  function onBackupDeleted(params)
  {
    showWaitAnimation(false)
    requestEntries()
  }


  static function isAvailable()
  {
    return (isPlatformSony || isPlatformXboxOne) && "request_list_controls_backup" in ::getroottable()
  }


  static function open()
  {
    ::handlersManager.loadHandler(::gui_handlers.ControlsBackupManager)
  }
}
