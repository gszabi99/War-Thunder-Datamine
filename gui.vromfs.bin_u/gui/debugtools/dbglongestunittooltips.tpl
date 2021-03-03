root {
  blur {}
  blur_foreground {}

  DummyButton {
    on_click:t = 'goBack'
    on_r_click:t='goBack'
    btnName:t='B'
    size:t='sw, sh'
  }

  frame {
    size:t='sw, sh'
    pos:t='50%sw-50%w, 50%sh-50%h'
    position:t='absolute'

    tdiv {
      size:t='1@rw, 1@rh'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'

      //Display game working area, including safe area
      border:t='yes'
      border-color:t='@yellow'

      overflow-x:t='auto'

      tdiv {
        id:t='wnd_frame'
        height:t='ph'
        behavior:t='posNavigator'

        navigatorShortcuts:t='yes'

        <<#unitType>>
        tdiv {
          overflow-y:t='auto'
          margin:t='1@framePadding, 0'

          //Use for visual separation of each tooltip, and info in block
          border:t='yes';
          border-color:t='@silver'

          tooltipObj {
            id:t='<<typeName>>'
          }
        }
        <</unitType>>

        tdiv {
          id:t='sample_unit'
          overflow-y:t='auto'
          margin-right:t='0.5@framePadding, 0'

          tooltipObj {
            id:t='sample_type'
          }
        }
      }
    }
  }

  timer {
    id:t='update_timer'
    timer_handler_func:t='onUpdate'
  }
}