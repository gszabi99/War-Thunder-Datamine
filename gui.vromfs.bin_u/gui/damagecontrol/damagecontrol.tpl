root {
  blur {}
  blur_foreground {}
  frame {
    size:t='1@srw, 1@maxWindowHeight'
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

        tdiv {
          position:t='relative'
          margin-top:t='0.6@damageControlIconSize'
          size:t='0, 1@damageControlIconSize + 1@unlocksListboxItemInterval'
          color:t='#FFFFFFFF'
          text-align:t='left'
          background-position:t='0, 0, 0, 1'
          bgcolor:t='#22222222'

          tdiv {
            size:t='5@damageControlIconSize, ph'
            textareaNoTab {
              id:t='header_name_txt'
              position:t='relative'
              pos:t='1@modPadSize, 0.5ph-0.5h'
              text:t='#ship/damage_control_set'
              text-align:t='left'
              width:t='pw'
            }
          }
          div {
            size:t='1@damageControlIconSize, 1@damageControlIconSize'
            background-color:t='#CC1B2027'
            margin-right:t='1@unlocksListboxItemInterval'
            img {
              size:t='pw, ph'
              background-svg-size:t='pw, ph'
              background-image:t='#ui/gameuiskin#icon_repair_in_progress.svg'
            }
          }
          div {
            include "%gui/damageControl/damageControlCurrentPreset.tpl"
          }
        }
        text {
          width:t='pw'
          margin-top:t='4@buttonMargin'
          position:t='relative'
          pos:t='0.5pw-0.5w, 0'
          text:t='#ship/damage_control_priority'
        }
        div {
          margin-top:t='1@buttonMargin'
          width:t='pw'
          flow:t='vertical'
          overflow-y:t='auto'
          behavior:t='posNavigator'
          showSelect:t='always'
          canSelectNone:t='yes'
          navigatorShortcuts:t='yes'
          total-input-transparent:t='yes'
          on_select:t='onSelect'
          include "%gui/damageControl/damageControlFixedPreset.tpl"
        }
      }
      blockSeparator{}
      tdiv{
        flow:t='vertical'
        size:t='1.5@narrowTooltipWidth+1@scrollBarSize+1@blockInterval, ph'
        tdiv{
          flow:t='vertical'
          size:t='pw, ph'
          max-height:t='ph'
          overflow-y:t='auto'
          padding:t='1@blockInterval'

          buttons_select {
            border-color:t='@modBorderColor'
            border:t='yes'
            border-offset:t='1@slotBorderSize'
            padding:t='1@weaponIconPadding, 1@weaponIconPadding, 2@weaponIconPadding, 1@weaponIconPadding'
            flow:t='vertical'
            position:t='relative'
            pos:t='0, ph-h'
            include "%gui/damageControl/damageControlSelectButton.tpl"
          }
        }
      }
    }
  }
}
