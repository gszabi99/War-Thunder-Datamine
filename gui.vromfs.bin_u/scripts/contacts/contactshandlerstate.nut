from "%scripts/dagui_library.nut" import *

local contactsHandlerClass = null // class for load contacts window
local contactsHandler = null  // loaded contacts window

let function loadContactsToObj(obj, owner) {
  if (!checkObj(obj) || contactsHandlerClass == null)
    return

  let guiScene = obj.getScene()
  if (contactsHandler == null)
    contactsHandler = contactsHandlerClass(guiScene)
  contactsHandler.owner = owner
  contactsHandler.initScreen(obj)
}

let function switchContactsObj(scene, owner) {
  let objName = "contacts_scene"
  local obj = null
  if (checkObj(scene)) {
    obj = scene.findObject(objName)
    if (!obj) {
      scene.getScene().appendWithBlk(scene, "".concat("tdiv { id:t='", objName, "' }"))
      obj = scene.findObject(objName)
    }
  }
  else {
    let guiScene = get_gui_scene()
    obj = guiScene[objName]
    if (!checkObj(obj)) {
      guiScene.appendWithBlk("", "".concat("tdiv { id:t='", objName, "' }"))
      obj = guiScene[objName]
    }
  }

  if (contactsHandler == null)
    loadContactsToObj(obj, owner)
  else
    contactsHandler.switchScene(obj, owner)
}

let isContactsWindowActive = @() contactsHandler?.isContactsWindowActive() ?? false

return {
  getContactsHandler = @() contactsHandler
  setContactsHandlerClass = @(handlerClass) contactsHandlerClass = handlerClass
  switchContactsObj
  isContactsWindowActive
}
