separatorLine {}

textareaNoTab {
  id:t='active_countries_text'
  width:t='pw'
  padding:t='1@framePadding'
  text:t='#worldWar/participatingCountries'
}

separatorLine {}

<<#countries>>
tdiv {
  width:t='pw'
  margin:t='1@framePadding'

  img {
    size:t='@cIco, @cIco'
    background-image:t='<<countryIcon>>'
    background-svg-size:t='@cIco, @cIco'
  }

  textareaNoTab {
    width:t='0.6pw'
    margin-left:t='1@framePadding'
    text:t='<<name>>'
  }

  textareaNoTab {
    text:t='<<value>>'
  }
}
<</countries>>
