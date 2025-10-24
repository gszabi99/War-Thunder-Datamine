root {
  blur {}
  blur_foreground {}
  frame {
    size:t='1366@sf/@pf, 739@sf/@pf'
    class:t='wndNav'
    css-hier-invalidate:t='yes'
    isCenteredUnderLogo:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='#ship/damage_control'
      }
      Button_close { id:t = 'btn_back' }
    }
    tdiv {
      flow:t='horizontal'
      size:t='pw, fh'
      tdiv {
        flow:t='vertical'
        tdiv {
          margin:t='9@blockInterval, 3@blockInterval, 9@blockInterval, 0'
          flow:t='vertical'
          css-hier-invalidate:t='yes'
          activeText {
            position:t='relative'
            pos:t='0.5pw-0.5w, 0'
            text:t='#ship/damage_control_priority'
          }
          tdiv {
            position:t='relative'
            margin-top:t='6@blockInterval'
            flow:t='horizontal'
            text {
              width:t='1@fixedPresetWidth'
              text:t='#ship/repair'
              smallFont:t='yes'
              text-align:t='center'
            }
            text {
              width:t='1@fixedPresetWidth'
              margin-left:t='1@fixedPresetGap'
              text:t='#ship/extinguishing'
              smallFont:t='yes'
              text-align:t='center'
            }
            text {
              width:t='1@fixedPresetWidth'
              margin-left:t='1@fixedPresetGap'
              text:t='#ship/unwatering'
              smallFont:t='yes'
              text-align:t='center'
            }
          }
          fixedPresetsNest {
            behavior:t='posNavigator'
            margin-top:t='2@blockInterval'
            height:t='2@fixedPresetHeight + 11@blockInterval'
            flow:t='v-flow'
            overflow-y:t='auto'
            css-hier-invalidate:t='yes'
            canSelectNone:t='yes'
            navigatorShortcuts:t='yes'
            total-input-transparent:t='yes'
            on_select:t='onPresetSelect'
            <<#fixedPresetView>>
            fixedPreset {
              size:t='1@fixedPresetWidth, 1@fixedPresetHeight'
              <<^lastPreset>>margin-right:t='1@fixedPresetGap'<</lastPreset>>
              margin-bottom:t='5@blockInterval'
              css-hier-invalidate:t='yes'
              flow:t='horizontal'
              on_drag_start:t='onPresetDragStart'
              on_move:t='onPresetMove'
              on_drag_drop:t='onPresetDrop'
              proxyEventsParentTag:t='fixedPresetsNest'
              presetIdx:t='<<presetIdx>>'
              actionsHolder {
                valign:t='center'
                halign:t='center'
                <<#actionsView>>
                actionItem{
                  img {
                    size:t='1@actionIconSize, 1@actionIconSize'
                    position:t='relative'
                    background-image:t='<<#image>><<image>><</image>>'
                    background-repeat:t='expand'
                    background-svg-size:t='1@actionIconSize, 1@actionIconSize'
                  }
                  <<^lastAction>>
                  tdiv {
                    margin:t='1.5@blockInterval, 0, 1.5@blockInterval, 0'
                    size:t='1@arrowIconSize, 1@arrowIconSize'
                    background-color:t='#80808080'
                    background-image:t='#ui/gameuiskin#arrow_simple_hor.svg'
                    valign:t='center'
                  }
                  <</lastAction>>
                }
                <</actionsView>>
              }
            }
            <</fixedPresetView>>
          }
          horizontalSeparator { width:t='3@fixedPresetWidth + 2@fixedPresetGap' }
          presetsSeparator { left:t='1@fixedPresetWidth + 0.5@fixedPresetGap' }
          presetsSeparator { left:t='2@fixedPresetWidth + 1.5@fixedPresetGap' }
        }

        tdiv{
          size:t='3@fixedPresetWidth + 2@fixedPresetGap, fh'
          margin-left:t='9@blockInterval'
          flow:t='vertical'
          css-hier-invalidate:t='yes'

          activeText {
            position:t='relative'
            pos:t='0.5pw-0.5w, 0'
            margin-top:t='3@blockInterval'
            text:t='#ship/damage_control_set'
          }

          tdiv {
            position:t='absolute'
            pos:t='0.5pw - 0.5w, 18.5@blockInterval'
            background-image:t='ui/images/damage_control_slotbar.avif'
            background-svg-size:t='716@sf/@pf, 102@sf/@pf'
            size:t='716@sf/@pf, 102@sf/@pf'
            background-color:t='#33333333'
          }

          currentPresetNest {
            id:t='currentPresetNest'
            position:t='absolute'
            pos:t='0.5pw - 0.5w, 10@blockInterval'
            buttonsDisabled:t='yes'
            css-hier-invalidate:t='yes'
            <<#currentPresetView>>
            currentPreset {
              width:t='1@damageControlIconSize'
              <<^lastCurrentPreset>>margin-right:t='1.66@blockInterval'<</lastCurrentPreset>>
              css-hier-invalidate:t='yes'
              flow:t='vertical'

              damageControlPresetShortcut {
                size:t='pw, 4@blockInterval'
                margin-bottom:t='0.5@blockInterval'
                textareaNoTab {
                  text:t='<<shortcut>>'
                }
              }
              damageControlPresetIcon {
                id:t='<<presetNumber>>'
                size:t='pw, pw'
                <<@image>>
              }
              Button_text {
                presetId:t='<<presetNumber>>'
                size:t='pw, 4.5@blockInterval'
                margin-top:t='2.5@blockInterval'
                damageControlActionButton:t='yes'
                text:t='#msgbox/btn_add'
                on_click:t='onSelectFor'
              }
            }
            <</currentPresetView>>
          }
        }
      }
      blockSeparator{}
      tdiv {
        size:t='fw, ph'
        flow:t='vertical'
        tdiv {
          height:t='11@blockInterval'
          activeText {
            id:t='presetName'
            position:t='relative'
            margin-left:t='3@blockInterval'
            valign:t='center'
            text:t=''
          }
        }
        horizontalSeparator { width:t='pw' }
        tdiv {
          id:t='noSelectedPresets'
          behaviour:t='bhvHint'
          position:t='relative'
          width:t='pw - 4@blockInterval'
          margin:t='3@blockInterval, 4@blockInterval, 0, 0'
          smallFont:t='yes'
        }

        tdiv {
          id:t='presetDescriptionDiv'
          width:t='pw'
          margin-left:t='3@blockInterval'
          flow:t='vertical'
          display:t='hide'
          textareaNoTab {
            id:t='presetDescription'
            position:t='relative'
            width:t='pw - 4@blockInterval'
            margin-top:t='4@blockInterval'
            text:t=''
            smallFont:t='yes'
          }

          textareaNoTab {
            position:t='relative'
            margin-top:t='1.5@blockInterval'
            text:t='#ship/damageControlSpecTitle'
            smallFont:t='yes'
          }

          textareaNoTab {
            id:t='damageControlSpecs'
            position:t='relative'
            margin:t='1@blockInterval, 1@blockInterval, 0, 0'
            text:t=''
            smallFont:t='yes'
          }
        }
      }
    }
  }
}
