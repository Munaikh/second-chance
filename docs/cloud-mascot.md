# Cloudy, the Raise assistant

Revised 7 November 2026 against the user-provided cloud reference. This vector redraw follows its large round dome, three rounded lower lobes, lavender round glasses and bridge, violet eyes with white catchlights, pink cheeks, and curved purple smile. Soft white-to-ice/lavender gradient fills supply depth. The Lottie contains newly authored vector geometry and no embedded image, external asset, font, or expression.

Asset: `assets/raise_cloud.json`. Transparent 512 × 512 composition, 60 fps, 120 frames. Body bounds approximately x=73–439 and y=100–388; eye line y=235, above stage center. Separate shape layers explicitly put the face above the body.

## Playback

- Idle: frames 0–59, controller 0–0.5; soft float and blink. Suggested real period: 3 seconds.
- Listening: frames 60–89, controller 0.5–0.75; attentive widened eyes and gentle double bounce. Suggested period: 1.2 seconds.
- Speaking: frames 90–119, controller 0.75–1; gentle bob and animated smiling mouth. Suggested period: 0.9 seconds.

Each range begins and ends at the neutral pose. Frames 60 and 90 anchor phase transitions; frame 119 holds through the endpoint. Speech animation indicates activity rather than matching phonemes. Freeze frame 0 for reduced motion.

## Placement and validation

Use a 260–300-pixel transparent square above the expandable financial sheet; the body fills approximately 72% of its width. Keep the glasses and smile visible above the sheet. A cool sky gradient supports the lavender shading. No external ambient shadow is included.

JSON parsing, matching path tangent/vertex counts, and ordered keyframe bounds passed assert-based checks. Flutter tests load the real asset, advance all three controller ranges and verify the reduced-motion freeze. The final native Home rendering was visually inspected, including the glasses, visible face and sheet overlap. Speaking motion indicates conversation state; it is not lip synchronization.
