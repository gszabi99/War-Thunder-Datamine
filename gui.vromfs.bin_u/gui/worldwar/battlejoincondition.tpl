root {
  background-color:t = '@modalShadeColor'
  behaviour:t='button'
  on_click:t='goBack'

  frame {
    id:t='wnd_frame'
    size:t='0.7@sf, 0.6@sf'
    pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    class:t='wndNav'
    largeNavBarHeight:t='help'

    frame_header {
      activeText { caption:t='yes'; text:t='#worldwar/help/title' }
      Button_close {}
    }

    tdiv {
      size:t='pw, fh'
      margin:t='0.03@scrn_tgt'
      flow:t='vertical'

      tdiv {
        margin-bottom:t='0.02@scrn_tgt'
        width:t='pw'

        img {
          margin-right:t='1@blockInterval'
          background-image:t='<<countryIcon>>'
          iconType:t='small_country'
        }
        textareaNoTab {
          width:t='fw'
          top:t='50%ph-50%h'
          position:t='relative'
          text:t='<<countryInfoText>>'
        }
      }

      textareaNoTab {
        width:t='pw'
        text:t='<<battleConditionText>>'
      }

      tdiv {
        size:t='pw, fh'
        overflow-y:t='auto'
        flow:t='vertical'
        scrollbarShortcuts:t='yes'

        tdiv {
          width:t='pw'
          margin:t='0.03@scrn_tgt, 1@blockInterval'

          <<#columns>>
          tdiv {
            width:t='0.5pw'
            flow:t='vertical'

            <<#unitString>>
            tdiv {
              <<#icon>>
              img {
                size:t='1@tableIcoSize, 1@tableIcoSize'
                background-image:t='<<icon>>'
                shopItemType:t='<<shopItemType>>'
              }
              <</icon>>

              textareaNoTab {
                text:t=' <<name>>'
              }
            }
            <</unitString>>
          }
          <</columns>>
        }
      }
    }
  }
}
