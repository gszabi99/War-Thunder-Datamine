//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

::gui_handlers.ControlsBackupManager <- class extends ::gui_handlers.SaveDataDialog {
  function initScreen() {
    if (!this.isAvailable())
      return

    this.getSaveDataContents = ::request_list_controls_backup
    base.initScreen()
  }


  function doSave(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    let cb = Callback(this.onBackupSaved, this)
    ::request_save_controls_backup(@(result) cb(result), blk)
  }


  function onBackupSaved(params) {
    this.showWaitAnimation(false)
    if (!params.success)
      ::showInfoMsgBox(loc("msgbox/errorSavingPreset"))
    this.goBack()
  }


  function doLoad(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    let cb = Callback(this.onBackupLoaded, this)
    ::request_load_controls_backup(@(result) cb(result), blk)
  }


  function onBackupLoaded(params) {
    this.showWaitAnimation(false)
    if (params.success) {
      ::preset_changed = true
      ::broadcastEvent("ControlsPresetChanged")
    }
    else
      ::showInfoMsgBox(loc("msgbox/errorSavingPreset"))
    this.goBack()
  }


  function doDelete(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    let cb = Callback(this.onBackupDeleted, this)
    ::request_delete_controls_backup(@(result) cb(result), blk)
  }


  function onBackupDeleted(_params) {
    this.showWaitAnimation(false)
    this.requestEntries()
  }


  static function isAvailable() {
    return (isPlatformSony || isPlatformXboxOne) && "request_list_controls_backup" in getroottable()
  }


  static function open() {
    ::handlersManager.loadHandler(::gui_handlers.ControlsBackupManager)
  }
}
