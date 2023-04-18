frame {
  id:t='wnd_frame'
  width:t='1@scrn_tgt'
  class:t='wnd'
  type:t='big'
  isCenteredUnderLogo:t='yes'

  frame_header {
    HorizontalListBox {
      id:t='tabs_list'
      height:t='1@frameHeaderHeight'
      position:t='relative'
      activeAccesskeys:t='RS'
      class:t='header'
      on_select:t = 'onTabChange'
      include "%gui/frameHeaderTabs.tpl"
    }
    textarea {
      id:t='info_txt'
      right:t='1@buttonCloseHeight'
      top:t='0.5ph-0.5h'
      position:t='absolute'
      padding:t='1@blockInterval, 0'
    }
    Button_close {
      id:t = 'btn_back'
    }
  }

  tdiv {
    width:t='pw'
    id:t='rewards_content'
    padding:t='0.01@scrn_tgt, 0.01@scrn_tgt, 0, 0.01@scrn_tgt'
    flow:t='vertical'
    max-height:t='0.8@scrn_tgt - @minYposWindow - 0.1*(sh - 1@minYposWindow - h)'
    overflow:t='auto'
    scrollbarShortcuts:t='yes'
  }
}
