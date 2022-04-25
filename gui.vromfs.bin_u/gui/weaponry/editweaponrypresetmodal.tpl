root {
  blur {}
  blur_foreground {}
  frame {
    width:t='13@tierIconSize + 1@modPresetTextMaxWidth + 2@blockInterval'
    class:t='wndNav'
    css-hier-invalidate:t='yes'
    isCenteredUnderLogo:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='#edit/secondary_weapons'
      }
      Button_close { id:t = 'btn_back' }
    }
    tdiv {
      id:t='presetNest'
      include "%gui/weaponry/weaponryPreset"
    }
    navBar {
      navLeft {
        Button_text{
          text:t='#msgbox/btn_cancel'
          on_click:t='goBack'
          btnName:t='B'
          ButtonImg {}
        }
      }
      navRight {
        Button_text {
          id:t='editTier'
          text:t='#msgbox/btn_edit'
          on_click:t='onEditCurrentTier'
          btnName:t=''
          ButtonImg { btnName:t='A' }
          display:t='hide'
          enable:t='no'
        }
        Button_text {
          text:t='#msgbox/btn_rename'
          on_click:t='onPresetRename'
          btnName:t='Y'
          ButtonImg {}
        }
        Button_text{
          text:t='#filesystem/btnSave'
          on_click:t='onPresetSave'
          btnName:t='X'
          ButtonImg {}
        }
      }
    }
  }
}
