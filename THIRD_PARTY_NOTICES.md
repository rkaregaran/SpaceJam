# Third-party notices

SpaceJam's original app, settings, onboarding, packaging, and documentation are
MIT licensed. The following adapted components retain Apache-2.0:

- `Sources/ThirdParty/GestureEvents.h`
- `Sources/SwitchEngine.mm`
- `Tests/EventProtocol.mm`

These files build on [FasterSwiper](https://github.com/mgbowen/FasterSwiper),
Copyright 2026 Matthew Bowen, at revision
`b5491e496b2721828dffd40d08facd289bbe7d19`. They adapt the gesture protocol,
serialization, desktop progress scale, and switch/commit algorithms. Changes
include a standalone implementation without FasterSwiper's build dependencies,
bounds checks, lifecycle cancellation, a bounded queue, source tagging, and
destination verification. Original notices are preserved in the source files.

A copy of the Apache license is in `LICENSES/Apache-2.0.txt`. FasterSwiper's
upstream attribution document is included as
`LICENSES/FasterSwiper-Upstream-Attributions.md` for provenance. Its complete
list includes tools and libraries used by FasterSwiper; those tools and
libraries are not bundled dependencies of SpaceJam.

These notices and licenses are also included in the distributed app bundle.
The MIT license does not replace the licenses of these adapted components.
