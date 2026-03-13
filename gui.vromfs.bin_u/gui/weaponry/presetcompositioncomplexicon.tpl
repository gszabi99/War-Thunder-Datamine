div {
  size:t='pw, ph'
  margin:t='@weaponIconPadding'

  <<#compositionIcons>>
  presetIcons {
    <<^singleModeIcon>>
      size:t='(pw-5@weaponIconPadding)/5,ph'
      flow:t='vertical'
      margin-left:t='@weaponIconPadding'
    <</singleModeIcon>>

    <<#singleModeIcon>>
      size:t='pw,ph'
    <</singleModeIcon>>

    <<#disabledSoldier>>
    iconStatus:t='disabled'
    <</disabledSoldier>>
    <<^disabledSoldier>>
    iconStatus:t='enabled'
    <</disabledSoldier>>

    <<#icons>>
    div {
      <<^singleModeIcon>>
        size:t='pw,pw'
      <</singleModeIcon>>

      <<#singleModeIcon>>
        size:t='(pw-4@weaponIconPadding)/3,w'
        position:t='relative'
        pos:t='0,50%ph-50%h'
      <</singleModeIcon>>

      border-color:t='@modBorderColor'
      border:t='yes'
      <<#hasMargin>>
        margin-bottom:t='@weaponIconPadding'
      <</hasMargin>>

      <<#singleModeIcon>>
        margin-left:t='1@weaponIconPadding'
      <</singleModeIcon>>

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