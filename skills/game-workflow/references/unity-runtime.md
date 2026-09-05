# Unity runtime evidence

Use when serialized values, hierarchy, lifecycle, or a runtime override may control the symptom.

- Identify the observed object/component and its actual owner: scene instance, prefab/variant, spawned clone, persistent service, or pooled object. Check the relevant Unity/package version and source before assuming an API or Editor tool.
- Trace the value's source and writer through initialization, enable/disable, scene transitions, pooling and reload. Distinguish serialized defaults, prefab overrides, runtime assignment, and values saved to disk. Confirm whether a change must persist and where.
- Preserve asset and script GUIDs and their .meta files. Do not regenerate identities to hide a missing reference. Check prefab/scene references before moving or replacing assets.
- For layout defects, inspect the rendered hierarchy, active canvas/camera, anchors, pivots, scale, safe area, layout groups, fitters, animation and scripts that drive the property. A value changed in code may be overwritten later that frame.
- After a speculative patch fails, stop stacking guesses. Obtain concrete evidence such as an object path, runtime value before/after its writer, screenshot, log, profiler capture or serialization diff; revise the hypothesis from that evidence.
- Prove the relevant lifecycle: enter/exit play, reload/reopen, respawn, scene transition or pooling reuse. Select only cases that exercise the suspected owner.
- Preserve user-owned Editor sessions and unsaved scene work. Stop only temporary processes you started for this task. Report required manual Editor actions when automation is unavailable.

Tie findings to source locations or runtime artifacts; label inference. Do not silently turn a diagnosis request into an implementation.
