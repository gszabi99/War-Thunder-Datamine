root {
  blur {}
  blur_foreground {}
  on_click:t='goBack'
  frame {
    size:t='<<wndWidth>>, 1@maxWindowHeight'
    class:t='wndNav'
    css-hier-invalidate:t='yes'
    isCenteredUnderLogo:t='yes'
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

        include "%gui/weaponry/weaponryPreset"
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
      navLeft {
        width:t='pw'
        popupFilter {
          pos:t='1@blockInterval, 0'
          position:t='relative'
          margin-top:t="1@buttonMargin"
          margin-bottom:t="1@buttonMargin"
        }
        Button_text {
          id:t='openPresetMenuBtn'
          text:t='#msgbox/presetActions'
          on_click:t='onPresetMenuOpen'
          btnName:t='LB'
          display:t='hide'
          ButtonImg {}
        }
        Button_text {
          id:t='newPresetBtn'
          text:t='#chat/create'
          on_click:t='onPresetNew'
          btnName:t='RB'
          display:t='hide'
          ButtonImg {}
        }
        Button_text {
          id:t='btn_buyAll'
          btnName:t='L3'
          _on_click:t='onBuyAll'
          hideText:t='yes'
          display:t='hide'
          visualStyle:t='purchase'
          buttonWink{}
          buttonGlance{}
          textarea {
            id:t='btn_buyAll_text'
            class:t='buttonText'
          }
          ButtonImg {}
        }
      }
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
          on_click:t='onAltModAction'
          display:t='hide'
          tooltip:t='<<altBtnTooltip>>'
          btnName:t='X'
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