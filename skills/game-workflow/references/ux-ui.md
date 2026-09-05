# Game UI specification and rendered evidence

Inspect available visual sources and existing art direction, components, assets and tokens. A screenshot, Figma node, or runnable view is evidence; prose alone does not prove the actual layout. State missing sources and distinguish requirements, assumptions and conflicts.

Map the scoped requirement to a design decision, element/state and observable acceptance check. Prefer one coherent direction. Reuse exact existing tokens; propose new values only where needed. Cover applicable normal, hover, focus, loading, empty, error, disabled and pause states rather than creating every state for every element.

Evaluate target resolutions/aspect ratios and safe areas. Check only relevant controller/keyboard/mouse/touch navigation, focus restoration, localization expansion, fallback glyphs, plural/RTL requirements, contrast, readable sizing, color-independent signals, motion and reduced-motion behavior. For HUDs, test readability against gameplay motion and background variation.

After implementation inspect rendered screenshots/video or a runnable view at representative sizes and interactions. Check anchors, alignment, overflow, focus/navigation and motion against the specification. Record actual evidence and deviations; compilation and source inspection cannot establish visual parity. If rendering is unavailable, describe that gap and avoid claiming visual completion.
