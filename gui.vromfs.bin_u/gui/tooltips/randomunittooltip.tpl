div {
  id:t='air_info_tooltip';
  flow:t='vertical'
  smallFont:t='yes'
  countryExpType:t='wide';
  behavior:t = 'Timer';

  textAreaCentered {
    id:t='group_name'
    text:t='<<groupName>>'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    text-align:t='center'
  }
  tdiv {
    pos:t='50%pw-50%w, 0';
    position:t='relative';
    margin-bottom:t='10@sf/@pf'

    textareaNoTab { text:t='<<rankGroup>>' }
    tdiv {
      margin-left:t='0.02@sf'
      textareaNoTab { text:t='<<battleRatingGroup>>' }
    }
  }
  tdiv {
    id:t='units_list'
    pos:t='50%pw-50%w, 0';
    position:t='relative';
    flow:t='vertical'

    activeText {
      id:t='aircraft-name';
      pos:t='50%pw-50%w, 0';
      position:t='relative';
      caption:t='yes'
      text-align:t='center'
      text:t='#respawn/randomUnitsGroup/content'
    }
    <<#units>>
      tdiv {
        pos:t='50%pw-50%w, 0';
        position:t='relative';
        smallFont:t='yes';
        img {
          id:t='air_icon';
          background-image:t='<<unitClassIcon>>';
          shopItemType:t='<<shopItemType>>';
          size:t='@tableIcoSize, @tableIcoSize';
          background-svg-size:t='@tableIcoSize, @tableIcoSize';
        }
        activeText {
          id:t='air_name';
          padding-left:t='4*@sf/@pf';
          padding-top:t='4*@sf/@pf';
          text:t='<<name>>';
        }
      }
    <</units>>
  }
}
