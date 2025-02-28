from "%scripts/dagui_natives.nut" import get_exe_dir, get_save_load_path
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let stdpath = require("%sqstd/path.nut")
let { abs } = require("math")
let { find_files } = require("dagor.fs")
let { lastIndexOf, INVALID_INDEX, utf8ToUpper, endsWith } = require("%sqstd/string.nut")
let { select_editbox, move_mouse_on_child_by_value } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { measureType } = require("%scripts/measureType.nut")

gui_handlers.FileDialog <- class (gui_handlers.BaseGuiHandlerWT) {
  static wndType = handlerType.MODAL
  static sceneBlkName = "%gui/fileDialog/fileDialog.blk"

  static dirPathPartTemplate    = "%gui/fileDialog/dirPath.tpl"
  static fileTableTemplate      = "%gui/fileDialog/fileTable.tpl"
  static navItemListTemplate    = "%gui/fileDialog/navItemList.tpl"
  static filterSelectTemplate   = "%gui/fileDialog/filterSelect.tpl"

  static FILEDIALOG_PATH_SETTING_ID = "fileDialog"

  static allFilesFilter         = "*"

  // Required params
  isSaveFile = false
  onSelectCallback  = null

  // Other general params
  dirPath               = ""
  fileName              = ""    // Default fileName
  pathTag               = null  // Used for restore dirPath and fileName from account settings
  extension             = null  // Automatically added file extension on save
  shouldAskOnRewrite    = true  // Ask if user want rewrite file when save
  isNavigationVisible   = true  // Is navigation panel visible by default
  isNavigationToggleAllowed = true  // Is navigation panel can expanded/collapsed
  currentFilter             = null  // Default selected filter
  shouldAddAllFilesFilter   = true

  // Other array/map params
  // Can specified in contructor, or used defaults
  columns           = null
  filters           = null
  visibleColumns    = null
  columnSortOrder   = null

  // Fyle-system functions.
  // Can specified in contructor, or used defaults
  validatePath      = null
  readDirFiles      = null
  readFileInfo      = null
  getFileName       = null
  getFileFullPath   = null
  isExists          = null
  isDirectory       = null
  getNavElements    = null

  // User sort information
  userSortColumn    = null
  isUserSortReverse = false

  // History arrays for back and forward move
  dirHistoryBefore  = null
  dirHistoryAfter   = null

  // Map containing last selected file by paths
  lastSelectedFileByPath        = null

  // Cached maps
  cachedFileNameByTableRowId      = null
  cachedTableRowIdxByFileName     = null
  cachedFileFullPathByFileName    = null
  cachedColumnNameByTableColumnId = null
  cachedPathByPathPartId          = null
  cachedPathByNavItemId           = null
  cachedFilterByItemId            = null

  // Number of maximum files loaded in large directories
  // Required while sorting is slowest operation,
  // And if where is many files game client freeze
  maximumFilesToLoad            = 512

  finallySelectedPath           = null

  // ================================================================
  // =========================== DEFAULTS ===========================
  // ================================================================

  static columnSources = [
    // Sort source placement
    {
      sourceName = "columnSortOrder"
      requiredAttributes = ["getValue", "comparator"]
    }
    {
      sourceName = "visibleColumns"
      requiredAttributes = ["header", "getValue", "getView"]
    }
  ]

  static defaultColumns = {
    /*
    userSpecifiedColumnInColumns = {
      header = "Column header, showed in first row"

      // Preprocess file
      getValue = function(file, fileDialog) {
        return FUNC1(file)
      }

      // Compare two preprocessed values
      comparator = function(lhs, rhs) {
        return FUNC2(lhs, rhs)
      }

      // Convert preprocessed values to table view
      getView = function(lhs, rhs) {
        return FUNC2(lhs, rhs)
      }
    }

    // User modified column can use original functions
    // through defaultColumn variable.
    name = {
      getView = function(value) {
        local view = defaultColumn.getView(value)
        view.tdalign <- "right"
        return view
      }
    }
    */

    name = {
      header = "#filesystem/fileName"
      getValue = function(file, _fileDialog) {
        return getTblValue("name", file)
      }
      comparator = function(lhs, rhs) {
        return gui_handlers.FileDialog.compareStringOrNull(lhs, rhs)
      }
      width = "fw"
      getView = function(value) {
        let text = value != null ? value : ""
        return {
          text = text
          tooltip = text
          width = this.width
        }
      }
    }

    mTime = {
      header = "#filesystem/fileMTime"
      getValue = function(file, _fileDialog) {
        return getTblValue("modifyTime", file)
      }
      comparator = function(lhs, rhs) {
        return gui_handlers.FileDialog.compareIntOrNull(lhs, rhs)
      }
      width = "0.18@sf"
      getView = function(value) {
        local text = ""
        local tooltip = "#filesystem/mTimeNotSpecified"
        if (value != null) {
          tooltip = time.buildDateTimeStr(value)
          text = time.buildTabularDateTimeStr(value)
        }

        return {
          text = text
          tooltip = tooltip
          width = this.width
        }
      }
    }

    directory = {
      header = ""
      getValue = function(file, _fileDialog) {
        return getTblValue("isDirectory", file, false)
      }
      comparator = function(lhs, rhs) {
        return (lhs ? 1 : 0) - (rhs ? 1 : 0)
      }
      width = "h"
      getView = function(value) {
        let fileImage = "#ui/gameuiskin#btn_clear_all.svg"
        let dirImage = "#ui/gameuiskin#btn_load_from_file.svg"
        return {
          text = ""
          tooltip = ""
          width = this.width
          image = value ? dirImage : fileImage
          imageRawParams = "pos:t = '50%w, 50%ph-50%h'; "
        }
      }
    }

    extension = {
      header = "#filesystem/fileExtension"
      getValue = function(file, _fileDialog) {
        if (getTblValue("isDirectory", file, false))
          return "."

        let filename = file?.name ?? ""
        let fileExtIdx = lastIndexOf(filename, ".")
        if (fileExtIdx == INVALID_INDEX)
          return null

        return utf8ToUpper(filename.slice(fileExtIdx))
      }
      comparator = function(lhs, rhs) {
        return gui_handlers.FileDialog.compareStringOrNull(lhs, rhs)
      }
      width = "0.18@sf"
      getView = function(value) {
        local extType = ""
        if (value == null)
          extType = ""
        else if (value == ".")
          extType = "#filesystem/directory"
        else if (value == "")
          extType = "#filesystem/file"
        else
          extType = " ".concat(loc("filesystem/file"), value)
        return {
          text = extType
          tooltip = extType
          width = this.width
        }
      }
    }

    size = {
      header = "#filesystem/fileSize"
      getValue = function(file, _fileDialog) {
        return getTblValue("size", file)
      }
      comparator = function(lhs, rhs) {
        return gui_handlers.FileDialog.compareIntOrNull(lhs, rhs)
      }
      width = "0.18@sf"
      getView = function(value) {
        local text = ""
        local tooltip = "#filesystem/fileSizeNotSpecified"
        if (value != null) {
          text = measureType.FILE_SIZE.getMeasureUnitsText(value, true, false);
          tooltip = measureType.FILE_SIZE.getMeasureUnitsText(value, true, true);
        }
        return {
          text = text
          tooltip = tooltip
          tdalign = "right"
          width = this.width
        }
      }
    }

    userSort = {
      // Only for sort, can't be used in visible columns
      getValue = function(file, fileDialog) {
        if (!("userSortColumn" in fileDialog) ||
          !("getValue" in fileDialog.userSortColumn))
          return null
        return {
          file = file
          column = fileDialog.userSortColumn
          value = fileDialog.userSortColumn.getValue(file, fileDialog)
          multiplier = fileDialog.isUserSortReverse ? -1 : 1
        }
      }
      comparator = function(lhs, rhs) {
        return gui_handlers.FileDialog.compareObjOrNull(lhs, rhs) ||
          (lhs != null ? lhs.column.comparator(lhs.value, rhs.value) * lhs.multiplier : 0)
      }
    }
  }

  static defaultFsFunctions = {
    validatePath = function(path) {
      return (path && path != ""
        && (is_platform_windows
          ? (path.len() >= 2 && path[1] == ':')
          : path[0] == '/'))
    }

    readDirFiles = function(path, maxFiles) {
      if (!this.validatePath(path))
        return []
      let files = find_files(stdpath.join(path, this.allFilesFilter), { maxCount = maxFiles })
      foreach (file in files)
        if ("name" in file)
          file.fullPath <- stdpath.join(path, file.name)
      return files
    }

    readFileInfo = function(path) {
      if (!this.validatePath(path))
        return null
      let basename = stdpath.fileName(path)
      local files = find_files(path, { maxCount = 1 })
      if (files.len() > 0 && getTblValue("name", files[0]) == basename)
        return files[0]

      if (files.len() == 0)
        files = find_files(stdpath.join(path, this.allFilesFilter), { maxCount = 1 })
      if (files.len() > 0)
        return { name = basename, isDirectory = true }
      return null
    }

    getFileName = function(file) {
      return getTblValue("name", file, "")
    }

    getFileFullPath = function(file) {
      return getTblValue("fullPath", file, "")
    }

    isExists = function(file) {
      return file != null && "name" in file
    }

    isDirectory = function(file) {
      return file != null && getTblValue("isDirectory", file, false)
    }

    getNavElements = function() {
      // Filtering non-existent elements is performed when filling navigation bar
      let favorites = []
      favorites.append({
        name = "#filesystem/gamePaths"
        childs = [
          { name = "#filesystem/gameSaves",
            path = stdpath.normalize(get_save_load_path()) },
          { name = "#filesystem/gameExe",
            path = stdpath.parentPath(stdpath.normalize(get_exe_dir())) }
        ]
      })

      if (is_platform_windows) {
        let disks = { name = "#filesystem/winDiskDrives", childs = [] }
        for (local diskChar = 'C' ; diskChar <= 'Z'; diskChar++) {
          let path = $"{diskChar.tochar()}:"
          disks.childs.append({ path = path })
        }
        favorites.append(disks)
      }
      else if (platformId == "macosx") {
        favorites.append({
          name = "#filesystem/fsMountPoints"
          childs = [
            { name = "#filesystem/fsRoot", path = "/" },
            { path = "/Users" },
            { path = "/Volumes" }
          ]
        })
      }
      else { /* base template for other unix-based OS */
        favorites.append({
          name = "#filesystem/fsMountPoints"
          childs = [
            { name = "#filesystem/fsRoot", path = "/" },
            { path = "/home" },
            { path = "/media" },
            { path = "/mnt" }
          ]
        })
      }

      return favorites;
    }
  }


  // ================================================================
  // ========================= INIT SCREEN ==========================
  // ================================================================

  function initScreen() {
    if (!this.scene)
      return this.goBack()

    // Init defaults
    if (this.dirPath != "")
      this.dirPath = stdpath.normalize(this.dirPath)
    else if (is_platform_windows)
      this.dirPath = "C:"
    else
      this.dirPath = "/"

    this.columns = this.columns || {}
    this.visibleColumns = this.visibleColumns ||
      ["directory", "name", "mTime", "extension", "size"]
    this.columnSortOrder = this.columnSortOrder || [
      // Sort by "directory" always and before sorting by user selected column
      { column = "directory", reverse = true }
      "userSort"
    ]

    this.filters = (this.filters && this.filters.len() > 0) ? this.filters : []
    if (this.currentFilter && !isInArray(this.currentFilter, this.filters))
      this.filters.append(this.currentFilter)
    if (this.shouldAddAllFilesFilter && !isInArray(this.allFilesFilter, this.filters))
      this.filters.append(this.allFilesFilter)
    this.currentFilter = this.currentFilter ||
      (isInArray(this.allFilesFilter, this.filters) ? this.allFilesFilter : this.filters[0])

    if (this.extension && this.currentFilter != this.allFilesFilter && this.extension != this.currentFilter) {
      script_net_assert_once("FileDialog: extension not same as currentFilter",
        "FileDialog: specified extension is not same as currentFilter")
      this.goBack()
      return
    }

    if (this.onSelectCallback == null) {
      script_net_assert_once("FileDialog: null onSelectCallback",
        "FileDialog: onSelectCallback not specified")
      this.goBack()
      return
    }

    this.dirHistoryBefore = []
    this.dirHistoryAfter  = []
    this.cachedFileNameByTableRowId      = {}
    this.cachedTableRowIdxByFileName     = {}
    this.cachedFileFullPathByFileName    = {}
    this.cachedColumnNameByTableColumnId = {}
    this.cachedPathByPathPartId          = {}
    this.lastSelectedFileByPath          = {}
    this.cachedPathByNavItemId           = {}
    this.cachedFilterByItemId            = {}

    foreach (funcName, func in this.defaultFsFunctions)
      if (!this[funcName])
        this[funcName] = func

    // Fill columns structure
    this.prepareColums()
    if (!this.validateColums()) {
      this.goBack()
      return
    }

    // Update screen
    this.getObj("dialog_header").setValue(
      loc(this.isSaveFile ? "filesystem/savefile" : "filesystem/openfile"))
    this.updateAllDelayed()

    move_mouse_on_child_by_value(this.getObj("file_table"))

    this.restorePathFromSettings()
  }


  // ================================================================
  // =========================== HANDLERS ===========================
  // ================================================================

  function onFileTableClick(_obj) {
    this.setFocusToFileTable()
    this.updateSelectedFileName()
  }


  function onFileTableDblClick() {
    this.onOpen()
  }


  function onNavigation() {
    if (!this.isNavigationToggleAllowed)
      return

    this.isNavigationVisible = !this.isNavigationVisible
    this.fillNavListObj()
  }


  function onForward() {
    this.moveInHistory(1)
  }


  function onBack() {
    this.moveInHistory(-1)
  }


  function onUp() {
    let parentPath = stdpath.parentPath(this.dirPath)
    if (parentPath != null)
      this.openDirectory(parentPath)
  }


  function onCancel() {
    this.goBack()
  }


  function onOpen() {
    let dirPathObj = this.getObj("dir_path")
    let fileNameObj = this.getObj("file_name")

    if (dirPathObj.isFocused())
      this.onDirPathEditBoxActivate()
    else if (fileNameObj.isFocused())
      this.onFileNameEditBoxActivate()
    else {
      this.updateSelectedFileName()

      let fullPath = getTblValue(this.fileName, this.cachedFileFullPathByFileName) ||
        stdpath.join(this.dirPath, this.fileName)
      if (fullPath != "")
        this.openFileOrDir(fullPath)
    }
  }


  function onDirPathEditBoxFocus() {
    this.guiScene.performDelayed(this, this.fillDirPathObj)
  }


  function onRefresh() {
    let dirPathObj = this.getObj("dir_path")
    let path = dirPathObj.isFocused() ? dirPathObj.getValue() : this.dirPath
    this.openDirectory(path)
    move_mouse_on_child_by_value(this.getObj("file_table"))
  }


  function onDirPathEditBoxActivate() {
    let dirPathObj = this.getObj("dir_path")
    let path = dirPathObj.isFocused() ? dirPathObj.getValue() : this.dirPath
    this.openFileOrDir(path)
    move_mouse_on_child_by_value(this.getObj("file_table"))
  }


  function onFileNameEditBoxActivate() {
    this.fileName = this.getObj("file_name").getValue()
    if (this.fileName != "")
      this.openFileOrDir(stdpath.join(this.dirPath, this.fileName))
  }


  function onFileNameEditBoxCancelEdit() {
    this.onToggleFocusFileName()
  }


  function onDirPathEditBoxCancelEdit() {
    this.onToggleFocusDirPath()
  }


  function onToggleFocusFileName() {
    let fileTableObj = this.getObj("file_table")
    let fileNameObj = this.getObj("file_name")
    if (fileNameObj.isHovered())
      move_mouse_on_child_by_value(fileTableObj)
    else
      select_editbox(fileNameObj)
  }

  function onToggleFocusDirPath() {
    let fileTableObj = this.getObj("file_table")
    let dirPathObj = this.getObj("dir_path")
    if (dirPathObj.isHovered())
      move_mouse_on_child_by_value(fileTableObj)
    else
      select_editbox(dirPathObj)
  }


  function onFileNameEditBoxChangeValue() {
    this.fileName = this.getObj("file_name").getValue()
  }


  function onNavListSelect(obj) {
    let idx = obj.getValue()
    if (idx < 0 || idx >= obj.childrenCount())
      return

    let item = obj.getChild(idx)
    if (!(item.id in this.cachedPathByNavItemId))
      return

    let path = this.cachedPathByNavItemId[item.id]
    if (path != this.dirPath)
      this.openDirectory(path)
  }


  function onFileTableSelect(_obj) {
    this.updateSelectedFileName()
  }


  function onDirPathPartClick(obj) {
    if (obj?.id in this.cachedPathByPathPartId)
      this.openDirectory(this.cachedPathByPathPartId[obj.id])
  }


  function onFileTableColumnClick(obj) {
    let objId = obj.id
    let columnName = this.cachedColumnNameByTableColumnId[objId]
    foreach (column in this.columns) {
      if (column.name != columnName)
        continue

      if (this.userSortColumn == column)
        this.isUserSortReverse = !this.isUserSortReverse
      else {
        this.userSortColumn = column
        this.isUserSortReverse = false
      }

      this.guiScene.performDelayed(this, function() {
        this.fillFileTableObj(true)
      })
      break
    }
  }


  function onFilterChange(obj) {
    let idx = obj.getValue()
    if (idx < 0 || idx >= obj.childrenCount() || idx >= this.filters.len())
      return

    if (this.filters[idx] != this.currentFilter) {
      this.currentFilter = this.filters[idx]
      this.fillFileTableObj(true)
    }
  }


  // ================================================================
  // ======================= DATA OPERATIONS ========================
  // ================================================================

  function prepareColums() {
    // Add columns used for show and sort
    foreach (columnSourceInfo in this.columnSources) {
      let source = this[columnSourceInfo.sourceName]
      foreach (idx, columnInfoSrc in source) {
        local columnInfo
        if (u.isString(columnInfoSrc)) {
          columnInfo = { column = columnInfoSrc }
          source[idx] = columnInfo
        }
        else
          columnInfo = columnInfoSrc

        if (u.isString(columnInfo.column)) {
          let columnName = columnInfo.column
          this.columns[columnName] <- getTblValue(columnName, this.columns, {})
          columnInfo.column = this.columns[columnName]
        }
      }
    }

    // Copy attributes from defaults
    foreach (columnName, column in this.columns) {
      column.name <- columnName
      if (!(columnName in this.defaultColumns))
        continue

      let defaultColumn = this.defaultColumns[columnName]
      if (column == defaultColumn)
        continue

      column.defaultColumn <- defaultColumn
      foreach (attr, attrValue in defaultColumn)
        if (!(attr in column))
          column[attr] <- attrValue
    }
  }


  function validateColums() {
    // Check required attributes
    foreach (columnSourceInfo in this.columnSources) {
      let source = this[columnSourceInfo.sourceName]
      let requiredAttributes = columnSourceInfo.requiredAttributes
      foreach (_idx, columnInfo in source) {
        let column = columnInfo.column
        foreach (attr in requiredAttributes)
          if (!(attr in column)) {
            script_net_assert_once("ERROR: FileDialog ColumnNoAttr", format("".concat(
              "ERROR: FileDialog column ",
              column?.name ?? "[UNDEFINED name]",
              $" has not attribute {attr} but it is required!"
            )))
            return false
          }
      }
    }
    return true
  }


  setFocusToFileTable = @() move_mouse_on_child_by_value(this.getObj("file_table"))


  function updateSelectedFileName() {
    let fileTableObj = this.getObj("file_table")
    if (!fileTableObj)
      return

    let selectedRowIdx = fileTableObj.getValue()
    if (selectedRowIdx < 0 || selectedRowIdx >= fileTableObj.childrenCount())
      return

    let childObj = fileTableObj.getChild(selectedRowIdx)
    if (!checkObj(childObj) ||
      !(childObj?.id in this.cachedFileNameByTableRowId))
      return

    this.fileName = this.cachedFileNameByTableRowId[childObj.id]
    this.guiScene.performDelayed(this, this.updateButtons)
    let file = this.readFileInfo(stdpath.join(this.dirPath, this.fileName))
    if (file && !this.isDirectory(file))
      this.fillFileNameObj()
  }


  function restorePathFromSettings() {
    if (!this.pathTag)
      return

    let settingName = $"{this.FILEDIALOG_PATH_SETTING_ID}/{this.pathTag}"
    let loadBlk = loadLocalAccountSettings(settingName)
    this.dirPath  = getTblValue("dirPath",  loadBlk, this.dirPath)
    this.fileName = getTblValue("fileName", loadBlk, this.fileName)

    while (!this.isDirectory(this.readFileInfo(this.dirPath))) {
      let parentPath = stdpath.parentPath(this.dirPath)
      if (!parentPath)
        return
      this.dirPath = parentPath
    }
  }


  function savePathToSettings(path) {
    if (!this.pathTag || this.dirPath == "")
      return

    let settingName = $"{this.FILEDIALOG_PATH_SETTING_ID}/{this.pathTag}"
    let saveBlk = DataBlock()
    saveBlk.dirPath = stdpath.parentPath(path)
    saveBlk.fileName = stdpath.fileName(path)
    saveLocalAccountSettings(settingName, saveBlk)
  }


  function updateButtons() {
    if (!this.isValid())
      return

    local shouldUseSaveButton = this.isSaveFile
    if (shouldUseSaveButton && this.fileName in this.cachedFileFullPathByFileName) {
      let file = this.readFileInfo(this.cachedFileFullPathByFileName[this.fileName])
      shouldUseSaveButton = !this.isDirectory(file)
    }
    this.getObj("btn_open").setValue(
      loc(shouldUseSaveButton ? "filesystem/btnSave" : "filesystem/btnOpen"))
    this.getObj("btn_backward").enable(this.dirHistoryBefore.len() > 0)
    this.getObj("btn_forward").enable(this.dirHistoryAfter.len() > 0)
  }


  function moveInHistory(shift) {
    if (shift == 0)
      return

    let isForward = shift > 0
    let numSteps = abs(shift)

    let sourceList = isForward ? this.dirHistoryAfter : this.dirHistoryBefore
    let targetList = isForward ? this.dirHistoryBefore : this.dirHistoryAfter

    this.rememberSelectedFile()
    for (local stepIdx = 0; stepIdx < numSteps; stepIdx++) {
      if (sourceList.len() == 0)
        break
      targetList.append(this.dirPath)
      this.dirPath = sourceList.pop()
    }
    this.updateAllDelayed()
  }


  function executeSelectCallback() {
    if (this.onSelectCallback(this.finallySelectedPath)) {
      this.savePathToSettings(this.finallySelectedPath)
      this.goBack()
    }
  }


  function openDirectory(path) {
    path = stdpath.normalize(path)
    let file = this.readFileInfo(path)
    if (this.isDirectory(file)) {
      this.rememberSelectedFile()
      if (this.dirPath == path) {
        this.fillFileTableObj(true)
        return
      }
      this.dirHistoryBefore.append(this.dirPath)
      this.dirHistoryAfter.clear()
      this.dirPath = path
      this.fileName = ""
      this.updateAllDelayed()
      return true
    }
    else
      showInfoMsgBox(loc("filesystem/folderDeleted", { path = path }))
  }


  function openFileOrDir(path) {
    path = stdpath.normalize(path)
    let file = this.readFileInfo(path)
    if (this.isDirectory(file))
      this.openDirectory(path)
    else {
      this.finallySelectedPath = path
      if (this.isSaveFile) {
        let folderPath = stdpath.parentPath(path)
        if (this.shouldAskOnRewrite && this.isExists(file))
          scene_msg_box("filesystem_rewrite_msg_box", null,
            loc("filesystem/askRewriteFile", { path = path }),
            [["ok", Callback(this.executeSelectCallback, this) ],
            ["cancel", function() {} ]], "cancel", {})
        else if (!this.isDirectory(this.readFileInfo(folderPath)))
          showInfoMsgBox(loc("filesystem/folderDeleted", { path = folderPath }))
        else {
          if (!this.isExists(file) && this.extension
            && !endsWith(this.finallySelectedPath,$".{this.extension}"))
            this.finallySelectedPath = $"{this.finallySelectedPath}.{this.extension}"
          this.executeSelectCallback()
        }
      }
      else {
        if (this.isExists(file))
          this.executeSelectCallback()
        else
          showInfoMsgBox(loc("filesystem/fileNotExists", { path = path }))
      }
    }
  }

  function rememberSelectedFile() {
    local path = ""
    let pathSegments = stdpath.splitToArray(stdpath.join(this.dirPath, this.fileName))
    for (local j = 0; j < pathSegments.len() - 1; j++) {
      path = stdpath.join(path, pathSegments[j])
      this.lastSelectedFileByPath[path] <- pathSegments[j + 1]
    }
  }


  function restoreLastSelectedFile() {
    let fileTableObj = this.getObj("file_table")
    if (!fileTableObj)
      return

    let selectedFile = getTblValue(this.dirPath, this.lastSelectedFileByPath, this.fileName)
    if (selectedFile in this.cachedTableRowIdxByFileName) {
      let rowIdx = this.cachedTableRowIdxByFileName[selectedFile]
      if (rowIdx >= 0 && rowIdx < fileTableObj.childrenCount())
        fileTableObj.setValue(rowIdx)
      return
    }
  }


  function restoreFileName() {
    let fileNameObj = this.getObj("file_name")
    if (fileNameObj && this.fileName == "")
      this.fileName = fileNameObj.getValue()
  }


  // ================================================================
  // ======================== FILL FUNCTIONS ========================
  // ================================================================

  function updateAllDelayed() {
    this.restoreFileName()
    this.guiScene.performDelayed(this, function() {
      this.fillDirPathObj()
      this.fillFileNameObj()
      this.fillFileTableObj()
      this.fillNavListObj()
      this.fillFiltersObj()
      this.updateButtons()
    })
  }

  isDirPathObjFilled = null
  isDirPathObjFocused = null
  function fillDirPathObj(forceUpdate = false) {
    let dirPathObj = this.getObj("dir_path")
    if (!dirPathObj)
      return

    let isFocused = dirPathObj.isFocused()
    if (this.isDirPathObjFilled != null && this.isDirPathObjFilled == this.dirPath &&
      this.isDirPathObjFocused == isFocused && !forceUpdate)
      return

    this.isDirPathObjFilled = this.dirPath
    this.isDirPathObjFocused = isFocused

    this.getObj("btn_refresh")["tooltip"] =
      loc(isFocused ? "filesystem/btnGo" : "filesystem/btnRefresh")
    this.getObj("btn_refresh_img")["background-image"] = isFocused ?
      "#ui/gameuiskin#spinnerListBox_arrow_up.svg" : "#ui/gameuiskin#refresh.svg"
    this.getObj("btn_refresh_img")["rotation"] = isFocused ?
      "90" : "0"

    if (isFocused) {
      dirPathObj.setValue(this.dirPath)
      this.guiScene.replaceContentFromText(dirPathObj, "", 0, this)
    }
    else {
      dirPathObj.setValue("")
      let pathParts = stdpath.splitToArray(this.dirPath)

      this.cachedPathByPathPartId.clear()
      let view = { items = [] }
      local combinedPath = ""
      foreach (idx, pathPart in pathParts) {
        combinedPath = stdpath.join(combinedPath, pathPart)
        if (pathPart == "")
          continue

        let id = $"dir_path_part_{idx}"
        this.cachedPathByPathPartId[id] <- combinedPath
        view.items.append({
          id = id
          text = pathPart != "/" ? $"{pathPart} / " : " / "
          tooltip = combinedPath
          onClick = "onDirPathPartClick"
        })
      }

      let data = handyman.renderCached(this.dirPathPartTemplate, view)
      this.guiScene.replaceContentFromText(dirPathObj, data, data.len(), this)
    }
  }


  function fillFileNameObj() {
    let fileNameObj = this.getObj("file_name")
    if (fileNameObj)
      fileNameObj.setValue(this.fileName)
  }


  fileTableObjFilledPath = null
  fileTableObjFilledFilter = null
  function fillFileTableObj(forceUpdate = false) {
    let fileTableObj = this.getObj("file_table")
    if (!fileTableObj)
      return

    if (!forceUpdate && this.fileTableObjFilledPath == this.dirPath &&
      this.fileTableObjFilledFilter == this.currentFilter)
      return

    this.fileTableObjFilledPath = this.dirPath
    this.fileTableObjFilledFilter = this.currentFilter

    local filesList = this.readDirFiles(this.dirPath, this.maximumFilesToLoad)
    if (filesList.len() > this.maximumFilesToLoad)
      filesList = filesList.slice(0, this.maximumFilesToLoad)
    let filesTableData = []

    this.cachedFileFullPathByFileName.clear()
    let fileNameMetaAttr = {}
    foreach (file in filesList) {
      let fileData = {}
      foreach (columnName, column in this.columns)
        fileData[columnName] <- column.getValue(file, this)
      let filename = this.getFileName(file)
      if (!this.isDirectory(file) && this.currentFilter != this.allFilesFilter &&
        !endsWith(filename, this.currentFilter))
        continue
      fileData[fileNameMetaAttr] <- filename
      this.cachedFileFullPathByFileName[filename] <- this.getFileFullPath(file)
      filesTableData.append(fileData)
    }

    // sort takes ~85% of fillFileTableObj execution time
    // when read directories with large files number
    filesTableData.sort(this.fileDataComporator.bindenv(this))

    let view = { rows = [] }

    let headerRowView = {
      row_id = "file_header_row"
      isHeaderRow = true
      cells = []
    }
    this.cachedColumnNameByTableColumnId.clear()
    foreach (visibleColumn in this.visibleColumns) {
      let id =$"file_col_{visibleColumn.column.name}"
      this.cachedColumnNameByTableColumnId[id] <- visibleColumn.column.name
      headerRowView.cells.append({
        id = id
        text = visibleColumn.column.header
        callback = "onFileTableColumnClick"
        active = visibleColumn.column == this.userSortColumn
      })
    }
    view.rows.append(headerRowView)

    local isEven = true
    this.cachedFileNameByTableRowId.clear()
    this.cachedTableRowIdxByFileName.clear()
    foreach (idx, fileData in filesTableData) {
      let rowId = $"file_row_{idx}"
      let filename = fileData[fileNameMetaAttr]
      this.cachedFileNameByTableRowId[rowId] <- filename
      this.cachedTableRowIdxByFileName[filename] <- idx + 1
      let rowView = {
        row_id = rowId
        even = isEven
        cells = []
      }
      foreach (visibleColumn in this.visibleColumns) {
        let column = visibleColumn.column
        let value = fileData[column.name]
        let cellView = column.getView(value)
        rowView.cells.append(cellView)
      }
      view.rows.append(rowView)
      isEven = !isEven
    }

    let data = handyman.renderCached(this.fileTableTemplate, view)
    this.guiScene.replaceContentFromText(fileTableObj, data, data.len(), this)
    this.guiScene.performDelayed(this, this.restoreLastSelectedFile)
  }


  function filterNavElements(navList) {
    for (local k = navList.len() - 1; k >= 0; k--) {
      let element = navList[k]
      if ("childs" in element && "name" in element) {
        this.filterNavElements(element.childs)
        if (element.childs.len() != 0)
          continue
      }
      else if ("path" in element) {
        element.path = stdpath.normalize(element.path)
        if (!("name" in element))
          element.name <- element.path
        if (this.isDirectory(this.readFileInfo(element.path)))
          continue;
      }
      navList.remove(k)
    }
  }


  function fillNavListData(navListData, navList, depth = 0) {
    foreach (navGroup in navList)
      if ("childs" in navGroup) {
        navListData.append({
          text = "name" in navGroup ? navGroup.name : ""
          depth = depth
        })
        this.fillNavListData(navListData, navGroup.childs, depth + 1)
      }
      else if ("path" in navGroup)
        navListData.append({
          text = "name" in navGroup ? navGroup.name : navGroup.path
          path = navGroup.path
          depth = depth
        })
  }


  isNavListObjFilled = false
  function fillNavListObj(forceUpdate = false) {
    if (!this.isNavigationVisible && this.getObj("nav_list").isFocused())
      this.setFocusToFileTable()

    showObjById("nav_list", this.isNavigationVisible, this.scene)
    showObjById("nav_seperator", this.isNavigationVisible, this.scene)

    let navListObj = this.getObj("nav_list")
    if (!navListObj || (this.isNavListObjFilled && !forceUpdate))
      return

    this.isNavListObjFilled = true

    let navList = this.getNavElements()
    let navListData = []
    this.filterNavElements(navList)
    this.fillNavListData(navListData, navList)

    if (navListData.len() == 0) {
      this.isNavigationToggleAllowed = false
      this.isNavigationVisible = false
      showObjById("nav_list", false, this.scene)
      showObjById("nav_seperator", false, this.scene)
    }
    showObjById("btn_navigation", this.isNavigationToggleAllowed, this.scene)

    let view = { items = [] }
    this.cachedPathByNavItemId.clear()
    foreach (idx, navData in navListData) {
      let id = $"nav_item_{idx}"
      if ("path" in navData)
        this.cachedPathByNavItemId[id] <- navData.path
      view.items.append({
        id = id
        isChapter = navData.depth == 0
        itemIcon = "path" in navData ? "#ui/gameuiskin#btn_load_from_file.svg" : ""
        isSelected = false
        itemText = navData.text
      })
    }

    let data = handyman.renderCached(this.navItemListTemplate, view)
    this.guiScene.replaceContentFromText(navListObj, data, data.len(), this)
  }


  isFiltersObjFilled = false
  function fillFiltersObj(forceUpdate = false) {
    let shouldUseFilters = this.filters.len() > 1
    let fileFilterObj = showObjById("file_filter", shouldUseFilters, this.scene)
    if (!fileFilterObj || !shouldUseFilters || (this.isFiltersObjFilled && !forceUpdate))
      return

    this.isNavListObjFilled = true

    let view = { items = [] }
    local selectedIdx = 0
    foreach (idx, filter in this.filters) {
      view.items.append({
        id = $"filter_{idx}"
        isAllFiles = filter == this.allFilesFilter
        fileExtension = filter
        fileExtensionUpper = filter.toupper()
      })
      if (filter == this.currentFilter)
        selectedIdx = idx
    }

    let data = handyman.renderCached(this.filterSelectTemplate, view)
    this.guiScene.replaceContentFromText(fileFilterObj, data, data.len(), this)
    fileFilterObj.setValue(selectedIdx)
  }


  // ================================================================
  // ====================== SORT COMPORATORS ========================
  // ================================================================

  function fileDataComporator(lhs, rhs) {
    foreach (columnSource in [this.columnSortOrder, this.visibleColumns])
      foreach (sortInfo in columnSource) {
        let column = sortInfo.column
        let lhsValue = getTblValue(column.name, lhs, null)
        let rhsValue = getTblValue(column.name, rhs, null)
        let result = column.comparator(lhsValue, rhsValue)
        if (result != 0)
          return result * (getTblValue("reverse", sortInfo, false) ? -1 : 1)
      }
    return 0
  }

  static function compareObjOrNull(lhs, rhs) {
    return (lhs != null ? 1 : 0) - (rhs != null ? 1 : 0)
  }

  static function compareStringOrNull(lhs, rhs) {
    return lhs == rhs ? 0
      : (gui_handlers.FileDialog.compareObjOrNull(lhs, rhs)
        || (lhs > rhs ? 1 : lhs < rhs ? -1 : 0))
  }

  static function compareIntOrNull(lhs, rhs) {
    return gui_handlers.FileDialog.compareObjOrNull(lhs, rhs)
      || (lhs != null ? lhs - rhs : 0)
  }
}
