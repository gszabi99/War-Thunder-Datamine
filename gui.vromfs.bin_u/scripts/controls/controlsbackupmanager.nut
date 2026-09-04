import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

let { request_load_controls_backup = @(...) null, request_save_controls_backup= @(...) null, request_delete_controls_backup= @(...) null, request_list_controls_backup= @(...) null } = require("controls")

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { SaveDataDialog } = require("%scripts/fileDialog/saveDataDialog.nut")
let { isPlatformSony, isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isPresetChanged } = require("%scripts/controls/controlsState.nut")

let ControlsBackupManager = class (SaveDataDialog) {
  function initScreen() {
    if (!this.isAvailable())
      return

    this.getSaveDataContents = request_list_controls_backup
    base.initScreen()
  }


  function doSave(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    let cb = Callback(this.onBackupSaved, this)
    request_save_controls_backup(@(result) cb(result), blk)
  }


  function onBackupSaved(params) {
    this.showWaitAnimation(false)
    if (!params.success)
      showInfoMsgBox(loc("msgbox/errorSavingPreset"))
    this.goBack()
  }


  function doLoad(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    let cb = Callback(this.onBackupLoaded, this)
    request_load_controls_backup(@(result) cb(result), blk)
  }


  function onBackupLoaded(params) {
    this.showWaitAnimation(false)
    if (params.success) {
      isPresetChanged.set(true)
      broadcastEvent("ControlsPresetChanged")
    }
    else
      showInfoMsgBox(loc("msgbox/errorSavingPreset"))
    this.goBack()
  }


  function doDelete(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    let cb = Callback(this.onBackupDeleted, this)
    request_delete_controls_backup(@(result) cb(result), blk)
  }


  function onBackupDeleted(_params) {
    this.showWaitAnimation(false)
    this.requestEntries()
  }


  static function isAvailable() {
    return (isPlatformSony || isPlatformXbox) && request_list_controls_backup != null
  }


  static function open() {
    loadHandler(get_gui_handler("ControlsBackupManager"))
  }
}
register_gui_handler("ControlsBackupManager", ControlsBackupManager)

return { ControlsBackupManager }
