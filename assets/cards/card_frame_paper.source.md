# Paper card frame

Generated with the built-in imagegen tool using the approved paper-fairy-tale card mockup as a material/style reference. The final local texture is `card_frame_paper.png`. Card art, text, stat emblems and animations are separate Godot scene nodes.

Initial prompt:

Use case: background-extraction / game UI asset. Use the reference solely for its beautiful paper-cut card MATERIAL AND FRAME STYLE. Produce ONE isolated BLANK FRONT of an ingredient card, straight front view, on a genuinely transparent background. Single card only, portrait approximately 2:3 aspect ratio. Card fills 96% of the canvas with a tiny transparent margin for a shallow shadow. No scene, no board, no characters, NO illustration, NO TEXT, NO NUMBERS, NO ICONS, NO stat badges. This is a reusable production UI texture to have game text and art layered on later.
Construct a beautiful understated handmade BLUE-TEAL cardstock border around a warm ivory parchment face. Border is narrow (about 5% of width) but dimensional, with a dark paper lower edge and a soft lighter cut-paper inner bevel. At the four corners tiny restrained embossed curled-paper motifs integrated into the frame, consistent with the mint card in the reference. Slightly imperfect die-cut silhouette, tactile paper fibers, not glossy, not realistic leather or metal, not vector clipart. Opaque unmarked light parchment throughout the interior; preserve generous empty area. One very subtle hand-drawn ochre decorative divider line at 64% of card height, leaving the entire lower THIRD empty for description. Upper interior should be completely open with no picture window, no large medallions, no separate white rounded panels. The blue frame and pale warm paper must be visually separable by hue for in-engine color variation. Outside the card truly transparent, with only a very small natural drop shadow. No checkerboard printed into the image.

Final edit prompt:

Precise asset edit. Preserve this exact single blue paper card frame, its dimensions, colors, all corner decorations, border, outer edges, material and parchment texture. Remove ONLY the thin gold horizontal ornamental divider and its tiny central leaf motif in the lower third. Fill that area seamlessly with matching blank parchment. The entire parchment interior must now be blank, so game text can start higher and flow naturally. No new markings, no lettering, no illustrations. Keep everything else unchanged.

The generated outer backdrop is masked at the die-cut border by `shaders/card_frame.gdshader`; this shader also recolors the cold border for the four card families without tinting the warm paper. The divider is now a separate scene element, so the description can start higher and wrap around the heat emblem.
