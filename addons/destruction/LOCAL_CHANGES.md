# Local changes to Jummit Destruction v7.2

Upstream: https://github.com/Jummit/godot-destruction-plugin/releases/tag/v7.2
Original release archive SHA256: `0c328b3024128c87bcfa66a600b444c7560613b3197aa3c2395717a5a289f1e1`
Original code copyright 2023 Jummit, MIT. See LICENSE-MIT.txt.
The icon and its original license record are retained with LICENSE-CC0-1.0.txt.

The original downloaded archive is preserved separately in BattlefieldAssets/rubble_destruction.
Only destruction.gd has been adapted for this validation project:

- Use Godot 4's `transparency = BaseMaterial3D.TRANSPARENCY_ALPHA` instead of the obsolete `flags_transparent` property, and preserve the source color during fading.
- Interpret animation_length as total lifetime; shrinking and fading finish at that deadline. Bind tweens to their rigid body so early removal safely stops animation.
- Keep cached resources and transforms rather than orphaned template nodes; filter non-mesh children before reading mesh properties.
- Respect material overrides and fragment transforms, including rotation of the intact parent. Unit-scale intact parents are recommended for predictable rigid-body collisions.
- Validate the persistent fragment container and guard against duplicate destruction calls.
- Add generated rigid bodies to the `destruction_shards` group for verification and optional performance management.

The destruction mechanism remains Jummit's plugin: a pre-segmented PackedScene supplies meshes, cached convex shapes are built, and destroy() replaces the intact parent with RigidBody3D fragments.
