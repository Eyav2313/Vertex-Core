# Vertex Desktop Preview Structure

This preview is split by UI responsibility so each area can evolve without turning `index.html` into a giant file again.

- `shared/` - fonts, cursors, wallpaper base, responsive rules, bootstrapping, small utilities.
- `boot/` - boot logo, shine, boot spinner, boot timing, boot reveal sound.
- `lockscreen/` - wallpaper interaction, clock, date, unlock hint, lock surface gestures.
- `system/` - battery, network, system status widgets, system metrics.
- `panels/` - status popovers, accessibility controls, shared panel behavior.
- `appearance/` - Vertex Appearance window, customization controls, drag handling.
- `login/` - profile, password field, cancel action, password validation.
- `keyboard/` - on-screen keyboard layout, styling, and input behavior.
- `power/` - suspend, restart, shutdown transition, Linux-style power logs.

`index.html` should stay as the composition shell only: markup plus ordered CSS/JS imports.
