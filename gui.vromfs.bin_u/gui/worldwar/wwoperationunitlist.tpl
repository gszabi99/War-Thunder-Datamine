tdiv {
  width:t='pw'
  flow:t='vertical'

  tdiv {
    width:t='pw'

    <<#teams>>
      tdiv {
        id:t='<<teamName>>'
        width:t='50%pw'
        padding:t='1@framePadding'
        flow:t='vertical'
        pos:t='0.01@sf, 0'
        position:t='relative'

        activeText {
          text:t='#events/<<teamName>>'
          position:t='relative'
          pos:t='0, 0'
        }

        tdiv {
        <<#countries>>
          cardImg { background-image:t='<<countryIcon>>' }
        <</countries>>
        }

        tdiv {
          id:t='allowed_unit_types'
          flow:t='vertical'
          margin-bottom:t='0.01@sf'

          activeText {
            id:t='allowed_unit_types_text'
            text:t='#worldwar/available_crafts'
          }

          <<@unitsList>>
        }
      }
    <</teams>>
  }
}