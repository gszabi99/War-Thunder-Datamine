<<#countries>>
tdiv {
  margin:t='0.005@sf, 0'
  flow:t='vertical'

  img {
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    id:t='<<countryName>>'
    size:t='@cIco, @cIco'
    background-image:t='<<countryIcon>>'
    background-svg-size:t='@cIco, @cIco'
  }

  <<#teamsInfoText>>
  textareaNoTab {
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    text:t='<<teamsInfoText>>'
  }
  <</teamsInfoText>>
}
<</countries>>
