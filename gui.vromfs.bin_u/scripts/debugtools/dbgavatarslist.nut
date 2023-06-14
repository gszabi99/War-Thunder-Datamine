//-file:plus-string
from "%scripts/dagui_library.nut" import *


let DataBlock  = require("DataBlock")
let { Point2 } = require("dagor.math")
let { format } = require("string")
let { fabs } = require("math")
let bhvAvatar = require("%scripts/user/bhvAvatar.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let stdPath = require("%sqstd/path.nut")
let avatars = require("%scripts/user/avatars.nut")
let dagor_fs = require("dagor.fs")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { register_command } = require("console")

enum avatarPlace { //higher index has more priority to show icon when same icons in the different places
  IN_GAME         = 0x01
  IN_PKG_DEV      = 0x02
  IN_MAIN_FOLDER  = 0x04
}

let roundVal = @(val) stdMath.round_by_value(clamp(val, 0.0, 1.0), 0.01)

let function debugAvatars(filePath) {
  let blk = DataBlock()
  if (!blk.tryLoad(filePath))
    return $"Failed to load avatars config from {filePath}"

  ::handlersManager.loadHandler(::gui_handlers.DbgAvatars, { savePath = filePath, configBlk = blk })
  return "Done"
}

register_command(@() debugAvatars("../develop/gameBase/config/avatars.blk"), "debug.avatars")
register_command(debugAvatars, "debug.avatars_by_file_path")

::gui_handlers.DbgAvatars <- class extends ::BaseGuiHandler {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/debugTools/dbgAvatars.tpl"

  savePath = ""
  configBlk = null
  configBlkOriginal = null

  fullIconsList = null
  iconsMap = null
  mainAvatarConfig = null

  selectedAvatar = "cardicon_default"

  isInEditMode = false
  editStartPos = null
  lastMainBorderSize = null
  lastMainBorderPos = null
  shouldUpdateBorder = true

  sliders = [
    {
      id = "size"
      getValue = @() this.getSelAvatarBlk().size
      setValue = @(v) this.getSelAvatarBlk().size = v
    }
    {
      id = "posX"
      getValue = @() this.getSelAvatarBlk().pos.x
      setValue = @(v) this.getSelAvatarBlk().pos.x = v
    }
    {
      id = "posY"
      getValue = @() this.getSelAvatarBlk().pos.y
      setValue = @(v) this.getSelAvatarBlk().pos.y = v
    }
  ]

  function getSceneTplView() {
    this.mainAvatarConfig = bhvAvatar.getCurParams()
    bhvAvatar.init({
      getConfig = (@() this.configBlk).bindenv(this)
      intIconToString = this.getIconByIdx.bindenv(this)
      getIconPath = this.getIconPath.bindenv(this)
    })

    this.initAvatarsList()

    return {
      savePath = this.savePath
      avatars = this.fullIconsList.map(@(icon)
        { name = icon.name
          isPkgDev = icon.place & avatarPlace.IN_PKG_DEV
          isOnlyInGame = icon.place == avatarPlace.IN_GAME
          isOnlyInResources = !(icon.place & avatarPlace.IN_GAME)
        })
      sliders = this.sliders
    }
  }

  function initAvatarsList() {
    this.fullIconsList = []
    this.iconsMap = {}

    let mainList = ["cardicon_default", "cardicon_bot"]
    mainList.extend(avatars.getIcons())
    foreach (name in mainList)
      this.addAvatarConfig(name, avatarPlace.IN_GAME, this.mainAvatarConfig.getIconPath(name))

    let fileMask = "*"
    let guiPath = "../develop/gui/"
    let dirs = {
      ["menu/images/images/avatars"] = avatarPlace.IN_MAIN_FOLDER,
      ["menu/pkg_dev/images/images/avatars"] = avatarPlace.IN_PKG_DEV,
    }
    foreach (dirPath, place in dirs) {
      let filePaths = dagor_fs.scan_folder({ root = guiPath + dirPath, vromfs = false, realfs = true, recursive = true, files_suffix = fileMask })
      foreach (path in filePaths)
        this.addAvatarConfig(stdPath.fileName(path).slice(0, -4), place, path)
    }
  }

  function addAvatarConfig(name, place, path) {
    local icon = this.iconsMap?[name]
    if (icon) {
      if (icon.place < place)
        icon.path = path
      icon.place = icon.place | place
      return
    }

    icon = {
      name = name
      place = place
      path = path
    }
    this.fullIconsList.append(icon)
    this.iconsMap[name] <- icon
  }

  function initScreen() {
    this.configBlkOriginal = DataBlock()
    this.configBlkOriginal.setFrom(this.configBlk)
    this.scene.findObject("edit_update").setUserData(this)
    this.setAvatar("cardicon_default")
  }

  getIconByIdx = @(idx) this.fullIconsList?[idx]?.name ?? ""
  getIconPath = @(name) this.iconsMap?[name]?.path ?? ""

  function save() {
    this.configBlk.saveToTextFile(this.savePath)
  }

  function saveAndExit() {
    this.save()
    base.goBack()
  }

  function goBack() {
    if (u.isEqual(this.configBlk, this.configBlkOriginal))
      return base.goBack()

    this.msgBox("save", "should save changes?",
    [
      ["yes", this.saveAndExit ],
      ["no", base.goBack ]
    ],
    "yes", { cancel_fn = function() {} })
  }

  function onDestroy() {
    bhvAvatar.init(this.mainAvatarConfig)
  }

  function onAvatarSelect(obj) {
    this.setAvatar(this.fullIconsList?[obj.getValue()]?.name)
  }

  function setAvatar(avatar) {
    if (!avatar)
      return

    this.isInEditMode = false
    this.selectedAvatar = avatar
    foreach (name in ["sel_name", "sel_big_icon", "sel_small_icon"])
      this.scene.findObject(name).setValue(this.selectedAvatar)
    this.updateEditControls()
  }

  function onSelAvatarSizeChange() {
    bhvAvatar.forceUpdateView(this.scene.findObject("sel_small_icon"))
    let listObj = this.scene.findObject("avatars_list")
    foreach (idx, avatar in this.fullIconsList)
      if (avatar.name == this.selectedAvatar)
        bhvAvatar.forceUpdateView(listObj.getChild(idx).findObject("small_icon"))
    this.updateEditControls()
  }

  function updateEditControls() {
    let avatarBlk = this.getSelAvatarBlk()
    foreach (s in this.sliders) {
      let value = s.getValue.call(this)
      this.scene.findObject(s.id + "_text").setValue(value.tostring())
    }

    if (this.shouldUpdateBorder) {
      let editBorder = this.showSceneBtn("edit_border", this.isInEditMode)
      let mainBorder = this.showSceneBtn("main_border", !this.isInEditMode && avatarBlk.size < 1)
      let curBorder = this.isInEditMode ? editBorder : mainBorder
      curBorder.pos = format("%.2fpw, %.2fph", avatarBlk.pos.x, avatarBlk.pos.y)
      curBorder.size = format("%.2fpw,%.2fph", avatarBlk.size, avatarBlk.size)
    }
  }

  function getSelAvatarBlk() {
    if (!(this.selectedAvatar in this.configBlk)) {
      let blk = DataBlock()
      blk.pos = Point2(0, 0)
      blk.size = 1.0
      this.configBlk[this.selectedAvatar] <- blk
    }
    return this.configBlk[this.selectedAvatar]
  }

  function getMousePosPart() {
    let obj = this.scene.findObject("sel_big_icon")
    let coords = ::get_dagui_mouse_cursor_pos()
    let objPos = obj.getPosRC()
    let objSize = obj.getSize()
    return Point2(roundVal((coords[0] - objPos[0]).tofloat() / (objSize[0] || 1)),
                    roundVal((coords[1] - objPos[1]).tofloat() / (objSize[1] || 1)))
  }

  function validateCorners(pos1, pos2) {
    foreach (key in ["x", "y"])
      if (pos1[key] > pos2[key]) {
        let t = pos1[key]
        pos1[key] = pos2[key]
        pos2[key] = t
      }
  }

  function onEditStart(_obj) {
    let avatarBlk = this.getSelAvatarBlk()
    this.editStartPos = this.getMousePosPart()
    avatarBlk.pos = this.editStartPos
    avatarBlk.size = 0.0
    this.onSelAvatarSizeChange()
    this.isInEditMode = true
  }

  function updateEditSize() {
    let avatarBlk = this.getSelAvatarBlk()
    let pos1 = Point2(this.editStartPos.x, this.editStartPos.y)
    let pos2 = this.getMousePosPart()
    this.validateCorners(pos1, pos2)
    avatarBlk.pos = pos1
    avatarBlk.size = max(pos2.x - pos1.x, pos2.y - pos1.y)
  }

  function onEditUpdate(_obj = null, _dt = 0.0) {
    if (this.isInEditMode) {
      this.updateEditSize()
      this.onSelAvatarSizeChange()
    }
    else
      this.checkMainFrameMovement()
  }

  function onEditDone(_obj) {
    if (!this.isInEditMode)
      return
    this.updateEditSize()
    this.isInEditMode = false
    this.onSelAvatarSizeChange()
  }

  function checkMainFrameMovement() {
    let mainBorder = this.scene.findObject("main_border")
    if (!mainBorder.isVisible())
      return

    let size = mainBorder.getSize()
    let pos = mainBorder.getPosRC()
    if (size[0] <= 0 || size[1] <= 0)
      return

    local hasChanges = false
    if (!u.isEqual(size, this.lastMainBorderSize)
      || !u.isEqual(pos, this.lastMainBorderPos)) {
      let avatarBlk = this.getSelAvatarBlk()
      let obj = this.scene.findObject("sel_big_icon")
      let objPos = obj.getPos()
      let objSize = obj.getSize()

      let realPos = Point2(roundVal((pos[0] - objPos[0]).tofloat() / objSize[0]),
                               roundVal((pos[1] - objPos[1]).tofloat() / objSize[1]))
      if (fabs(avatarBlk.pos.x - realPos.x) > 0.001
        || fabs(avatarBlk.pos.y - realPos.y) > 0.001) {
        avatarBlk.pos = realPos
        hasChanges = true
      }

      let realSize = roundVal(max(size[0], size[1]).tofloat() / objSize[0])
      if (fabs(avatarBlk.size - realSize) > 0.001) {
        avatarBlk.size = realSize
        hasChanges = true
      }
    }

    this.lastMainBorderSize = size
    this.lastMainBorderPos = pos
    if (hasChanges) {
      let avatarBlk = this.getSelAvatarBlk()
      let maxSize = min(1.0 - avatarBlk.pos.x, 1.0 - avatarBlk.pos.y)
      if (avatarBlk.size > maxSize)
        avatarBlk.size = roundVal(maxSize)
      this.shouldUpdateBorder = false
      this.onSelAvatarSizeChange()
      this.shouldUpdateBorder = true
    }
  }

  function onSave() {
    this.save()
    this.configBlkOriginal.setFrom(this.configBlk)
  }

  function onReset() {
    let avatarBlk = this.getSelAvatarBlk()
    avatarBlk.size = 1.0
    avatarBlk.pos = Point2()
    this.onSelAvatarSizeChange()
  }

  function onRestore() {
    let avatarBlk = this.getSelAvatarBlk()
    let prevAvatarBlk = this.configBlkOriginal?[this.selectedAvatar]
    if (!prevAvatarBlk) {
      this.onReset()
      return
    }

    avatarBlk.setFrom(prevAvatarBlk)
    this.onSelAvatarSizeChange()
  }
}
