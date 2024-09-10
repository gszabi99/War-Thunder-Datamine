frame {
  id:t='select_unit_pane'
  size:t='380@sf/@pf, 350@sf/@pf'
  position:t='absolute'
  top='40@sf/@pf'
  right:t='pw-w'
  class:t='wndNav'
  total-input-transparent:t='yes'

  frame_header {
    activeText {
      text:t='#tankSight/changeSpectator'
      caption:t='yes'
    }
  }

  tdiv {
    size:t='pw,ph'
    padding:t='12@sf/@pf, 1@blockInterval'
    flow:t='vertical'

    <<#unitSettings>>
    ComboBox {
      width:t='pw'
      margin-top:t='2@blockInterval'
      <<@markup>>
    }
    <</unitSettings>>

    rowSeparator { margin-top:t='4@blockInterval' }

    Button_text {
      width:t='pw'
      margin-top:t='4@blockInterval'
      text:t='#save/btnSave'
      ButtonImg {}
      on_click='onSave'
      btnName:t='X'
    }

    Button_text {
      width:t='pw'
      margin-top:t='2@blockInterval'
      text:t='#mainmenu/btnReset'
      ButtonImg {}
      on_click='onReset'
      btnName:t='Y'
    }
  }
}

frame {
  id:t='settings_pane'
  width:t='400@sf/@pf'
  position:t='absolute'
  top='40@sf/@pf'
  left:t='pw-w'
  class:t='wndNav'
  total-input-transparent:t='yes'

  frame_header {
    activeText {
      text:t='#tankSight/presetSettings'
      caption:t='yes'
    }
  }

  tdiv {
    width='pw'
    padding:t='12@sf/@pf, 1@blockInterval'
    flow:t='vertical'

    tdiv {
      width='pw'
      flow:t='vertical'

      textAreaCentered {
        text:t="#tankSight/choosePreset"
      }

      ComboBox {
        id:t= 'select_preset_combobox'
        width:t='pw'
        <<@presetsComboboxMarkup>>
      }

      Button_text {
        width:t='pw'
        margin-top:t='2@blockInterval'
        text:t='#tankSight/savePreset'
        ButtonImg {}
        on_click='onSaveCustomPreset'
        btnName:t='R3'
      }
    }

    rowSeparator {
      margin-top:t='4@blockInterval'
      margin-bottom:t='2@blockInterval'
    }

    tdiv {
      width:t='pw'
      flow:t='vertical'
      <<#presetSettings>>
      tankSightOptions {
        id:t='<<id>>'
        width:t='pw'
        flow:t='vertical'
        css-hier-invalidate:t='all'

        <<#initiallyExpand>>
        expanded='yes'
        <</initiallyExpand>>
        <<^initiallyExpand>>
        expanded='no'
        <</initiallyExpand>>

        button {
          width='pw'
          margin-top:t='1@blockInterval'
          on_click:t='onOptionsTitleClick'

          textAreaCentered {
            text:t='<<title>>'
          }

          img {
            position:t='absolute'
            pos:t='pw-w-8@sf/@pf, ph/2-h/2'
            background-image:t='#ui/gameuiskin#drop_menu_icon.svg'
            size:t='20@sf/@pf, 20@sf/@pf'
            background-svg-size:t='20@sf/@pf, 20@sf/@pf'
            background-repeat:t='aspect-ratio'
          }
        }

        tankSightOptionsList {
          width:t='pw'
          display:t='hide'
          overflow:t='hidden'
          flow:t='vertical'

          <<#controls>>
          ComboBox {
            id:t= '<<controlId>>'
            width:t='pw'
            margin-top:t='1@blockInterval'
            <<@markup>>
          }
          <</controls>>
        }
      }
    <</presetSettings>>
    }
  }
}

tdiv {
  position:t='absolute'
  pos:t='pw-w, sh-1@bh-h'

  Button_text {
    id:t='btn_toggle_preview'
    text:t='#mainmenu/btnPreview'
    ButtonImg {}
    on_click='onToggleSightPreviewMode'
    btnName:t='L3'
  }

  Button_text {
    id:t='btn_toggle_lighting'
    text:t=''
    ButtonImg {}
    on_click='onToggleLightingMode'
    btnName:t='LB'
  }

  Button_text {
    id:t='btn_toggle_nv'
    text:t=''
    ButtonImg {}
    on_click='onToggleNightVisionMode'
    btnName:t='LT'
  }

  Button_text {
    id:t='btn_toggle_thermal'
    text:t=''
    ButtonImg {}
    on_click='onToggleThermalMode'
    btnName:t='RB'
  }

  Button_text {
    id:t='btn_back'
    text:t='#mainmenu/btnBack'
    btnName:t='B'
    ButtonImg {}
    _on_click:t='goBack'
  }
}

tdiv {
  behaviour='darg'
}