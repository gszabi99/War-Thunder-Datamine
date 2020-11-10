local u = require("sqStdLibs/helpers/u.nut")
local time = require("scripts/time.nut")
local progressMsg = require("sqDagui/framework/progressMsg.nut")
local DataBlock = require("DataBlock")
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"
const LOCAL_SORT_ENTITIES_ID = "saveDataLastSort"

class ::gui_handlers.SaveDataDialog extends ::gui_handlers.BaseGuiHandlerWT
{
  static wndType = handlerType.MODAL
  static sceneBlkName = "gui/fileDialog/saveDataDialog.blk"

  curHoverObjId = null

  getSaveDataContents = null

  doLoad = null
  doSave = null
  doDelete = null
  doCancel = null

  entries = []
  tableEntries = {}
  createEntry = @(comment="", path="", mtime=0) {comment = comment, path = path, mtime = mtime}

  sortParams = [
    {id = "releaseDate", param = "mtime", asc = true}
    {id = "releaseDate", param = "mtime", asc = false}
    {id = "name", param = "comment", asc = true}
    {id = "name", param = "comment", asc = false}
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
      width = "0.18@sf"
      param = "mtime"
      textFunc = @(p) time.buildTabularDateTimeStr(p)
    }
  ]

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

    updateSortingList()
    requestEntries()
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

    entries.clear()
    foreach (id, meta in blk)
    {
      if (meta instanceof DataBlock)
        entries.append({path=meta.path, comment=meta.comment, mtime=meta.mtime})
    }
    showWaitAnimation(false)

    updateEntriesList()
  }

  function updateEntriesList()
  {
    sortEntries()
    renderSaveDataContents()
    updateSelectionAfterDataLoaded()
  }

  function requestEntries()
  {
    showWaitAnimation(true)
    local cb = ::Callback(onReceivedSaveDataListing, this)
    getSaveDataContents(@(blk) cb(blk))
  }

  function updateSortingList() {
    local obj = scene.findObject("sorting_block_bg")
    if (!::checkObj(obj))
      return

    local curVal = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    local view = {
      id = "sort_params_list"
      btnName = "RB"
      funcName = "onChangeSortParam"
      values = sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(::loc($"items/sort/{p.id}"), ::loc(p.asc? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      })
    }

    local data = ::handyman.renderCached("gui/commonParts/comboBox", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    getSortListObj().setValue(curVal)
  }

  function onChangeSortParam(obj) {
    local val = obj.getValue()
    ::saveLocalByAccount(LOCAL_SORT_ENTITIES_ID, val)

    updateEntriesList()
  }

  function sortEntries()
  {
    local val = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    local p = sortParams[val].param
    local isAscending = sortParams[val].asc
    entries.sort(@(a,b) (isAscending? 1 : -1)*(a[p] <=> b[p]))
  }

  function onHoverChange(obj)
  {
    local id = obj.isHovered() ? obj.id : null
    if (curHoverObjId == id)
      return

    curHoverObjId = id
    updateButtons()
  }

  isEntryLoaded = @(entry) entry && entry.path != "" && entry.comment != ""

  function updateButtons()
  {
    if (!isValid())
      return

    local isNewFileSelected  = curHoverObjId == "file_name"
    local isFileTableFocused = curHoverObjId == "file_table"
    local curEntry = getSelectedEntry()
    local isLoadedEntry = isEntryLoaded(curEntry)

    ::showBtnTable(scene, {
      btn_delete = doDelete && isFileTableFocused && isLoadedEntry,
      btn_load = doLoad && isFileTableFocused && isLoadedEntry
      btn_save = isNewFileSelected
      btn_rewrite = isFileTableFocused
    })

    local newFileName = getObj("file_name").getValue()
    ::enableBtnTable(scene, {btn_save = newFileName != ""}, true)
  }

  function renderSaveDataContents()
  {
    local fileTableObj = getTableListObj()
    if (!fileTableObj)
      return

    local curSortIdx = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    local sortParam = sortParams[curSortIdx].param
    local headerRow = []
    tableParams.each(function(p, idx) {
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

    tableEntries.clear()

    local rowData = []
    foreach (idx, e in entries)
    {
      rowData.clear()

      local rowName = $"file_row_{idx}"
      tableEntries[rowName] <- e
      tableParams.each(function(p) {
        rowData.append({
          id = $"{rowName}_{p.id}"
          text = p?.textFunc? p.textFunc(e[p.param]) : e[p.param]
          width = p.width
          active = p.param == sortParam
        })
      })

      markUp.append(::buildTableRowNoPad(rowName, rowData, idx % 2 != 0))
    }

    markUp = ::g_string.implode(markUp)
    guiScene.replaceContentFromText(fileTableObj, markUp, markUp.len(), this)
  }

  function updateSelectionAfterDataLoaded()
  {
    local fileTableObj = getTableListObj()
    if (!fileTableObj)
      return

    if (tableEntries.len() > 0)
      fileTableObj.setValue(1)

    if (tableEntries.len() > 0)
      ::move_mouse_on_child_by_value(getTableListObj())
    else
      ::select_editbox(getObj("file_name"))
  }

  function restoreFocus()
  {
    if (curHoverObjId == "file_name")
      ::select_editbox(getObj("file_name"))
    else
      ::move_mouse_on_child_by_value(getTableListObj())
  }

  function getSelectedEntry()
  {
    if (!tableEntries.len())
      return null

    local tableObj = getTableListObj()
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


  function onFileNameEditBoxAccesskey()
  {
    ::select_editbox(getObj("file_name"))
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
                    { cancel_fn = @() null })
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
                    { cancel_fn = @() null })
  }

  function onCancel()
  {
    if (doCancel)
      doCancel()
    goBack()
  }

  function onEventModalWndDestroy(params)
  {
    if (!isSceneActiveNoModals())
      return
    updateButtons()
    restoreFocus()
  }

  getTableListObj = @() getObj("file_table")
  getSortListObj = @() getObj("sort_params_list")
}
