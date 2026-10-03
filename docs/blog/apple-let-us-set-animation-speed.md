# Apple, let me set the speed of my Mac

*A small request for a setting that would make a big difference to how I work.*

I love working on a Mac. I also find some of its animations infuriating.

I use desktops constantly. One holds my editor. Another holds the browser.
Another holds the other pieces of whatever I'm trying to figure out. I switch
with buttons on my mouse, mapped to Control–Left and Control–Right. It is a
quick, deliberate action. I already know where I want to go.

Then the screen slides, and I wait for it to catch up.

That pause breaks my flow. Not because I have a stopwatch running, or because
I can prove a grand productivity equation. It simply feels like the computer
is taking its time after I've made a decision. Do that throughout a working
day and the friction gets old.

Apple, please give us a way to adjust animation speed.

## Keep the animation. Give me control of the timing.

Animations communicate useful things. A slide tells me that I moved to another
desktop. A window expanding tells me where it came from. Motion can make an
interface easier to understand, and different people have different needs.

I want to keep that continuity. I want the slide to happen faster.

Reduce Motion addresses a different preference: the amount and kind of motion
someone wants to experience. I would love an independent timing setting. Keep
the current behavior as the default. Let me choose a faster preset or enter a
duration in milliseconds. Let another person choose a slower transition if
that helps them.

A Mac should adapt to the person using it. Some of us navigate deliberately,
repeat the same transitions throughout the day, and value an interface that
responds at the pace of our hands. That is a perfectly reasonable preference
to expose in Settings.

## So I built SpaceJam

I wanted to see whether I could get the desktop transition I wanted without
giving up the slide. The result is [SpaceJam](https://github.com/rkaregaran/SpaceJam),
a small menu bar app with one settings window.

![SpaceJam's duration and permission controls](../images/settings.png)

It lets me choose a duration between 50 and 1,000 milliseconds for ordinary
desktop switching through Control–Left/Right. That also covers my mouse
buttons, because they send those shortcuts. Its default is 100 ms, and I can
choose 75 ms for a quicker gesture.

Those values describe the gesture the app generates. They are not a claim
that every pixel finishes moving in exactly that time; macOS can add settling
time. My conclusion is a personal one: switching this way feels much better
to me.

The app can live in the menu bar or run quietly with its icon hidden. Reopening
it brings settings back. I can pause it, see whether its permission is enabled,
and have it open at login. That is the extent of the interface.

## The workaround should not have to exist

The useful lead came from Matthew Bowen's
[FasterSwiper](https://github.com/mgbowen/FasterSwiper). Credit belongs there
for the synthetic-gesture approach. SpaceJam adapts that engine and adds its
own settings, onboarding, lifecycle handling, and packaging. The new app code
is MIT licensed; the adapted gesture code retains Apache-2.0 and its notices.

Instead of asking macOS to perform the usual keyboard transition, SpaceJam
listens for the shortcut and sends a synthetic desktop-swipe gesture. It
advances that gesture along a short ease-out trajectory, then ends it so macOS
commits the destination desktop. It also reads the current desktop state to
choose an adjacent ordinary desktop and verify the transition.

That relies on private macOS interfaces and a private gesture format. It is a
workaround, and an OS update can break it. This version is scoped to Apple
silicon on macOS 27. It leaves physical trackpad swipes, numbered shortcuts,
Mission Control, and fullscreen transitions with their native behavior.

Earlier experiments modified Dock's memory and needed a debugging exception
to System Integrity Protection. We restored those changes and re-enabled full
SIP. The gesture app works on my Mac with SIP fully enabled; it needs the
user's Accessibility permission and must remain running. It does not patch
Dock or modify system files.

I am preparing signed, notarized downloads and a straightforward installation:
drag the app into Applications, drag its tile into the permission list, and
turn on the switch. Homebrew and a terminal installer are being prepared too.
That makes the workaround easier to use. It still leaves me maintaining an
app around an implementation detail Apple could change at any time.

## Please make this a native setting

What I want from Apple is small and concrete:

- An **Animation Speed** preference with the current behavior as its default.
- A faster preset and an optional custom duration.
- Separate control from Reduce Motion, so timing and motion preference can
  serve different needs.
- Consistent behavior for desktop switching and other recurring system
  transitions, with sensible limits where timing affects interaction.

Apple can implement this where the animations actually live. It can support
trackpad input, keyboard shortcuts, mouse mappings, and future macOS releases
without requiring a background utility to imitate a gesture.

I don't want everyone else's Mac to behave like mine. I want a setting that
lets mine behave the way I prefer.

Please, Apple. Give us the knob.
