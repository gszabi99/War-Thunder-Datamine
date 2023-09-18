root {
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    size:t='1@maxWindowWidth $min 1200@sf/@pf, 1@rh $min 1200@sf/@pf'
    pos:t='pw/2-w/2, ph/2-h/2'
    position:t='absolute'
    class:t='wnd'

    frame_header {
      activeText { id:t='wnd_title'; caption:t='yes'; text:t='#controls/help/rwr/threat_types' }
      Button_close {}
    }

    tdiv {
      size:t='pw, fh'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'

      tdiv {
        width:t='pw - 1@scrollBarSize'
        min-height:t='ph'
        padding:t='10@sf/@pf, 0, 10@sf/@pf, 10@sf/@pf'
        flow:t='vertical'

        <<#rows>>
        tdiv {
          width:t='pw'
          flow:t='horizontal'

          <<#title>>
          textareaNoTab {
            width:t='pw'
            position:t='relative'
            margin:t='0, 10@sf/@pf'
            overlayTextColor:t='active'
            text:t='<<title>>'
          }
          <</title>>
          <<^title>>
          textareaNoTab {
            width:t='120@sf/@pf'
            position:t='relative'
            style:t='color:#50FF50;'
            text:t='<<name>>'
          }
          textareaNoTab {
            width:t='fw'
            position:t='relative'
            text:t='<<desc>>'
          }
          <</title>>
        }
        <</rows>>
      }
    }
  }
}
