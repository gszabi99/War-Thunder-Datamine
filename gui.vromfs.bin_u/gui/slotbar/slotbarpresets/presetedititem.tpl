<<#presets>>
presetTab {
  id:t='preset_<<idx>>'
  editPresets:t='yes'
  position:t='absolute'
  pos:t='0, <<idx>>@editPresetsItemHeight'
  css-hier-invalidate:t='yes'
  isPresetSelected:t='<<isPresetSelected>>'
  presetIdx:t='<<idx>>'
  dragDisabled:t='<<dragDisabled>>'
  on_click:t='onPresetItemClick'
  on_move_start:t='onPresetMoveStart'
  on_move_end:t='onPresetMoveEnd'
  on_move:t='onPresetMove'
  state:t=<<state>>

  <<#isGamepadMode>>
  dragAnchor {
    behavior:t='moveobj'
    pos:t='1@blockInterval, ph/2-h/2'
    size:t='1@hoverButtonHeight, 1@hoverButtonHeight'
    position:t='absolute'
    interactive:t='yes'
    shortcut-on-hover:t='yes'
    check-off-screen:t='parent'
  }
  <</isGamepadMode>>

  readyState {
    id:t='readyState'
    height:t='ph'
    position:t='absolute'
    css-hier-invalidate:t='yes'
    display:t='hide'

    tdiv {
      margin-left:t='5@blockInterval + @vtIco'
      size:t='pw, ph'

      textareaNoTab {
        id:t='presetBR'
        position:t='relative'
        normalBoldFont:t='yes'
        margin-right:t='2@blockInterval'
        text:t='<<presetBR>>'
      }

      textareaNoTab {
        position:t='relative'
        overlayTextColor:t='minor'
        margin-right:t='2@blockInterval'
        text:t='<<presetGameMode>>'
      }

      textareaNoTab {
        presetName:t='yes'
        position:t='relative'
        text:t='<<presetName>>'
      }
    }

    actions {
      position:t='absolute'
      size:t='270@sf/@pf, 1@editPresetsItemHeight'
      background-image:t='#ui/gameuiskin#edit_preset_gradient.svg'
      background-svg-size:t='270@sf/@pf, 1@editPresetsItemHeight'
      background-color:t='@white'
      css-hier-invalidate:t='yes'
      display:t='hide'

      hoverButton {
        margin-left:t='7.5@blockInterval'
        presetIdx:t='<<idx>>'
        on_click:t='onRenamePreset'
        icon {
          background-image:t='#ui/gameuiskin#btn_edit.svg'
        }
      }

      hoverButton {
        presetIdx:t='<<idx>>'
        margin-left:t='1.5@blockInterval'
        on_click:t='onCopyPreset'
        icon {
          background-image:t='#ui/gameuiskin#preset_dublicate.svg'
        }
      }

      hoverButton {
        isRemoveButton:t='yes'
        presetIdx:t='<<idx>>'
        margin-left:t='1.5@blockInterval'
        on_click:t='onRemovePreset'
        icon {
          background-image:t='#ui/gameuiskin#icon_trash_bin.svg'
        }
      }
    }
  }

  renameState {
    size:t='pw, ph'
    position:t='absolute'
    css-hier-invalidate:t='yes'
    bgcolor:t='#1C222A'
    display:t='hide'

    hoverButton {
      margin-left:t='2.5@blockInterval'
      presetIdx:t='<<idx>>'
      on_click:t='onConfirmRenamePreset'
      icon {
        background-image:t='#ui/gameuiskin#preset_add_confirm.svg'
      }
    }

    hoverButton {
      margin-left:t='1.5@blockInterval'
      presetIdx:t='<<idx>>'
      on_click:t='onCancelEditPreset'
      icon {
        background-image:t='#ui/gameuiskin#preset_add_cancel.svg'
      }
    }

    EditBox {
      id:t='renamePresetEditBox'
      width:t='fw'
      valign:t='center'
      margin:t='3@blockInterval, 0, 3@blockInterval, 0'
      max-len:t='16'
      text:t=''
      presetIdx:t='<<idx>>'
      on_cancel_edit:t='onCancelEditPreset'
      on_unhover:t='onEditBoxUnhover'
      on_activate:t='onConfirmRenamePreset'
    }
  }

  removeState {
    size:t='pw, ph'
    position:t='absolute'
    css-hier-invalidate:t='yes'
    display:t='hide'

    img {
      position:t='absolute'
      size:t='516@sf/@pf, 1@editPresetsItemHeight'
      background-image:t='#ui/gameuiskin#remove_preset_gradient.svg'
      background-svg-size:t='516@sf/@pf, 1@editPresetsItemHeight'
      bgcolor:t='@white'
    }

    hoverButton {
      margin-left:t='2.5@blockInterval'
      presetIdx:t='<<idx>>'
      on_click:t='onConfirmRemovePreset'
      icon {
        background-image:t='#ui/gameuiskin#preset_add_confirm.svg'
      }
    }

    hoverButton {
      margin-left:t='1.5@blockInterval'
      presetIdx:t='<<idx>>'
      on_click:t='onCancelEditPreset'
      icon {
        background-image:t='#ui/gameuiskin#preset_add_cancel.svg'
      }
    }

    textareaNoTab {
      margin-left:t='3@blockInterval'
      overlayTextColor:t='active'
      text:t='#presets/edit/remove'
    }
  }

  dragAnchorImg {
    position:t='absolute'
    pos:t='1@blockInterval, ph/2-h/2'
    background-image:t='#ui/gameuiskin#menu.svg'
    background-position:t='1.5@blockInterval'
    background-svg-size:t='1@hoverButtonHeight - 3@blockInterval, 1@hoverButtonHeight - 3@blockInterval'
    size:t='1@hoverButtonHeight, 1@hoverButtonHeight'
    total-input-transparent:t='yes'
    css-hier-invalidate:t='yes'
  }

  <<^isGamepadMode>>
  dragAnchor {
    behavior:t='moveobj'
    pos:t='1@blockInterval, ph/2-h/2'
    size:t='1@hoverButtonHeight, 1@hoverButtonHeight'
    position:t='absolute'
    interactive:t='yes'
    shortcut-on-hover:t='yes'
    check-off-screen:t='parent'
  }
  <</isGamepadMode>>

  blockSeparator {}
}

<</presets>>