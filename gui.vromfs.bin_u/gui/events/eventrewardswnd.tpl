frame {
  id:t='wnd_frame'
  width:t='1@scrn_tgt';
  pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)';
  position:t='absolute';
  class:t='wnd';
  type:t='big';

  frame_header {
    activeText {
      width:t='fw';
      text:t='<<header>>';
      caption:t='yes';
      pare-text:t='yes';
    }
    Button_close {
      id:t = 'btn_back';
    }
  }

  tdiv {
    width:t='pw';
    id:t='content';
    padding:t='0.01@scrn_tgt, 0.01@scrn_tgt, 0, 0.01@scrn_tgt';
    flow:t='vertical';
    max-height:t='0.8@scrn_tgt - @minYposWindow - 0.1*(sh - 1@minYposWindow - h)';
    overflow:t='auto';
    scrollbarShortcuts:t='yes'

    <<#baseReward>>
    tdiv {
      width:t='pw';
      margin:t='0, 0, 1@blockInterval, 1@blockInterval';

      textareaNoTab {
        text:t='<<baseReward>>';
      }
    }
    <</baseReward>>

    tdiv {
      width:t='pw - 0.01@scrn_tgt';
      flow:t='vertical';
      <<#items>>
      tr {
        <<#even>>even:t='yes';<</even>>
        td {
          width:t='0.03@scrn_tgt';
          <<#received>>
          img {
            size:t='0.03@scrn_tgt, 0.03@scrn_tgt';
            background-image:t='#ui/gameuiskin#favorite';
            position:t='relative';
            pos:t='0, -0.004@scrn_tgt';
          }

          <</received>>
        }
        td {
          width:t='0.44@scrn_tgt';
          flow:t='vertical';
          textareaNoTab {
            id:t='reward_condition_text_<<conditionId>>_<<conditionField>>_<<conditionValue>>';
            width:t='pw';
            text:t='<<conditionText>>';
            <<#received>>
            style:t='color:@userlogColoredText;';
            <</received>>
          }
        }
        td {
          width:t='0.49@scrn_tgt';
          textareaNoTab {
            text-align:t='right';
            max-width:t='pw';
            height:t='0.03@scrn_tgt';
            id:t='reward';
            position:t='relative';
            padding-left:t='0.03@scrn_tgt';
            pos:t='pw - w, 0';
            text:t='<<reward>>';
            img {
              size:t='0.03@scrn_tgt, 0.03@scrn_tgt';
              position:t='relative';
              pos:t='-w, 0';
              background-image:t='<<icon>>';
            }
            <<#rewardTooltipId>>
            tooltipObj {
              id:t='tooltip_<<rewardTooltipId>>'
              on_tooltip_open:t='onGenericTooltipOpen'
              on_tooltip_close:t='onTooltipObjClose'
              display:t='hide'
            }
            title:t='$tooltipObj';
            <</rewardTooltipId>>
          }
        }
      }
      <</items>>
    }
  }
}
