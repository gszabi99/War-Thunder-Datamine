root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    max-height:t='1@maxWindowHeightNoSrh'
    position:t='absolute'
    class:t='wnd'
    padByLine:t='yes'

    frame_header {
      activeText {
        id:t='wnd_title'
        caption:t='yes'
        text:t='<<frameHeaderText>>'
      }
      Button_close {}
    }
    tdiv {
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      include "%gui/items/craftTreeContent.tpl"
    }
  }
}
