root {
  background-color:t='@shadeBackgroundColor'

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    max-height:t='1@maxWindowHeight'
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
      id:t='craft_tree'
      position:t='relative'
      flow:t='vertical'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      tdiv {
        id:t='craft_header'
        include "gui/items/craftTreeHeader"
      }

      craftBranchBody {
        id:t='craft_body'
        size:t='<<bodyWidth>>, <<bodyHeight>>'
        flow:t='h-flow'
        total-input-transparent:t='yes'
        <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>

        behaviour:t='posNavigator'
        navigatorShortcuts:t='yes'
        moveX:t='linear'
        moveY:t='closest'

        include "gui/items/craftTreeBody"
      }
    }
  }
}

DummyButton {
  btnName:t='A'
  on_click:t='onMainAction'
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
