import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/fileDialog/saveDataDialog.nut" import SaveDataDialog
from "%sqstd/platform.nut" import isSony, isXbox
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/controls/controlsState.nut" import isPresetChanged
from "%scripts/utils/nativeRequests.nut" import mkNativeResultReceiver
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

let { request_load_controls_backup = @(...) 0, request_save_controls_backup= @(...) 0, request_delete_controls_backup= @(...) 0, request_list_controls_backup= @(...) 0 } = require("controls")


const BACKUP_RESULT_EVENT = "controlsBackupResult"
let onBackupResult = mkNativeResultReceiver(BACKUP_RESULT_EVENT)

let ControlsBackupManager = class (SaveDataDialog) {
  function initScreen() {
    if (!this.isAvailable())
      return

    this.getSaveDataContents = @(cb) onBackupResult(request_list_controls_backup(BACKUP_RESULT_EVENT), cb)
    base.initScreen()
  }


  function doSave(descr) {
    this.showWaitAnimation(true)
    let blk = DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    onBackupResult(request_save_controls_backup(BACKUP_RESULT_EVENT, blk), Callback(this.onBackupSaved, this))
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

    onBackupResult(request_load_controls_backup(BACKUP_RESULT_EVENT, blk), Callback(this.onBackupLoaded, this))
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

    onBackupResult(request_delete_controls_backup(BACKUP_RESULT_EVENT, blk), Callback(this.onBackupDeleted, this))
  }


  function onBackupDeleted(_params) {
    this.showWaitAnimation(false)
    this.requestEntries()
  }


  static function isAvailable() {
    return (isSony || isXbox) && request_list_controls_backup != null
  }


  static function open() {
    loadHandler(get_gui_handler("ControlsBackupManager"))
  }
}
register_gui_handler("ControlsBackupManager", ControlsBackupManager)

return freeze({ ControlsBackupManager })
