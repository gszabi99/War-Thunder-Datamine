//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let time = require("%scripts/time.nut")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let DataBlock = require("DataBlock")
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"
const LOCAL_SORT_ENTITIES_ID = "saveDataLastSort"

::gui_handlers.SaveDataDialog <- class extends ::gui_handlers.BaseGuiHandlerWT {
  static wndType = handlerType.MODAL
  static sceneBlkName = "%gui/fileDialog/saveDataDialog.blk"

  curHoverObjId = null

  getSaveDataContents = null

  doLoad = null
  doSave = null
  doDelete = null
  doCancel = null

  entries = []
  tableEntries = {}
  createEntry = @(comment = "", path = "", mtime = 0) { comment = comment, path = path, mtime = mtime }

  sortParams = [
    { id = "releaseDate", param = "mtime", asc = true }
    { id = "releaseDate", param = "mtime", asc = false }
    { id = "name", param = "comment", asc = true }
    { id = "name", param = "comment", asc = false }
  ]

  tableParams = [
    {
      id = "name"
      headerLocId = "#save/fileName"
      width = "fw"
      param = "comment"
    }
    {
      id = "mtime"
      headerLocId = "#filesystem/fileMTime"
      width = "0.22@sf"
      param = "mtime"
      textFunc = @(p) time.buildTabularDateTimeStr(p)
    }
  ]

  function initScreen() {
    if (!this.scene)
      this.goBack()

    if (!this.getSaveDataContents) {
      ::script_net_assert_once("SaveDataDialog: no listing function",
                               "SaveDataDialog: no mandatory listing function")
      this.goBack()
      return
    }

    this.updateSortingList()
    this.requestEntries()
  }

  function showWaitAnimation(show) {
    if (show)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, null)
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
  }

  function onReceivedSaveDataListing(blk) {
    if (!this.isValid())
      return

    this.entries.clear()
    foreach (_id, meta in blk) {
      if (meta instanceof DataBlock)
        this.entries.append({ path = meta.path, comment = meta.comment, mtime = meta.mtime })
    }
    this.showWaitAnimation(false)

    this.updateEntriesList()
  }

  function updateEntriesList() {
    this.sortEntries()
    this.renderSaveDataContents()
    this.updateSelectionAfterDataLoaded()
  }

  function requestEntries() {
    this.showWaitAnimation(true)
    let cb = Callback(this.onReceivedSaveDataListing, this)
    this.getSaveDataContents(@(blk) cb(blk))
  }

  function updateSortingList() {
    let obj = this.scene.findObject("sorting_block_bg")
    if (!checkObj(obj))
      return

    let curVal = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let view = {
      id = "sort_params_list"
      btnName = "RB"
      funcName = "onChangeSortParam"
      values = this.sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(loc($"items/sort/{p.id}"), loc(p.asc ? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      })
    }

    let data = handyman.renderCached("%gui/commonParts/comboBox.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    this.getSortListObj().setValue(curVal)
  }

  function onChangeSortParam(obj) {
    let val = obj.getValue()
    ::saveLocalByAccount(LOCAL_SORT_ENTITIES_ID, val)

    this.updateEntriesList()
  }

  function sortEntries() {
    let val = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let p = this.sortParams[val].param
    let isAscending = this.sortParams[val].asc
    this.entries.sort(@(a, b) (isAscending ? 1 : -1) * (a[p] <=> b[p]))
  }

  function onHoverChange(obj) {
    let id = obj.isHovered() ? obj.id : null
    if (this.curHoverObjId == id)
      return

    this.curHoverObjId = id
    this.updateButtons()
  }

  isEntryLoaded = @(entry) entry && entry.path != "" && entry.comment != ""

  function updateButtons() {
    if (!this.isValid())
      return

    let isNewFileSelected  = this.curHoverObjId == "file_name"
    let isFileTableFocused = this.curHoverObjId == "file_table"
    let curEntry = this.getSelectedEntry()
    let isLoadedEntry = this.isEntryLoaded(curEntry)

    ::showBtnTable(this.scene, {
      btn_delete = this.doDelete && isFileTableFocused && isLoadedEntry,
      btn_load = this.doLoad && isFileTableFocused && isLoadedEntry
      btn_save = isNewFileSelected
      btn_rewrite = isFileTableFocused
    })

    let newFileName = this.getObj("file_name").getValue()
    ::enableBtnTable(this.scene, { btn_save = newFileName != "" }, true)
  }

  function renderSaveDataContents() {
    let fileTableObj = this.getTableListObj()
    if (!fileTableObj)
      return

    let curSortIdx = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let sortParam = this.sortParams[curSortIdx].param
    let headerRow = []
    this.tableParams.each(function(p, _idx) {
      headerRow.append({
        id = $"file_header_{p.id}"
        text = p.headerLocId
        width = p.width
        active = p.param == sortParam
      })
    })

    local markUp = [
      ::buildTableRowNoPad("row_header", headerRow, true,
        "inactive:t='yes'; commonTextColor:t='yes'; skip-navigation:t='yes';")
    ]

    this.tableEntries.clear()

    let rowData = []
    foreach (idx, e in this.entries) {
      rowData.clear()

      let rowName = $"file_row_{idx}"
      this.tableEntries[rowName] <- e
      this.tableParams.each(function(p) {
        rowData.append({
          id = $"{rowName}_{p.id}"
          text = p?.textFunc ? p.textFunc(e[p.param]) : e[p.param]
          width = p.width
          active = p.param == sortParam
        })
      })

      markUp.append(::buildTableRowNoPad(rowName, rowData, idx % 2 != 0))
    }

    markUp = "".join(markUp, true)
    this.guiScene.replaceContentFromText(fileTableObj, markUp, markUp.len(), this)
  }

  function updateSelectionAfterDataLoaded() {
    let fileTableObj = this.getTableListObj()
    if (!fileTableObj)
      return

    if (this.tableEntries.len() > 0)
      fileTableObj.setValue(1)

    if (this.tableEntries.len() > 0)
      ::move_mouse_on_child_by_value(this.getTableListObj())
    else
      ::select_editbox(this.getObj("file_name"))
  }

  function restoreFocus() {
    if (this.curHoverObjId == "file_name")
      ::select_editbox(this.getObj("file_name"))
    else
      ::move_mouse_on_child_by_value(this.getTableListObj())
  }

  function getSelectedEntry() {
    if (!this.tableEntries.len())
      return null

    let tableObj = this.getTableListObj()
    let selectedRowIdx = tableObj.getValue()
    if (selectedRowIdx >= 0 && selectedRowIdx < tableObj.childrenCount()) {
      let e = tableObj.getChild(selectedRowIdx)
      if (e.id in this.tableEntries)
        return this.tableEntries[e.id]
    }

    return null
  }


  function onFileTableSelect() {
    this.updateButtons()
  }


  function onFileNameEditBoxChangeValue() {
    this.updateButtons()
  }


  function onFileNameEditBoxAccesskey() {
    ::select_editbox(this.getObj("file_name"))
  }

  function onFileNameEditBoxCancelEdit(obj) {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      this.goBack()
  }

  function onBtnDelete() {
    let curEntry = this.getSelectedEntry()
    if (!curEntry)
      return

    log("SAVE DIALOG: onBtnDelete for entry")
    debugTableData(curEntry)

    ::scene_msg_box("savedata_delete_msg_box",
                    null,
                    loc("save/confirmDelete", { name = curEntry.comment }),
                    [["yes", Callback(@() this.doDelete(curEntry), this)], ["no", function() {}]],
                    "no",
                    { cancel_fn = @() null })
  }

  function onBtnSave() {
    let entryName = this.getObj("file_name").getValue()
    if (entryName == "") {
      ::showInfoMsgBox(loc("save/saveNameMissing"))
      return
    }

    let entry = this.getExistEntry(entryName) || this.createEntry(entryName)
    log("SAVE DIALOG: onBtnSave for entry:")
    debugTableData(entry)

    if (entry.path == "")
      this.doSave(entry)
    else
      this.doRewrite(entry)
  }

  function getExistEntry(name) {
    if (this.tableEntries.len())
      return u.search(this.tableEntries, @(e) e.comment == name)

    return null
  }

  function onBtnRewrite() {
    let selectedEntry = this.getSelectedEntry()
    if (!selectedEntry)
      return

    log("SAVE DIALOG: onBtnRewrite for entry:")
    debugTableData(selectedEntry)
    this.doRewrite(selectedEntry)
  }

  function doRewrite(entry) {
    ::scene_msg_box("savedata_overwrite_msg_box",
      null,
      loc("save/confirmOverwrite", { name = entry.comment }),
      [
        ["yes", Callback(@() this.doSave(entry), this)],
        ["no", @() null]
      ],
      "no",
    { cancel_fn = @() null })
  }

  function onBtnLoad() {
    let curEntry = this.getSelectedEntry()
    if (!curEntry)
      return

    log("SAVE DIALOG: onBtnLoad for entry:")
    debugTableData(curEntry)

    ::scene_msg_box("savedata_confirm_load_msg_box",
                    null,
                    loc("save/confirmLoad", { name = curEntry.comment }),
                    [["yes", Callback(@() this.doLoad(curEntry), this)], ["no", function() {}]],
                    "no",
                    { cancel_fn = @() null })
  }

  function onCancel() {
    if (this.doCancel)
      this.doCancel()
    this.goBack()
  }

  function onEventModalWndDestroy(_params) {
    if (!this.isSceneActiveNoModals())
      return
    this.updateButtons()
    this.restoreFocus()
  }

  getTableListObj = @() this.getObj("file_table")
  getSortListObj = @() this.getObj("sort_params_list")
}
