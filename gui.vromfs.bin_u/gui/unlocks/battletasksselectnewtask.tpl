frame {
  size:t='0.8@sf, 1@maxWindowHeight'
  class:t='wndNav'
  isCenteredUnderLogo:t='yes'

  frame_header {
    activeText {
      text:t='#mainmenu/battleTasks/selectNewTask'
      caption:t='yes'
    }
  }

  tdiv {
    id:t='tasks_list_frame'
    size:t='pw, fh'
    position:t='relative'
    flow:t='vertical'

    listbox {
      id:t='tasks_list'
      size:t='pw, fh'
      overflow-y:t='auto';
      flow:t='vertical'
      scrollBox-dontResendShortcut:t="yes"

      on_select:t='onSelectTask'

      selImgType:t='gamepadFocused'

      include "gui/unlocks/battleTasksItem"
    }
  }

  navBar {
    navLeft {
      Button_text {
        id:t = 'btn_requirements_list'
        text:t = '#unlocks/requirements'
        _on_click:t = 'onViewBattleTaskRequirements'
        btnName:t='Y'
        ButtonImg {}
      }
    }
    navRight {
      Button_text {
        id:t = 'btn_select'
        text:t = '#mainmenu/btnSelect'
        _on_click:t = 'onSelect'
        btnName:t='A'
        ButtonImg {}
      }
    }
  }
}
