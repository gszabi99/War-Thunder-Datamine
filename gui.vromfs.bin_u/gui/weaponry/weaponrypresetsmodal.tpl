root {
  background-color:t = '@modalShadeColor'
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

        behaviour:t='posNavigator'
        showSelect:t='always'
        navigatorShortcuts:t='yes'
        scrollbarShortcuts:t='yes'
        css-hier-invalidate:t='yes'
        total-input-transparent:t='yes'
        on_select:t='onItemSelect'

        include "gui/weaponry/weaponryPreset"
      }
      blockSeparator{}
      tdiv{
        flow:t='vertical'
        size:t='1@narrowTooltipWidth+1@scrollBarSize+1@blockInterval, ph'
        tdiv{
          width:t='pw'
          max-height:t='ph'
          overflow-y:t='auto'
          padding:t='1@blockInterval'
          descriptionNest {
            id:t='desc'
            width:t='pw'
          }
        }
      }
    }
    navBar {
      navRight {
        Button_text{
          id:t='altActionBtn'
          text:t=''
          display:t='hide'
          tooltip:t='<<altBtnTooltip>>'
          btnName:t='X'
          on_click:t='onAltModAction'
          visualStyle:t='purchase'
          buttonWink {}
          buttonGlance{}
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