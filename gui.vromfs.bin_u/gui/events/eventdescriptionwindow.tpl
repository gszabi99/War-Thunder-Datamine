root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute';
    width:t='1@slotbarWidthFull';
    max-width:t='800*@sf/@pf_outdated + 2@framePadding';
    max-height:t='@rh'
    <<#showOkButton>>
    class:t='wndNav';
    <</showOkButton>>
    <<^showOkButton>>
    class:t='wnd';
    <</showOkButton>>

    timer {
      id:t='vehicle_require_feature_timer';
      timer_handler_func:t='onTimerUpdate';
    }

    frame_header {
      <<#eventHeader>>
      img {
        id:t='difficulty_img';
        size:t='1@unlockStageIconSize,1@unlockStageIconSize';
        pos:t='0,50%ph-50%h';
        position:t='relative';
        background-image:t='<<difficultyImage>>';
        tooltip:t='<<difficultyTooltip>>';
      }

      activeText {
        id:t='event_name';
        text:t='<<eventName>>';
        caption:t='yes';
      }
      <</eventHeader>>

      Button_close {}
    }

    tdiv {
      id:t = 'item_desc'
      flow:t = 'vertical'
      size:t = 'fw, ph'
      overflow-y:t='auto'
    }

    <<#showOkButton>>
    navBar {
      navRight {
        Button_text {
          id:t='btn_close';
          text:t='#mainmenu/btnOk';
          btnName:t='A';
          _on_click:t='goBack';
          ButtonImg {}
        }
      }
    }
    <</showOkButton>>
  }
}
