let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let DataBlock = require("DataBlock")
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"
const LOCAL_SORT_ENTITIES_ID = "saveDataLastSort"

::gui_handlers.SaveDataDialog <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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
      width = "0.22@sf"
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
    let cb = ::Callback(onReceivedSaveDataListing, this)
    getSaveDataContents(@(blk) cb(blk))
  }

  function updateSortingList() {
    let obj = scene.findObject("sorting_block_bg")
    if (!::checkObj(obj))
      return

    let curVal = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let view = {
      id = "sort_params_list"
      btnName = "RB"
      funcName = "onChangeSortParam"
      values = sortParams.map(@(p, idx) {
        text = "{0} ({1})".subst(::loc($"items/sort/{p.id}"), ::loc(p.asc? "items/sort/ascending" : "items/sort/descending"))
        isSelected = curVal == idx
      })
    }

    let data = ::handyman.renderCached("%gui/commonParts/comboBox", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    getSortListObj().setValue(curVal)
  }

  function onChangeSortParam(obj) {
    let val = obj.getValue()
    ::saveLocalByAccount(LOCAL_SORT_ENTITIES_ID, val)

    updateEntriesList()
  }

  function sortEntries()
  {
    let val = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let p = sortParams[val].param
    let isAscending = sortParams[val].asc
    entries.sort(@(a,b) (isAscending? 1 : -1)*(a[p] <=> b[p]))
  }

  function onHoverChange(obj)
  {
    let id = obj.isHovered() ? obj.id : null
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

    let isNewFileSelected  = curHoverObjId == "file_name"
    let isFileTableFocused = curHoverObjId == "file_table"
    let curEntry = getSelectedEntry()
    let isLoadedEntry = isEntryLoaded(curEntry)

    ::showBtnTable(scene, {
      btn_delete = doDelete && isFileTableFocused && isLoadedEntry,
      btn_load = doLoad && isFileTableFocused && isLoadedEntry
      btn_save = isNewFileSelected
      btn_rewrite = isFileTableFocused
    })

    let newFileName = getObj("file_name").getValue()
    ::enableBtnTable(scene, {btn_save = newFileName != ""}, true)
  }

  function renderSaveDataContents()
  {
    let fileTableObj = getTableListObj()
    if (!fileTableObj)
      return

    let curSortIdx = ::loadLocalByAccount(LOCAL_SORT_ENTITIES_ID, 0)
    let sortParam = sortParams[curSortIdx].param
    let headerRow = []
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

    let rowData = []
    foreach (idx, e in entries)
    {
      rowData.clear()

      let rowName = $"file_row_{idx}"
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
    let fileTableObj = getTableListObj()
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

    let tableObj = getTableListObj()
    let selectedRowIdx = tableObj.getValue()
    if (selectedRowIdx >= 0 && selectedRowIdx < tableObj.childrenCount())
    {
      let e = tableObj.getChild(selectedRowIdx)
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
    let curEntry = getSelectedEntry()
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
    let entryName = getObj("file_name").getValue()
    if (entryName == "")
    {
      ::showInfoMsgBox(::loc("save/saveNameMissing"))
      return
    }

    let entry = getExistEntry(entryName) || createEntry(entryName)
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
    let selectedEntry = getSelectedEntry()
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
    let curEntry = getSelectedEntry()
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
