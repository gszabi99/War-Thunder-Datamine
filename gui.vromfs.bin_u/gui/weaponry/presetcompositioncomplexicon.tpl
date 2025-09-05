div {
  size:t='pw, ph'
  margin:t='@weaponIconPadding'

  <<#compositionIcons>>
  div {
    flow:t='vertical'
    size:t='(pw-5@weaponIconPadding)/5,ph'
    margin-left:t='@weaponIconPadding'

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