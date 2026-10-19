# Native design principles

Design guidance: [Emil Kowalski's Apple Design skill](https://github.com/emilkowalski/skills/blob/main/skills/apple-design/SKILL.md), explicitly requested for this project.
Its web examples are applied through native macOS controls and frameworks.

- Respond on press and track region/waveform drags directly. Do not animate the
  selection away from the pointer or delay input to wait for a transition.
- Use interruptible, critically damped springs for press/reorder affordances.
  Reduce Motion removes scaling and spring movement while preserving feedback.
- Use semantic/adaptive colors for the canvas, surfaces and foreground text.
  Verify actual screenshots of both the workspace and tool sheets in each appearance.
- Use opaque semantic surfaces for structural chrome and the drag wheel. The
  custom Liquid Glass experiment was removed at the user's request because
  underlying windows made sidebar text difficult to read. Keep window backgrounds
  opaque; do not add full-window blur or floating transparent panels.
- Use the system font, deliberate hierarchy, tight heading tracking and comfortably
  sized field labels. Color is not the sole indication of success or failure.
- Put preview and controls next to each other. Expose common settings first and
  put JSON overrides one level deeper. Keep Cancel and the named action visible.
- Keep processing off the main actor. Show queued/running/completed/failed states,
  preserve originals, report partial batch results, and allow cancellation.
- Make all compatible tools discoverable in the workspace, drag wheel and keyboard
  menu. Show the mode-switch keys in the wheel itself. Keep labels legible as the
  number of choices grows.

Native sheets and scroll views provide platform behavior. There are no custom
full-screen moving backgrounds, decorative looping animations or artificial
conversion delays. AirDrop, file pickers, clipboard and Terminal use AppKit.

## Brand artwork

The mark keeps the original orange rounded tile and simple white graphics. A
closed circular tangerine outline, short stem and one leaf replace the leaf-only
symbol. Do not use photos or realistic 3D fruit. `scripts/make-brandmark.swift`
draws the artwork from paths. The generated PNG resource supplies the workspace,
menu bar and application icon; `scripts/make-icon.swift` creates the iconset.

## Installer

The Finder disk image uses the app’s warm canvas and orange accent. The app icon
sits on the left; an arrow leads to a stationary wheel surrounding the actual
Applications shortcut. The wheel is decoration around the native Finder drop
target. There is no installer executable, animation, network request or privileged
helper. A Retina TIFF and saved icon positions keep artwork and targets aligned.
