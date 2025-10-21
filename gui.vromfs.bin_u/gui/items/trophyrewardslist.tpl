root {
  blur {}
  blur_foreground {}
  type:t="big"

  frame {
    width:t='<<listWidth>> + 2@itemSpacing + 1@blockInterval + 1@itemInfoWidth + 2@framePadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    class:t='wnd'

    frame_header {
      activeText{
        id:t='title'
        text:t='#mainmenu/rewardsList'
        caption:t='yes'
      }
      Button_close { id:t = 'btn_back' }
    }

    tdiv {
      id:t='trophy_rewards_list'
      size:t='pw, 570@sf/@pf'
      max-height:t='1@maxWindowHeight'

      tdiv {
        id:t='items_list'
        width:t='<<listWidth>>'
        margin:t='1@itemSpacing, 0'
        flow:t='vertical'
        overflow-y:t='auto'
        itemShopList:t='yes'
        bringFocusBorderToFront:t='no'
        isPrizeSelectableList:t='yes'

        behavior:t='posNavigator'
        navigatorShortcuts:t='yes'
        moveX:t='closest'
        moveY:t='linear'
        clearOnFocusLost:t='no'
        total-input-transparent:t='yes'

        on_select:t = 'updateItemInfo'
      }

      chapterSeparator {
        margin:t='1@blockInterval, 0, 0, 0'
      }

      tdiv {
        size:t='fw, ph'
        pos:t='1@blockInterval, 0'
        flow:t='vertical'
        padding:t='0.01@scrn_tgt'
        overflow-y:t='auto'
        scrollbarShortcuts:t='yes'

        tdiv {
          id:t='item_info'
          width:t='pw'
          display:t='hide'
          flow:t='vertical'
        }

        tdiv {
          id:t='prize_info'
          width:t='pw'
          text-align:t='center'
          flow:t='vertical'
        }
      }
    }

    <<#hasProbabilityInfo>>
    navBar {
      class:t='relative'
      navRight {
        Button_text {
          id:t = 'btn_probability_info'
          text:t='#mainmenu/probability_info'
          btnName:t='Y'
          on_click:t = 'onProbabilityInfoBtn'
          hideText:t='yes'
          css-hier-invalidate:t='yes'
          showButtonImageOnConsole:t='no'
          visualStyle:t='secondary'
          buttonWink{}
          buttonGlance{}
          class:t=''
          isColoredImg:t='yes'
          img { id:t='img'; background-image:t='' }
          ButtonImg {}
          textarea {
            id:t='btn_probability_info_text'
            class:t='buttonText'
            text:t='#mainmenu/probability_info'
          }
        }
      }
    }
    <</hasProbabilityInfo>>
  }
}