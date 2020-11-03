local time = require("scripts/time.nut")
local stdpath = require("std/path.nut")

class ::gui_handlers.FileDialog extends ::gui_handlers.BaseGuiHandlerWT
{
  static wndType = handlerType.MODAL
  static sceneBlkName = "gui/fileDialog/fileDialog.blk"

  static dirPathPartTemplate    = "gui/fileDialog/dirPath"
  static fileTableTemplate      = "gui/fileDialog/fileTable"
  static navItemListTemplate    = "gui/fileDialog/navItemList"
  static filterSelectTemplate   = "gui/fileDialog/filterSelect"

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
        view.tdAlign <- "right"
        return view
      }
    }
    */

    name = {
      header = "#filesystem/fileName"
      getValue = function(file, fileDialog) {
        return ::getTblValue("name", file)
      }
      comparator = function(lhs, rhs) {
        return ::gui_handlers.FileDialog.compareStringOrNull(lhs, rhs)
      }
      width = "fw"
      getView = function(value) {
        local text = value != null ? value : ""
        return {
          text = text
          tooltip = text
          width = width
        }
      }
    }

    mTime = {
      header = "#filesystem/fileMTime"
      getValue = function(file, fileDialog) {
        return ::getTblValue("modifyTime", file)
      }
      comparator = function(lhs, rhs) {
        return ::gui_handlers.FileDialog.compareIntOrNull(lhs, rhs)
      }
      width = "0.18@sf"
      getView = function(value) {
        local text = ""
        local tooltip = "#filesystem/mTimeNotSpecified"
        if (value != null)
        {
          tooltip = time.buildDateTimeStr(value)
          text = time.buildTabularDateTimeStr(value)
        }

        return {
          text = text
          tooltip = tooltip
          width = width
        }
      }
    }

    directory = {
      header = ""
      getValue = function(file, fileDialog) {
        return ::getTblValue("isDirectory", file, false)
      }
      comparator = function(lhs, rhs) {
        return (lhs ? 1 : 0) - (rhs ? 1 : 0)
      }
      width = "h"
      getView = function(value) {
        local fileImage = "#ui/gameuiskin#btn_clear_all.svg"
        local dirImage = "#ui/gameuiskin#btn_load_from_file.svg"
        return {
          text = ""
          tooltip = ""
          width = width
          image = value ? dirImage : fileImage
          imageRawParams = "pos:t = '50%w, 50%ph-50%h'; "
        }
      }
    }

    extension = {
      header = "#filesystem/fileExtension"
      getValue = function(file, fileDialog) {
        if (::getTblValue("isDirectory", file, false))
          return "."

        local filename = file?.name ?? ""
        local fileExtIdx = ::g_string.lastIndexOf(filename, ".")
        if (fileExtIdx == ::g_string.INVALID_INDEX)
          return null

        return ::g_string.utf8ToUpper(filename.slice(fileExtIdx))
      }
      comparator = function(lhs, rhs) {
        return ::gui_handlers.FileDialog.compareStringOrNull(lhs, rhs)
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
          extType = ::loc("filesystem/file") + " " + value
        return {
          text = extType
          tooltip = extType
          width = width
        }
      }
    }

    size = {
      header = "#filesystem/fileSize"
      getValue = function(file, fileDialog) {
        return ::getTblValue("size", file)
      }
      comparator = function(lhs, rhs) {
        return ::gui_handlers.FileDialog.compareIntOrNull(lhs, rhs)
      }
      width = "0.18@sf"
      getView = function(value) {
        local text = ""
        local tooltip = "#filesystem/fileSizeNotSpecified"
        if (value != null)
        {
          text = ::g_measure_type.FILE_SIZE.getMeasureUnitsText(value, true, false);
          tooltip = ::g_measure_type.FILE_SIZE.getMeasureUnitsText(value, true, true);
        }
        return {
          text = text
          tooltip = tooltip
          tdAlign = "right"
          width = width
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
        return ::gui_handlers.FileDialog.compareObjOrNull(lhs, rhs) ||
          (lhs != null ? lhs.column.comparator(lhs.value, rhs.value) * lhs.multiplier : 0)
      }
    }
  }

  static defaultFsFunctions = {
    validatePath = function(path)
    {
      return (path && path != ""
        && (::is_platform_windows
          ? (path.len() >= 2 && path[1] == ':')
          : path[0] == '/'))
    }

    readDirFiles = function(path, maxFiles)
    {
      if (!validatePath(path))
        return []
      local files = ::find_files_ex(stdpath.join(path, allFilesFilter), maxFiles)
      foreach(file in files)
        if ("name" in file)
          file.fullPath <- stdpath.join(path, file.name)
      return files
    }

    readFileInfo = function(path)
    {
      if (!validatePath(path))
        return null
      local basename = stdpath.fileName(path)
      local files = ::find_files_ex(path, 1)
      if (files.len() > 0 && ::getTblValue("name", files[0]) == basename)
        return files[0]

      if (files.len() == 0)
        files = ::find_files_ex(stdpath.join(path, allFilesFilter), 1)
      if (files.len() > 0)
        return {name = basename, isDirectory = true}
      return null
    }

    getFileName = function(file) {
      return ::getTblValue("name", file, "")
    }

    getFileFullPath = function(file) {
      return ::getTblValue("fullPath", file, "")
    }

    isExists = function(file) {
      return file != null && "name" in file
    }

    isDirectory = function(file) {
      return file != null && ::getTblValue("isDirectory", file, false)
    }

    getNavElements = function()
    {
      // Filtering non-existent elements is performed when filling navigation bar
      local favorites = []
      favorites.append({
        name = "#filesystem/gamePaths"
        childs = [
          { name = "#filesystem/gameSaves",
            path = stdpath.normalize(::get_save_load_path()) },
          { name = "#filesystem/gameExe",
            path = stdpath.parentPath(stdpath.normalize(::get_exe_dir())) }
        ]
      })

      if (::is_platform_windows)
      {
        local disks = {name = "#filesystem/winDiskDrives", childs = []}
        for (local diskChar = 'C' ; diskChar <= 'Z'; diskChar++)
        {
          local path = diskChar.tochar() + ":"
          disks.childs.append({path = path})
        }
        favorites.append(disks)
      }
      else if (::target_platform == "macosx")
      {
        favorites.append({
          name = "#filesystem/fsMountPoints"
          childs = [
            { name = "#filesystem/fsRoot", path = "/" },
            { path = "/Users" },
            { path = "/Volumes" }
          ]
        })
      }
      else /* base template for other unix-based OS */
      {
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

  function initScreen()
  {
    if (!scene)
      return goBack()

    // Init defaults
    if (dirPath != "")
      dirPath = stdpath.normalize(dirPath)
    else if (::is_platform_windows)
      dirPath = "C:"
    else
      dirPath = "/"

    columns = columns || {}
    visibleColumns = visibleColumns ||
      ["directory", "name", "mTime", "extension", "size"]
    columnSortOrder = columnSortOrder || [
      // Sort by "directory" always and before sorting by user selected column
      {column = "directory", reverse = true}
      "userSort"
    ]

    filters = (filters && filters.len() > 0) ? filters : []
    if (currentFilter && !::isInArray(currentFilter, filters))
      filters.append(currentFilter)
    if (shouldAddAllFilesFilter && !::isInArray(allFilesFilter, filters))
      filters.append(allFilesFilter)
    currentFilter = currentFilter ||
      (::isInArray(allFilesFilter, filters) ? allFilesFilter : filters[0])

    if (extension && currentFilter != allFilesFilter && extension != currentFilter)
    {
      ::script_net_assert_once("FileDialog: extension not same as currentFilter",
        "FileDialog: specified extension is not same as currentFilter")
      goBack()
      return
    }

    if (onSelectCallback == null)
    {
      ::script_net_assert_once("FileDialog: null onSelectCallback",
        "FileDialog: onSelectCallback not specified")
      goBack()
      return
    }

    dirHistoryBefore = []
    dirHistoryAfter  = []
    cachedFileNameByTableRowId      = {}
    cachedTableRowIdxByFileName     = {}
    cachedFileFullPathByFileName    = {}
    cachedColumnNameByTableColumnId = {}
    cachedPathByPathPartId          = {}
    lastSelectedFileByPath          = {}
    cachedPathByNavItemId           = {}
    cachedFilterByItemId            = {}

    foreach (funcName, func in defaultFsFunctions)
      if (!this[funcName])
        this[funcName] = func

    // Fill columns structure
    prepareColums()
    if (!validateColums())
    {
      goBack()
      return
    }

    // Update screen
    getObj("dialog_header").setValue(
      ::loc(isSaveFile ? "filesystem/savefile" : "filesystem/openfile"))
    updateAllDelayed()

    ::move_mouse_on_child_by_value(getObj("file_table"))

    restorePathFromSettings()
  }


  // ================================================================
  // =========================== HANDLERS ===========================
  // ================================================================

  function onFileTableClick(obj)
  {
    setFocusToFileTable()
    updateSelectedFileName()
  }


  function onFileTableDblClick()
  {
    onOpen()
  }


  function onNavigation()
  {
    if (!isNavigationToggleAllowed)
      return

    isNavigationVisible = !isNavigationVisible
    fillNavListObj()
  }


  function onForward()
  {
    moveInHistory(1)
  }


  function onBack()
  {
    moveInHistory(-1)
  }


  function onUp()
  {
    local parentPath = stdpath.parentPath(dirPath)
    if (parentPath != null)
      openDirectory(parentPath)
  }


  function onCancel()
  {
    goBack()
  }


  function onOpen()
  {
    local dirPathObj = getObj("dir_path")
    local fileNameObj = getObj("file_name")

    if (dirPathObj.isFocused())
      onDirPathEditBoxActivate()
    else if (fileNameObj.isFocused())
      onFileNameEditBoxActivate()
    else
    {
      updateSelectedFileName()

      local fullPath = ::getTblValue(fileName, cachedFileFullPathByFileName) ||
        stdpath.join(dirPath, fileName)
      if (fullPath != "")
        openFileOrDir(fullPath)
    }
  }


  function onDirPathEditBoxFocus()
  {
    guiScene.performDelayed(this, fillDirPathObj)
  }


  function onRefresh()
  {
    local dirPathObj = getObj("dir_path")
    local path = dirPathObj.isFocused() ? dirPathObj.getValue() : dirPath
    openDirectory(path)
    ::move_mouse_on_child_by_value(getObj("file_table"))
  }


  function onDirPathEditBoxActivate()
  {
    local dirPathObj = getObj("dir_path")
    local path = dirPathObj.isFocused() ? dirPathObj.getValue() : dirPath
    openFileOrDir(path)
    ::move_mouse_on_child_by_value(getObj("file_table"))
  }


  function onFileNameEditBoxActivate()
  {
    fileName = getObj("file_name").getValue()
    if (fileName != "")
      openFileOrDir(stdpath.join(dirPath, fileName))
  }


  function onFileNameEditBoxCancelEdit()
  {
    onToggleFocusFileName()
  }


  function onDirPathEditBoxCancelEdit()
  {
    onToggleFocusDirPath()
  }


  function onToggleFocusFileName()
  {
    local fileTableObj = getObj("file_table")
    local fileNameObj = getObj("file_name")
    if (fileNameObj.isHovered())
      ::move_mouse_on_child_by_value(fileTableObj)
    else
      ::select_editbox(fileNameObj)
  }

  function onToggleFocusDirPath()
  {
    local fileTableObj = getObj("file_table")
    local dirPathObj = getObj("dir_path")
    if (dirPathObj.isHovered())
      ::move_mouse_on_child_by_value(fileTableObj)
    else
      ::select_editbox(dirPathObj)
  }


  function onFileNameEditBoxChangeValue()
  {
    fileName = getObj("file_name").getValue()
  }


  function onNavListSelect(obj)
  {
    local idx = obj.getValue()
    if (idx < 0 || idx >= obj.childrenCount())
      return

    local item = obj.getChild(idx)
    if (!(item.id in cachedPathByNavItemId))
      return

   local path = cachedPathByNavItemId[item.id]
   if (path != dirPath)
      openDirectory(path)
  }


  function onFileTableSelect(obj)
  {
    updateSelectedFileName()
  }


  function onDirPathPartClick(obj)
  {
    if (obj?.id in cachedPathByPathPartId)
      openDirectory(cachedPathByPathPartId[obj.id])
  }


  function onFileTableColumnClick(obj)
  {
    local objId = obj.id
    local columnName = cachedColumnNameByTableColumnId[objId]
    foreach (column in columns)
    {
      if (column.name != columnName)
        continue

      if (userSortColumn == column)
        isUserSortReverse = !isUserSortReverse
      else
      {
        userSortColumn = column
        isUserSortReverse = false
      }

      guiScene.performDelayed(this, function() {
        fillFileTableObj(true)
      })
      break
    }
  }


  function onFilterChange(obj)
  {
    local idx = obj.getValue()
    if (idx < 0 || idx >= obj.childrenCount() || idx >= filters.len())
      return

    if (filters[idx] != currentFilter)
    {
      currentFilter = filters[idx]
      fillFileTableObj(true)
    }
  }


  // ================================================================
  // ======================= DATA OPERATIONS ========================
  // ================================================================

  function prepareColums()
  {
    // Add columns used for show and sort
    foreach (columnSourceInfo in columnSources)
    {
      local source = this[columnSourceInfo.sourceName]
      foreach (idx, columnInfo in source)
      {
        if (::u.isString(columnInfo))
        {
          columnInfo = {column = columnInfo}
          source[idx] = columnInfo
        }

        if (::u.isString(columnInfo.column))
        {
          local columnName = columnInfo.column
          columns[columnName] <- ::getTblValue(columnName, columns, {})
          columnInfo.column = columns[columnName]
        }
      }
    }

    // Copy attributes from defaults
    foreach (columnName, column in columns)
    {
      column.name <- columnName
      if (!(columnName in defaultColumns))
        continue

      local defaultColumn = defaultColumns[columnName]
      if (column == defaultColumn)
        continue

      column.defaultColumn <- defaultColumn
      foreach (attr, attrValue in defaultColumn)
        if (!(attr in column))
          column[attr] <- attrValue
    }
  }


  function validateColums()
  {
    // Check required attributes
    foreach (columnSourceInfo in columnSources)
    {
      local source = this[columnSourceInfo.sourceName]
      local requiredAttributes = columnSourceInfo.requiredAttributes
      foreach (idx, columnInfo in source)
      {
        local column = columnInfo.column
        foreach (attr in requiredAttributes)
          if (!(attr in column))
          {
            ::script_net_assert_once("ERROR: FileDialog ColumnNoAttr", format(
              "ERROR: FileDialog column " +
              ::getTblValue("name", column, "[UNDEFINED name]") +
              " has not attribute " + attr + " but it is required!"))
            return false
          }
      }
    }
    return true
  }


  setFocusToFileTable = @() ::move_mouse_on_child_by_value(getObj("file_table"))


  function updateSelectedFileName()
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    local selectedRowIdx = fileTableObj.getValue()
    if (selectedRowIdx < 0 || selectedRowIdx >= fileTableObj.childrenCount())
      return

    local childObj = fileTableObj.getChild(selectedRowIdx)
    if (!::check_obj(childObj) ||
      !(childObj?.id in cachedFileNameByTableRowId))
      return

    fileName = cachedFileNameByTableRowId[childObj.id]
    guiScene.performDelayed(this, updateButtons)
    local file = readFileInfo(stdpath.join(dirPath, fileName))
    if (file && !isDirectory(file))
      fillFileNameObj()
  }


  function restorePathFromSettings()
  {
    if (!pathTag)
      return

    local settingName = FILEDIALOG_PATH_SETTING_ID + "/" + pathTag
    local loadBlk = ::load_local_account_settings(settingName)
    dirPath  = ::getTblValue("dirPath",  loadBlk, dirPath)
    fileName = ::getTblValue("fileName", loadBlk, fileName)

    while (!isDirectory(readFileInfo(dirPath)))
    {
      local parentPath = stdpath.parentPath(dirPath)
      if (!parentPath)
        return
      dirPath = parentPath
    }
  }


  function savePathToSettings(path)
  {
    if (!pathTag || dirPath == "")
      return

    local settingName = FILEDIALOG_PATH_SETTING_ID + "/" + pathTag
    local saveBlk = ::DataBlock()
    saveBlk.dirPath = stdpath.parentPath(path)
    saveBlk.fileName = stdpath.fileName(path)
    ::save_local_account_settings(settingName, saveBlk)
  }


  function updateButtons()
  {
    if (!isValid())
      return

    local shouldUseSaveButton = isSaveFile
    if (shouldUseSaveButton && fileName in cachedFileFullPathByFileName)
    {
      local file = readFileInfo(cachedFileFullPathByFileName[fileName])
      shouldUseSaveButton = !isDirectory(file)
    }
    getObj("btn_open").setValue(
      ::loc(shouldUseSaveButton ? "filesystem/btnSave" : "filesystem/btnOpen"))
    getObj("btn_backward").enable(dirHistoryBefore.len() > 0)
    getObj("btn_forward").enable(dirHistoryAfter.len() > 0)
  }


  function moveInHistory(shift)
  {
    if (shift == 0)
      return

    local isForward = shift > 0
    local numSteps = ::abs(shift)

    local sourceList = isForward ? dirHistoryAfter : dirHistoryBefore
    local targetList = isForward ? dirHistoryBefore : dirHistoryAfter

    rememberSelectedFile()
    for (local stepIdx = 0; stepIdx < numSteps; stepIdx++)
    {
      if (sourceList.len() == 0)
        break
      targetList.append(dirPath)
      dirPath = sourceList.pop()
    }
    updateAllDelayed()
  }


  function executeSelectCallback()
  {
    if (onSelectCallback(finallySelectedPath))
    {
      savePathToSettings(finallySelectedPath)
      goBack()
    }
  }


  function openDirectory(path)
  {
    path = stdpath.normalize(path)
    local file = readFileInfo(path)
    if (isDirectory(file))
    {
      rememberSelectedFile()
      if (dirPath == path)
      {
        fillFileTableObj(true)
        return
      }
      dirHistoryBefore.append(dirPath)
      dirHistoryAfter.clear()
      dirPath = path
      fileName = ""
      updateAllDelayed()
      return true
    }
    else
      ::showInfoMsgBox(::loc("filesystem/folderDeleted", {path = path}))
  }


  function openFileOrDir(path)
  {
    path = stdpath.normalize(path)
    local file = readFileInfo(path)
    if (isDirectory(file))
      openDirectory(path)
    else
    {
      finallySelectedPath = path
      if (isSaveFile)
      {
        local folderPath = stdpath.parentPath(path)
        if (shouldAskOnRewrite && isExists(file))
          ::scene_msg_box("filesystem_rewrite_msg_box", null,
            ::loc("filesystem/askRewriteFile", {path = path}),
            [["ok", ::Callback(executeSelectCallback, this) ],
            ["cancel", function() {} ]], "cancel", {})
        else if (!isDirectory(readFileInfo(folderPath)))
          ::showInfoMsgBox(::loc("filesystem/folderDeleted", {path = folderPath}))
        else
        {
          if (!isExists(file) && extension
            && !::g_string.endsWith(finallySelectedPath, "." + extension))
            finallySelectedPath += "." + extension
          executeSelectCallback()
        }
      }
      else
      {
        if (isExists(file))
          executeSelectCallback()
        else
          ::showInfoMsgBox(::loc("filesystem/fileNotExists", {path = path}))
      }
    }
  }

  function rememberSelectedFile()
  {
    local path = ""
    local pathSegments = stdpath.splitToArray(stdpath.join(dirPath, fileName))
    for (local j = 0; j < pathSegments.len() - 1; j++)
    {
      path = stdpath.join(path, pathSegments[j])
      lastSelectedFileByPath[path] <- pathSegments[j + 1]
    }
  }


  function restoreLastSelectedFile()
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    local selectedFile = ::getTblValue(dirPath, lastSelectedFileByPath, fileName)
    if (selectedFile in cachedTableRowIdxByFileName)
    {
      local rowIdx = cachedTableRowIdxByFileName[selectedFile]
      if (rowIdx >= 0 && rowIdx < fileTableObj.childrenCount())
        fileTableObj.setValue(rowIdx)
      return
    }
  }


  function restoreFileName()
  {
    local fileNameObj = getObj("file_name")
    if (fileNameObj && fileName == "")
      fileName = fileNameObj.getValue()
  }


  // ================================================================
  // ======================== FILL FUNCTIONS ========================
  // ================================================================

  function updateAllDelayed()
  {
    restoreFileName()
    guiScene.performDelayed(this, function()
    {
      fillDirPathObj()
      fillFileNameObj()
      fillFileTableObj()
      fillNavListObj()
      fillFiltersObj()
      updateButtons()
    })
  }

  isDirPathObjFilled = null
  isDirPathObjFocused = null
  function fillDirPathObj(forceUpdate = false)
  {
    local dirPathObj = getObj("dir_path")
    if (!dirPathObj)
      return

    local isFocused = dirPathObj.isFocused()
    if (isDirPathObjFilled != null && isDirPathObjFilled == dirPath &&
      isDirPathObjFocused == isFocused && !forceUpdate)
      return

    isDirPathObjFilled = dirPath
    isDirPathObjFocused = isFocused

    getObj("btn_refresh")["tooltip"] =
      ::loc(isFocused ? "filesystem/btnGo" : "filesystem/btnRefresh")
    getObj("btn_refresh_img")["background-image"] = isFocused ?
      "#ui/gameuiskin#spinnerListBox_arrow_up.svg" : "#ui/gameuiskin#refresh.svg"
    getObj("btn_refresh_img")["rotation"] = isFocused ?
      "90" : "0"

    if (isFocused)
    {
      dirPathObj.setValue(dirPath)
      guiScene.replaceContentFromText(dirPathObj, "", 0, this)
    }
    else
    {
      dirPathObj.setValue("")
      local pathParts = stdpath.splitToArray(dirPath)

      cachedPathByPathPartId.clear()
      local view = {items = []}
      local combinedPath = ""
      foreach (idx, pathPart in pathParts)
      {
        combinedPath = stdpath.join(combinedPath, pathPart)
        if (pathPart == "")
          continue

        local id = "dir_path_part_" + idx
        cachedPathByPathPartId[id] <- combinedPath
        view.items.append({
          id = id
          text = pathPart != "/" ? pathPart + " / " : " / "
          tooltip = combinedPath
          onClick = "onDirPathPartClick"
        })
      }

      local data = ::handyman.renderCached(dirPathPartTemplate, view)
      guiScene.replaceContentFromText(dirPathObj, data, data.len(), this)
    }
  }


  function fillFileNameObj()
  {
    local fileNameObj = getObj("file_name")
    if (fileNameObj)
      fileNameObj.setValue(fileName)
  }


  fileTableObjFilledPath = null
  fileTableObjFilledFilter = null
  function fillFileTableObj(forceUpdate = false)
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    if (!forceUpdate && fileTableObjFilledPath == dirPath &&
      fileTableObjFilledFilter == currentFilter)
      return

    fileTableObjFilledPath = dirPath
    fileTableObjFilledFilter = currentFilter

    local filesList = readDirFiles(dirPath, maximumFilesToLoad)
    if (filesList.len() > maximumFilesToLoad)
      filesList = filesList.slice(0, maximumFilesToLoad)
    local filesTableData = []

    cachedFileFullPathByFileName.clear()
    local fileNameMetaAttr = {}
    foreach (file in filesList)
    {
      local fileData = {}
      foreach (columnName, column in columns)
        fileData[columnName] <- column.getValue(file, this)
      local filename = getFileName(file)
      if (!isDirectory(file) && currentFilter != allFilesFilter &&
        !::g_string.endsWith(filename, currentFilter))
        continue
      fileData[fileNameMetaAttr] <- filename
      cachedFileFullPathByFileName[filename] <- getFileFullPath(file)
      filesTableData.append(fileData)
    }

    // sort takes ~85% of fillFileTableObj execution time
    // when read directories with large files number
    filesTableData.sort(fileDataComporator.bindenv(this))

    local view = {rows = []}

    local headerRowView = {
      row_id = "file_header_row"
      isHeaderRow = true
      cells = []
    }
    cachedColumnNameByTableColumnId.clear()
    foreach (visibleColumn in visibleColumns)
    {
      local id = "file_col_" + visibleColumn.column.name
      cachedColumnNameByTableColumnId[id] <- visibleColumn.column.name
      headerRowView.cells.append({
        id = id
        text = visibleColumn.column.header
        callback = "onFileTableColumnClick"
        active = visibleColumn.column == userSortColumn
      })
    }
    view.rows.append(headerRowView)

    local isEven = true
    cachedFileNameByTableRowId.clear()
    cachedTableRowIdxByFileName.clear()
    foreach (idx, fileData in filesTableData)
    {
      local rowId = "file_row_" + idx
      local filename = fileData[fileNameMetaAttr]
      cachedFileNameByTableRowId[rowId] <- filename
      cachedTableRowIdxByFileName[filename] <- idx + 1
      local rowView = {
        row_id = rowId
        even = isEven
        cells = []
      }
      foreach (visibleColumn in visibleColumns)
      {
        local column = visibleColumn.column
        local value = fileData[column.name]
        local cellView = column.getView(value)
        rowView.cells.append(cellView)
      }
      view.rows.append(rowView)
      isEven = !isEven
    }

    local data = ::handyman.renderCached(fileTableTemplate, view)
    guiScene.replaceContentFromText(fileTableObj, data, data.len(), this)
    guiScene.performDelayed(this, restoreLastSelectedFile)
  }


  function filterNavElements(navList)
  {
    for (local k = navList.len() - 1; k >= 0; k--)
    {
      local element = navList[k]
      if ("childs" in element && "name" in element)
      {
        filterNavElements(element.childs)
        if (element.childs.len() != 0)
          continue
      }
      else if ("path" in element)
      {
        element.path = stdpath.normalize(element.path)
        if (!("name" in element))
          element.name <- element.path
        if (isDirectory(readFileInfo(element.path)))
          continue;
      }
      navList.remove(k)
    }
  }


  function fillNavListData(navListData, navList, depth = 0)
  {
    foreach (navGroup in navList)
      if ("childs" in navGroup)
      {
        navListData.append({
          text = "name" in navGroup ? navGroup.name : ""
          depth = depth
        })
        fillNavListData(navListData, navGroup.childs, depth + 1)
      }
      else if ("path" in navGroup)
        navListData.append({
          text = "name" in navGroup ? navGroup.name : navGroup.path
          path = navGroup.path
          depth = depth
        })
  }


  isNavListObjFilled = false
  function fillNavListObj(forceUpdate = false)
  {
    if (!isNavigationVisible && getObj("nav_list").isFocused())
      setFocusToFileTable()

    showSceneBtn("nav_list", isNavigationVisible)
    showSceneBtn("nav_seperator", isNavigationVisible)

    local navListObj = getObj("nav_list")
    if (!navListObj || (isNavListObjFilled && !forceUpdate))
      return

    isNavListObjFilled = true

    local navList = getNavElements()
    local navListData = []
    filterNavElements(navList)
    fillNavListData(navListData, navList)

    if (navListData.len() == 0)
    {
      isNavigationToggleAllowed = false
      isNavigationVisible = false
      showSceneBtn("nav_list", false)
      showSceneBtn("nav_seperator", false)
    }
    showSceneBtn("btn_navigation", isNavigationToggleAllowed)

    local view = {items = []}
    cachedPathByNavItemId.clear()
    foreach (idx, navData in navListData)
    {
      local id = "nav_item_" + idx
      if ("path" in navData)
        cachedPathByNavItemId[id] <- navData.path
      view.items.append({
        id = id
        isChapter = navData.depth == 0
        itemIcon = "path" in navData ? "#ui/gameuiskin#btn_load_from_file.svg" : ""
        isSelected = false
        itemText = navData.text
      })
    }

    local data = ::handyman.renderCached(navItemListTemplate, view)
    guiScene.replaceContentFromText(navListObj, data, data.len(), this)
  }


  isFiltersObjFilled = false
  function fillFiltersObj(forceUpdate = false)
  {
    local shouldUseFilters = filters.len() > 1
    local fileFilterObj = showSceneBtn("file_filter", shouldUseFilters)
    if (!fileFilterObj || !shouldUseFilters || (isFiltersObjFilled && !forceUpdate))
      return

    isNavListObjFilled = true

    local view = {items = []}
    local selectedIdx = 0
    foreach (idx, filter in filters)
    {
      view.items.append({
        id = "filter_" + idx
        isAllFiles = filter == allFilesFilter
        fileExtension = filter
        fileExtensionUpper = filter.toupper()
      })
      if (filter == currentFilter)
        selectedIdx = idx
    }

    local data = ::handyman.renderCached(filterSelectTemplate, view)
    guiScene.replaceContentFromText(fileFilterObj, data, data.len(), this)
    fileFilterObj.setValue(selectedIdx)
  }


  // ================================================================
  // ====================== SORT COMPORATORS ========================
  // ================================================================

  function fileDataComporator(lhs, rhs)
  {
    foreach (columnSource in [columnSortOrder, visibleColumns])
      foreach (sortInfo in columnSource)
      {
        local column = sortInfo.column
        local lhsValue = ::getTblValue(column.name, lhs, null)
        local rhsValue = ::getTblValue(column.name, rhs, null)
        local result = column.comparator(lhsValue, rhsValue)
        if (result != 0)
          return result * (::getTblValue("reverse", sortInfo, false) ? -1 : 1)
      }
    return 0
  }

  static function compareObjOrNull(lhs, rhs)
  {
    return (lhs != null ? 1 : 0) - (rhs != null ? 1 : 0)
  }

  static function compareStringOrNull(lhs, rhs)
  {
    return lhs == rhs ? 0
      : (::gui_handlers.FileDialog.compareObjOrNull(lhs, rhs)
        || (lhs > rhs ? 1 : lhs < rhs ? -1 : 0))
  }

  static function compareIntOrNull(lhs, rhs)
  {
    return ::gui_handlers.FileDialog.compareObjOrNull(lhs, rhs)
      || (lhs != null ? lhs - rhs : 0)
  }
}
