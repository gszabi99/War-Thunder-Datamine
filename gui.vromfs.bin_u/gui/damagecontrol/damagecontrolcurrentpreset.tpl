<<#currentPresetView>>
currentPreset {
  size:t='1@damageControlIconSize, 1@damageControlIconSize'
  margin-right:t='1@unlocksListboxItemInterval'
  background-color:t='#FF20252e'
  css-hier-invalidate:t='yes'
  div {
    id:t=<<presetNumber>>
    size:t='pw, ph'
    <<@image>>
  }
  damageControlPresetShortcut {
    width:t='pw'
    pos:t='pw/2 - w/2, -h'
    position:t='absolute'

    activeText {
      text:t='<<shortcut>>'
    }
  }
}
<</currentPresetView>>