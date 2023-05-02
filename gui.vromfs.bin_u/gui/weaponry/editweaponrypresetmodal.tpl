root {
  blur {}
  blur_foreground {}
  frame {
    id:t='edit_wnd'
    class:t='wndNav'
    pos:t='0.5pw-0.5w, 0.5ph-0.5h'
    position:t='absolute'
    css-hier-invalidate:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='#edit/secondary_weapons'
      }
      Button_close { id:t = 'btn_back' }
    }
    textareaNoTab {
      id:t='weightCapacity'
      width:t='pw'
      margin-left:t='1@modPresetTextMaxWidth'
      text-align:t='center'
      smallFont:t='yes'
    }
    tdiv {
      id:t='presetNest'
      include "%gui/weaponry/weaponryPreset.tpl"
    }
    tdiv {
      width:t='pw'
      textareaNoTab {
        id:t='weightDisbalance'
        width:t='pw'
        text-align:t='right'
        position:t='relative'
        smallFont:t='yes'
        overlayTextColor:t='bad'
      }
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
          id:t='savePreset'
          text:t='#filesystem/btnSave'
          on_click:t='onPresetSave'
          btnName:t='X'
          ButtonImg {}
        }
      }
    }
  }
}
