root {
  blur {}
  blur_foreground {}
  on_click:t='goBack'

  frame {
    size:t='<<wndWidth>>, 1@maxWindowHeight'
    pos:t='0.5pw-0.5w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    class:t='wndNav'
    css-hier-invalidate:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }

      Button_close { id:t = 'btn_back' }
    }
    tdiv{
      size:t='pw, ph'
      flow:t='horizontal'
      padding:t='1@blockInterval, 0'
      css-hier-invalidate:t='yes'
      tdiv {
        id:t='presetNest'
        width:t='fw'
        flow:t='vertical'
        overflow-y:t='auto'

        include "gui/weaponry/weaponryPreset"
      }
      blockSeparator{}
      tdiv{
        flow:t='vertical'
        size:t='1@narrowTooltipWidth+1@scrollBarSize+1@blockInterval, ph'
        tdiv{
          flow:t='vertical'
          width:t='pw'
          max-height:t='ph'
          overflow-y:t='auto'
          padding:t='1@blockInterval'
          descriptionNest {
            id:t='desc'
            width:t='pw'
            padding:t='0, 1@blockInterval'
          }
          rowSeparator{}
          descriptionNest {
            id:t='tierDesc'
            width:t='pw'
            padding:t='0, 1@blockInterval'
          }
        }
      }
    }
    navBar {
      navRight {
        Button_text{
          id:t='favoriteBtn'
          text:t=''
          on_click:t='onChangeFavorite'
          display:t='hide'
          btnName:t='LT'
          ButtonImg {}
        }
        Button_text{
          id:t='altActionBtn'
          text:t=''
          display:t='hide'
          tooltip:t='<<altBtnTooltip>>'
          btnName:t='X'
          on_click:t='onAltModAction'
          ButtonImg {}
        }
        Button_text{
          id:t='actionBtn'
          text:t=''
          on_click:t='onModActionBtn'
          display:t='hide'
          btnName:t='A'
          ButtonImg {}
        }
      }
    }
  }
}