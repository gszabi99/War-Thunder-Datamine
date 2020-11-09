root {
  background-color:t = '@modalShadeColor'
  on_click:t='goBack'

  frame {
    pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='relative'
    class:t='wnd'
    max-height:t = '1@maxWindowHeight'
    css-hier-invalidate:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='#clan/clan_awards'
      }

      Button_close { id:t = 'btn_back' }
    }

    tdiv {
      width:t = '<<width>>'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      tdiv {
        id:t='rewards_list'
        width:t = '<<width>>'
        padding:t='-1@framePadding'
        flow:t = 'h-flow'
        <<#isEditable>>
        behaviour:t='posNavigator'
        show_console_buttons:t='yes'
        navigatorShortcuts:t='SpaceA'
        on_activate:t = 'onActivate'
        <</isEditable>>
        <<#rewards>>
        frameBlock_dark{
          width:t='1@unlockBlockWidth'
          margin:t='1@framePadding, 1@framePadding'
          padding:t='1@tooltipPadding'
          css-hier-invalidate:t='yes'
          div{
            size:t='@profileUnlockIconSize, @profileUnlockIconSize'
            layeredIconContainer {
              size:t='ph, ph'
              pos:t='50%pw-50%w, 50%ph-50%h';
              position:t='absolute'
              <<@rewardImage>>
            }
          }
          div{
            pos:t='1@tooltipPadding, 0'; position:t='relative'
            flow:t='vertical'
            width:t='pw - 1@profileUnlockIconSize -1@tooltipPadding'
            css-hier-invalidate:t='yes'
            textareaNoTab{
              width:t='pw'
              pare-text:t='yes';
              overlayTextColor:t='unlockHeader'
              text:t='<<award_title_text>>'
              padding-top:t='6@sf/@pf'
            }
            textareaNoTab{
              text:t='<<desc_text>>'
              smallFont:t='yes'
              width:t='pw'
              padding-top:t='3@sf/@pf'
            }
            <<#isEditable>>
            CheckBox{
              id:t='<<rewardId>>'
              css-hier-invalidate:t='yes'
              pos:t='pw-w, 0'
              position:t='relative'
              text:t='#mainmenu/UnlockAchievementsToFavorite'
              smallFont:t='yes'
              value:t='<<isChecked>>'
              on_change_value:t = 'onBestRewardSelect'
              ButtonImg{
                position:t='absolute'
                pos:t='-@checkboxSize, 0.5ph-0.5h'
                btnName:t='A'
                showOnSelect:t='focus'
              }
              CheckBoxImg{}
            }
            <</isEditable>>
          }
          focus_border {}
        }
        <</rewards>>
      }
    }
  }

  gamercard_div {}

  tdiv{
    id:t='chatPopupNest';
    size:t='0.4@sf+10, 0.075*@sf+10';
    position:t='absolute';
    pos:t='0.5@rw-w-0.55@titleLogoPlateWidth-0.019@scrn_tgt, @topBarHeight'
    flow:t='vertical'
  }
}
