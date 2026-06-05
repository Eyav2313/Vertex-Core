# Vertex UI/UX Vision

## Design Direction

Vertex Glass is a premium minimalist desktop language built around depth, light, translucency, and generous whitespace. The system should feel calm, precise, and fast rather than decorative.

## Principles

- Glass surfaces are used for focused controls, not every container.
- Background blur must be high quality but performance bounded.
- Text contrast always wins over transparency.
- Rounded corners stay moderate and consistent.
- Motion is fluid, short, and functional.
- Dense tools are allowed to be dense, but never cramped.
- The desktop should look composed at 100 percent scaling before being tuned for high DPI.

## Visual Tokens

| Token | Value |
| --- | --- |
| Primary background | `#0E1117` |
| Elevated glass | `rgba(24, 28, 36, 0.70)` |
| Thin glass | `rgba(255, 255, 255, 0.08)` |
| Primary text | `#F5F7FA` |
| Secondary text | `#AAB2C0` |
| Accent cyan | `#69D2FF` |
| Accent green | `#76F7B2` |
| Warning | `#FFD166` |
| Error | `#FF6B7A` |
| Radius small | `8px` |
| Radius medium | `14px` |
| Radius large | `20px` |
| Window gap | `10px` to `14px` |

## Desktop Behavior

- Login should show a single glass authentication surface over a calm image or generated abstract material.
- Windows use subtle opacity only where it improves spatial awareness.
- Terminal uses a graphite base with cyan/green accents for a security-workstation feel.
- Panels and launchers should not fight for attention.
- Blur and shadow are reduced automatically on low-power or software-rendered sessions.

## Accessibility Requirements

- Maintain readable foreground/background contrast even on translucent panels.
- Provide a reduced motion profile.
- Provide a low transparency profile.
- Support keyboard-only login, launch, window movement, and shutdown workflows.
- Avoid tiny click targets in system surfaces.
