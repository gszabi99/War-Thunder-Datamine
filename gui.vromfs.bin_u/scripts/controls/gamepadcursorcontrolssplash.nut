from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { isPlatformPS4, isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLinkLinesMarkup } = require("%scripts/linesGenerator.nut")

const GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID = "gamepad_cursor_controls_splash_displayed"

gui_handlers.GampadCursorControlsSplash <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controls/gamepadCursorControlsSplash.blk"

  
  
  

  controllerDualshock4View = {
    image = "#ui/images/controller/controller_dualshock4.ddsx"
    isSwapDirpadAndLStickBubblesPos = false
    dirpad = {
      contactPointX = "168"
      contactPointY = "232"
    }
    leftStick = {
      contactPointX = "290"
      contactPointY = "349"
    }
    rightStick = {
      contactPointX = "549"
      contactPointY = "349"
    }
    actionKey = {
     contactPointX = "698"
     contactPointY = "284"
    }
  }

  controllerDualsenseView = {
    image = "#ui/images/controller/controller_dualsense.ddsx"
    isSwapDirpadAndLStickBubblesPos = false
    dirpad = {
      contactPointX = "163"
      contactPointY = "239"
    }
    leftStick = {
      contactPointX = "289"
      contactPointY = "356"
    }
    rightStick = {
      contactPointX = "551"
      contactPointY = "356"
    }
    actionKey = {
     contactPointX = "702"
     contactPointY = "287"
    }
  }

  controllerXboxOneView = {
    image = "#ui/images/controller/controller_xbox_one.ddsx"
    isSwapDirpadAndLStickBubblesPos = true
    dirpad = {
      contactPointX = "325"
      contactPointY = "334"
    }
    leftStick = {
      contactPointX = "191"
      contactPointY = "259"
    }
    rightStick = {
      contactPointX = "517"
      contactPointY = "387"
    }
    actionKey = {
     contactPointX = "635"
     contactPointY = "277"
    }
  }

  bubblesList = [ "dirpad", "lstick", "rstick", "actionx" ]

  static function open() {
    loadHandler(gui_handlers.GampadCursorControlsSplash)
  }

  static function shouldDisplay() {
    
    let value = loadLocalByAccount(GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID)
    return value == true 
  }

  static function markDisplayed() {
    saveLocalByAccount(GAMEPAD_CURSOR_CONTROLS_SPLASH_DISPLAYED_SAVE_ID, 2)
  }


  function initScreen() {
    let contentObj = this.scene.findObject("content")
    if (!checkObj(contentObj))
      this.goBack()

    let view = isPlatformPS4 ? this.controllerDualshock4View
               : isPlatformPS5 ? this.controllerDualsenseView
               :                 this.controllerXboxOneView

    view.isGamepadCursorControlsEnabled <- ::g_gamepad_cursor_controls.getValue()

    let markUp = handyman.renderCached("%gui/controls/gamepadCursorcontrolsController.tpl", view)
    this.guiScene.replaceContentFromText(contentObj, markUp, markUp.len(), this)

    let linkingObjsContainer = this.getObj("gamepad_image")
    let linesGeneratorConfig = {
      startObjContainer = linkingObjsContainer
      endObjContainer   = linkingObjsContainer
      lineInterval = "@helpLineInterval"
      links = this.bubblesList.map(@(id) { start = $"bubble_{id}", end = $"dot_{id}" })
    }
    let linesMarkup = getLinkLinesMarkup(linesGeneratorConfig)
    this.guiScene.replaceContentFromText(this.getObj("lines_block"), linesMarkup, linesMarkup.len(), this)
  }


  function goBack() {
    this.markDisplayed()
    base.goBack()
  }


  function getNavbarTplView() {
    return {
      right = [
        {
          text = "#msgbox/btn_ok"
          shortcut = "X"
          funcName = "goBack"
          button = true
        }
      ]
    }
  }
}
