local u = require("sqStdLibs/helpers/u.nut")
local time = require("scripts/time.nut")
local progressMsg = ::require("sqDagui/framework/progressMsg.nut")
local DataBlock = require("DataBlock")
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"


class ::gui_handlers.SaveDataDialog extends ::gui_handlers.BaseGuiHandlerWT
{
  static wndType = handlerType.MODAL
  static sceneBlkName = "gui/fileDialog/saveDataDialog.blk"

  getSaveDataContents = null

  doLoad = null
  doSave = null
  doDelete = null
  doCancel = null

  tableEntries = {}
  createEntry = @(comment="", path="", mtime=0) {comment = comment, path = path, mtime = mtime}

  currentFocusItem = 4

  function initScreen()
  {
    if (!scene)
      goBack()

    if (!getSaveDataContents)
    {
      ::script_net_assert_once("SaveDataDialog: no listing function",
                               "SaveDataDialog: no mandatory listing function")
      goBack()
      return
    }

    requestEntries()
    initFocusArray()
  }

  function showWaitAnimation(show)
  {
    if (show)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, null)
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
  }

  function onReceivedSaveDataListing(blk)
  {
    if (!isValid())
      return

    local entries = []
    foreach (id, meta in blk)
    {
      if (meta instanceof DataBlock)
        entries.append({path=meta.path, comment=meta.comment, mtime=meta.mtime})
    }

    entries.sort(@(a,b) -(a.mtime <=> b.mtime))

    renderSaveDataContents(entries)
    showWaitAnimation(false)
    updateSelectionAfterDataLoaded()
  }

  function requestEntries()
  {
    showWaitAnimation(true)
    local cb = ::Callback(onReceivedSaveDataListing, this)
    getSaveDataContents(@(blk) cb(blk))
  }

  function onFocusChange(obj)
  {
    guiScene.performDelayed(this, updateButtons)
  }

  isEntryLoaded = @(entry) entry && entry.path != "" && entry.comment != ""

  function updateButtons()
  {
    if (!isValid())
      return

    local isFileTableFocused = getObj("file_table").isFocused()

    local newFileObj = getObj("file_name")
    local isNewFileSelected = newFileObj.isFocused()

    local curEntry = getSelectedEntry()
    local isLoadedEntry = isEntryLoaded(curEntry)

    ::showBtnTable(scene, {
      btn_delete = doDelete && isFileTableFocused && isLoadedEntry,
      btn_load = doLoad && isFileTableFocused && isLoadedEntry
      btn_save = isNewFileSelected
      btn_rewrite = isFileTableFocused
    })

    local newFileName = newFileObj.getValue()
    ::enableBtnTable(scene, {btn_save = newFileName != ""}, true)
  }

  function renderSaveDataContents(entries)
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    local view = {rows = [{
      row_id = "file_header_row"
      isHeaderRow = true
      cells = [{id="file_col_name", text="#save/fileName", width="fw"},
               {id="file_col_mtime", text="#filesystem/fileMTime", width="0.18@sf"}]
    }]}

    tableEntries.clear()

    local isEven = false
    foreach (idx, e in entries)
    {
      local rowView = {
        row_id = "file_row_"+idx
        even = isEven
        cells = [{text=e.comment, width="fw"},
                 {text=time.buildTabularDateTimeStr(e.mtime), width="0.18@sf"}]
      }
      view.rows.append(rowView)
      tableEntries[rowView.row_id] <- e
      isEven = !isEven
    }

    local data = ::handyman.renderCached("gui/fileDialog/fileTable", view)
    guiScene.replaceContentFromText(fileTableObj, data, data.len(), this)
  }

  function updateSelectionAfterDataLoaded()
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    if (tableEntries.len() > 0)
      fileTableObj.setValue(1)
  }


  function getSelectedEntry()
  {
    if (!tableEntries.len())
      return null

    local tableObj = getObj("file_table")
    local selectedRowIdx = tableObj.getValue()
    if (selectedRowIdx >= 0 && selectedRowIdx < tableObj.childrenCount())
    {
      local e = tableObj.getChild(selectedRowIdx)
      if (e.id in tableEntries)
        return tableEntries[e.id]
    }

    return null
  }


  function onFileTableSelect()
  {
    updateButtons()
  }


  function onFileNameEditBoxChangeValue()
  {
    updateButtons()
  }


  function onFileNameEditBoxActivate()
  {
    local fileNameObj = getObj("file_name")
    if (!fileNameObj.isFocused())
      fileNameObj.select()
  }


  function onFileNameEditBoxCancelEdit(obj)
  {
    if (obj.getValue().len() > 0)
      obj.setValue("")
    else
      goBack()
  }

  function onBtnDelete()
  {
    local curEntry = getSelectedEntry()
    if (!curEntry)
      return

    dagor.debug("SAVE DIALOG: onBtnDelete for entry")
    ::debugTableData(curEntry)

    ::scene_msg_box("savedata_delete_msg_box",
                    null,
                    ::loc("save/confirmDelete", {name=curEntry.comment}),
                    [["yes", ::Callback(@() doDelete(curEntry), this)], ["no", function(){}]],
                    "no",
                    {})
  }

  function onBtnSave()
  {
    local entryName = getObj("file_name").getValue()
    if (entryName == "")
    {
      ::showInfoMsgBox(::loc("save/saveNameMissing"))
      return
    }

    local entry = getExistEntry(entryName) || createEntry(entryName)
    dagor.debug("SAVE DIALOG: onBtnSave for entry:")
    ::debugTableData(entry)

    if (entry.path == "")
      doSave(entry)
    else
      doRewrite(entry)
  }

  function getExistEntry(name)
  {
    if (tableEntries.len())
      return u.search(tableEntries, @(e) e.comment == name)

    return null
  }

  function onBtnRewrite()
  {
    local selectedEntry = getSelectedEntry()
    if (!selectedEntry)
      return

    dagor.debug("SAVE DIALOG: onBtnRewrite for entry:")
    ::debugTableData(selectedEntry)
    doRewrite(selectedEntry)
  }

  function doRewrite(entry)
  {
    ::scene_msg_box("savedata_overwrite_msg_box",
      null,
      ::loc("save/confirmOverwrite", {name=entry.comment}),
      [
        ["yes", ::Callback(@() doSave(entry), this)],
        ["no", @() null]
      ],
      "no",
    {cancel_fn = @() null })
  }

  function onBtnLoad()
  {
    local curEntry = getSelectedEntry()
    if (!curEntry)
      return

    dagor.debug("SAVE DIALOG: onBtnLoad for entry:")
    ::debugTableData(curEntry)

    ::scene_msg_box("savedata_confirm_load_msg_box",
                    null,
                    ::loc("save/confirmLoad", {name=curEntry.comment}),
                    [["yes", ::Callback(@() doLoad(curEntry), this)], ["no", function(){}]],
                    "no",
                    {})
  }

  function onCancel()
  {
    if (doCancel)
      doCancel()
    goBack()
  }

  function getMainFocusObj()
  {
    return tableEntries.len()? getObj("file_table") : null
  }

  function getMainFocusObj2()
  {
    return getObj("file_name")
  }
}
