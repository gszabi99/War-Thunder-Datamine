tdiv {
  id:t='second_game_modes_status'
  width:t='pw'
  flow:t='horizontal'

  <<#secondStatusModes>>
    tdiv {
      id:t='<<modeId>>'
      flow:t='horizontal'
      flow-align:t='center'
      width:t='fw'

      tdiv {
        id:t='icon'
        position:t='relative'
        size:t='<<iconSize>>'
        top:t='(ph-h)/2'
        background-image:t='<<icon>>'
        background-color:t='@commonMenuButtonColor'
        background-size:t='<<iconSize>>'
      }

      tdiv {
        id:t='text'
        re-type:t='textarea'
        behavior:t='textarea'
        top:t='(ph-h)/2'
        margin-left:t='1@blockInterval'
        font:t='@fontNormal'
        color:t='@commonMenuButtonColor'
        text:t=''
      }
    }
  <</secondStatusModes>>
}

secondGameModesDetails {
  id:t='second_game_modes_details'
  flow:t='vertical'
  width:t='pw'
  padding:t='20@sf/@pf, 10@sf/@pf, 20@sf/@pf, 20@sf/@pf'
  display:t='hide'

  <<#secondModes>>
    <<#isHeader>>
    textareaNoTab {
      id:t='<<modeId>>'
      margin-bottom:t='10@sf/@pf'
      overlayTextColor:t='minor'
      text:t='<<name>>'
      smallFont:t='yes'
    }
    <</isHeader>>
    <<^isHeader>>
    tdiv {
      id:t='<<modeId>>'
      flow:t='vertical'
      width:t='pw'
      margin-top:t='1@blockInterval'


      tdiv {
        width:t='pw'

        textareaNoTab {
          id:t='modeName'
          position:t='relative'
          top:t='(ph-h)/2'
          text:t='<<name>>'
        }
        <<#additionalBtns>>
        secondGameModeBtn {
          position:t='relative'
          class:t='usual'
          top:t='(ph-h)/2'
          margin-left:t='1@buttonMargin'
          on_click:t='<<onClickFunc>>'
          tooltip:t='<<tooltip>>'
          img {
            background-image:t='<<img>>'
          }
        }
        <</additionalBtns>>

        tdiv {
          id:t='switch_box_holder'
          position:t='absolute'
          pos:t='pw-w, (ph-h)/2'
          tooltip:t=''

          SwitchBox {
            id:t='switch_box'
            noRightPadding:t='yes'
            modeId:t='<<modeId>>'
            on_change_value:t='onSecondGameModeSlider'
            value:t='no'
            SwitchSliderBg { SwitchSliderBgOn {} SwitchSlider {} }
          }
        }
      }

      tdiv {
        id:t='details'
        re-type:t='textarea'
        behavior:t='textarea'
        width:t='pw'
        margin-top:t='5@sf/@pf'
        text:t=''
        color:t='#ED9118'
        font:t='@fontTiny'
      }
    }
    <</isHeader>>
  <</secondModes>>
}