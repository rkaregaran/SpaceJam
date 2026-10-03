# Apple, let us adjust animation speed

Switching between [desktop spaces](https://support.apple.com/guide/mac-help/mh14112/mac)
in macOS feels too slow. I keep my editor in one space and my browser in
another, and switch between them with mouse buttons mapped to Control–Left
Arrow and Control–Right Arrow. I do this throughout the day. Waiting for the
slide animation interrupts my flow.

The slide helps me see where I'm going. I want to choose how quickly it
happens. Apple should add an animation speed setting, with the current timing
as the default, a faster preset, and an optional duration in milliseconds.
It should be separate from Reduce Motion.

I built [SpaceJam](https://github.com/rkaregaran/SpaceJam), a small menu bar
app, to try this. It intercepts those keyboard shortcuts and generates a swipe
gesture to move to the adjacent desktop space. The approach comes from
Matthew Bowen's [FasterSwiper](https://github.com/mgbowen/FasterSwiper).

![SpaceJam's duration and Accessibility controls](../images/settings.png)

SpaceJam lets me set the gesture duration between 50 and 1,000 milliseconds.
The default is 100 ms; I use 75 ms. Switching feels much faster. These values
control the generated gesture; macOS can add time for the animation to settle.

The app needs Accessibility permission and must stay running. It works on my
Mac with System Integrity Protection enabled and doesn't modify system files.
This version targets Apple silicon on macOS 27. It leaves trackpad swipes,
Mission Control, and transitions to full-screen apps unchanged.

SpaceJam relies on private macOS interfaces, so an update could break it.
Apple could provide a supported setting that works across keyboard shortcuts,
mouse controls, and trackpad gestures, then extend it to other system
animations.

Animation timing is a preference. Keep the default for people who like it,
and let the rest of us change it in System Settings.
