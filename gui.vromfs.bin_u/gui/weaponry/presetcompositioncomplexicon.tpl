div {
  size:t='pw, ph'
  margin:t='@weaponIconPadding'

  <<#compositionIcons>>
  presetIcons {
    flow:t='vertical'
    size:t='(pw-5@weaponIconPadding)/5,ph'
    margin-left:t='@weaponIconPadding'
    <<#disabledSoldier>>
    iconStatus:t='disabled'
    <</disabledSoldier>>
    <<^disabledSoldier>>
    iconStatus:t='enabled'
    <</disabledSoldier>>

    <<#icons>>
    div {
      size:t='pw,pw'
      border-color:t='@modBorderColor'
      border:t='yes'
      <<#hasMargin>>
      margin-bottom:t='@weaponIconPadding'
      <</hasMargin>>

      img{
        size:t='pw,pw'
        background-image:t='<<itemImg>>'
        background-svg-size:t='pw,pw'
      }
    }
    <</icons>>
  }
  <</compositionIcons>>
}