local { isPlatformPS4, isPlatformPS5, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

::gui_start_gamepad_cursor_controls_splash <- function gui_start_gamepad_cursor_controls_splash(onEnable)
{
  ::gui_start_modal_wnd(::gui_handlers.GampadCursorControlsSplash, {onEnable = onEnable})
}


class ::gui_handlers.GampadCursorControlsSplash extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controls/gamepadCursorControlsSplash.blk"
  onEnable = null

  controller360View = {
    image = "#ui/images/controller/controller_xbox360"
    rightTrigger = {
     contactPointX = "pw-510"
     contactPointY = "297"
    }
    leftStick = {
      contactPointX = "470"
      contactPointY = "452"
    }
    rightStick = {
      contactPointX = "pw-570"
      contactPointY = "550"
    }
  }

  controllerDualshock4View = {
    image = "#ui/images/controller/controller_dualshock4"
    rightTrigger = {
     contactPointX = "pw-432"
     contactPointY = "297"
    }
    leftStick = {
      contactPointX = "520"
      contactPointY = "552"
    }
    rightStick = {
      contactPointX = "pw-542"
      contactPointY = "560"
    }
  }

  controllerDualsenseView = {
    image = "#ui/images/controller/controller_dualsense"
    rightTrigger = {
     contactPointX = "pw-432"
     contactPointY = "297"
    }
    leftStick = {
      contactPointX = "540"
      contactPointY = "555"
    }
    rightStick = {
      contactPointX = "pw-540"
      contactPointY = "555"
    }
  }

  controllerXboxOneView = {
    image = "#ui/images/controller/controller_xbox_one"
    rightTrigger = {
     contactPointX = "pw-480"
     contactPointY = "305"
    }
    leftStick = {
      contactPointX = "490"
      contactPointY = "460"
    }
    rightStick = {
      contactPointX = "pw-570"
      contactPointY = "570"
    }
  }

  static function isDisplayed()
  {
    return ::loadLocalByAccount("gamepad_cursor_controls_splash_displayed", false)
  }


  static function markDisplayed()
  {
    ::saveLocalByAccount("gamepad_cursor_controls_splash_displayed", true)
  }


  function initScreen()
  {
    local contentObj = scene.findObject("content")
    if (!::check_obj(contentObj))
      goBack()

    local view = controller360View
    if (isPlatformPS4)
      view = controllerDualshock4View
    else if (isPlatformPS5)
      view = controllerDualsenseView
    else if (isPlatformXboxOne)
      view = controllerXboxOneView

    local markUp = ::handyman.renderCached("gui/controls/gamepadCursorcontrolsController", view)
    guiScene.replaceContentFromText(contentObj, markUp, markUp.len(), this)
  }


  function enableGamepadCursorcontrols()
  {
    if (::g_gamepad_cursor_controls.canChangeValue())
    {
      ::g_gamepad_cursor_controls.setValue(true)
      if (onEnable)
        onEnable()
    }
    goBack()
  }


  function goBack()
  {
    markDisplayed()
    base.goBack()
  }


  function getNavbarTplView()
  {
    return {
      middle = [
        {
          text = "#gamepad_cursor_control_splash/accept"
          shortcut = "A"
          funcName = "enableGamepadCursorcontrols"
          isToBattle = true
          button = true
        }
      ]
      left = [
        {
          text = "#gamepad_cursor_control_splash/decline"
          shortcut = "B"
          funcName = "goBack"
          button = true
        }
      ]
    }
  }
}
