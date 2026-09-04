frame {
  size:t='1.1@scrn_tgt, 1@maxWindowHeight'
  class:t='wndNav'
  isCenteredUnderLogo:t='yes'

  frame_header {
    HorizontalListBox {
      id:t='cmh_tabs'
      class:t='header'
      height:t='ph'
      activeAccesskeys:t='RS'
      on_select:t='onSelectGroup'
      <<@tabs>>
    }

    Button_close {}
  }

  tdiv {
    size:t='pw, fh'
    position:t='relative'
    flow:t='horizontal'

    tdiv {
      size:t='0.32pw, ph'
      position:t='relative'
      flow:t='vertical'
      listbox {
        id:t='cmh_list'
        size:t='pw, fh'
        overflow-y:t='auto'
        flow:t='vertical'
        on_select:t='onSelectUnlock'
        navigatorShortcuts:t='yes'
        selImgType:t='gamepadFocused'
      }

      //chapter progress footer: completed/total + bar
      tdiv {
        width:t='pw'
        flow:t='vertical'
        margin-top:t='1@blockInterval'
        textareaNoTab {
          id:t='cmh_group_count'
          left:t='pw-w'
          position:t='relative'
          text:t=''
          smallFont:t='yes'
          overlayTextColor:t='active'
        }
        battleTaskProgress {
          id:t='cmh_group_progress'
          width:t='pw'
          margin-top:t='1@blockInterval'
          max:t='1000'
          value:t=''
        }
      }
    }

    profileContentSeparator {}

    tdiv {
      id:t='cmh_detail'
      size:t='fw, ph'
      position:t='relative'
      overflow-y:t='auto'
    }
  }
}
