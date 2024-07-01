keyboardAxis {
<<#needArrows>>
hasArrow:t= 'yes'
<</needArrows>>

  keyPlace {
    flow:t='vertical'
    posPlace:t= 'left'
    <<@leftKey>>
  }

  tdiv {
    flow:t='vertical'

    keyPlace {
      posPlace:t= 'top'
      <<@topKey>>
    }

    <<#needArrows>>
    tdiv { /* arrow place */
      size:t='1@shortcutImageHeight, 1@shortcutImageHeight'
      position:t='relative'
      left:t='50%pw-50%w'

      <<#arrows>>
      arrowImage {
        direction:t='<<direction>>'
      }
      <</arrows>>
    }
    <</needArrows>>

    keyPlace {
      posPlace:t= 'bottom'
      <<@downKey>>
    }
  }

  keyPlace {
    flow:t='vertical'
    posPlace:t= 'right'
    <<@rightKey>>
  }
}
