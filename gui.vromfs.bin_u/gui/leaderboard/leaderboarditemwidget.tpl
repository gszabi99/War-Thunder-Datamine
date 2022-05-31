<<#items>>
tdiv {
  id:t='<<id>>';
  width:t='<<#width>><<width>><</width>><<^width>>0.27@scrn_tgt<</width>>';
  pos:t='<<#pos>><<pos>><</pos>><<^pos>>0, 0<</pos>>';
  position:t='relative';
  margin:t='<<#margin>><<margin>><</margin>><<^margin>>0, 0.014@scrn_tgt, 0.021@scrn_tgt, 0<</margin>>';
  flow:t='vertical';
  re-type:t='9rect';
  background-image:t='#ui/gameuiskin#block_bg_rounded_flat_black';
  background-position:t='4';
  background-repeat:t='expand';
  background-color:t='@white';

  tdiv {
    id:t='header'
    re-type:t='9rect';
    background-image:t='#ui/gameuiskin#block_bg_rounded_dark';
    background-position:t='4';
    background-repeat:t='expand';
    background-color:t='@white';
    width:t='pw';
    height:t='0.03@scrn_tgt';
    padding:t='0.001@scrn_tgt';
    padding-left:t='0.01@scrn_tgt'

    textarea {
      width:t='fw';
      height:t='ph';
      pare-text:t='yes';
      text:t='<<name>>';
      removeParagraphIndent:t='yes';
    }
  }
  tdiv {
    id:t='content';
    padding:t='0.01@scrn_tgt';
    width:t='pw';
    tdiv {
      id:t='icon';
      img {
        size:t='0.055@scrn_tgt, 0.055@scrn_tgt';
        background-image:t='<<icon>>';
      }
    }

    tdiv {
      flow:t='vertical';
      width:t='fw';
      position:t='relative';
      pos:t='0, ph/2 - h/2';

      <<#progress>>
      tdiv {
        id:t='progress';
        position:t='relative';
        pos:t='pw - w';

        img {
          size:t='@sIco, @sIco';
          <<#positive>>
          rotation:t='180';
          style:t='background-color: @green;';
          background-image:t='#ui/gameuiskin#expand_info';
          <</positive>>

          <<^positive>>
          style:t='background-color: @red;';
          background-image:t='#ui/gameuiskin#expand_info';
          <</positive>>
        }

        <<#diff>>
        textareaNoTab {
          id:t='<<id>>'
          text:t='<<#positive>> +<</positive>><<text>>';
          tooltip:t='<<tooltip>>'
        }
        <</diff>>
      }
      <</progress>>

      tdiv {
        id:t='value';
        position:t='relative';
        pos:t='pw - w, 0';
        textarea {
          text:t='<<text>>'
          removeParagraphIndent:t='yes';
        }
      }
    }
  }
}
<</items>>
