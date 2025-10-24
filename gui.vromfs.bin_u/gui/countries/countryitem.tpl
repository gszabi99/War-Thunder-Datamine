<<#countries>>
countryItem {
  height:t='ph'
  country = '<<country>>'
  img {
    size:t='@cIco, 0.66@cIco'
    valign:t='center'
    background-image:t='<<countryIcon>>'
    background-color:t='@white'
    background-svg-size:t='@cIco, 0.66@cIco'
    background-repeat:t='aspect-ratio'
    <<#disabled>>background-saturate:t='0'<</disabled>>
  }

  textareaNoTab {
    valign:t='center'
    margin-left:t='1@blockInterval'
    text:t='#<<country>>'
    <<#disabled>>overlayTextColor:t='disabled'<</disabled>>
  }
}
<</countries>>