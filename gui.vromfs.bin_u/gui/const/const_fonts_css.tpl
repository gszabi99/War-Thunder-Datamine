

/*type of layout - pixel or fixed can be set here*/
@const scrn_tgt       : <<scrnTgt>>;
@const isWide         : <<isWide>>;
@const pf_outdated    : <<pxFontTgtOutdated>>; /*in this height images are pixel to pixel*/
@const sf: <<scrnTgt>>;
@const pf: 1080; /*smooth pixel size multiplyer, usage: @sf/@pf */

/* fonts */
@const fontTiny:        very_tiny_text<<set>>;
@const fontSmall:       tiny_text<<set>>;
@const fontNormal:      small_text<<set>>;
@const fontNormalBold:  small_accented_text<<set>>;
@const fontMedium:      medium_text<<set>>;
@const fontBigBold:     big_text<<set>>;
