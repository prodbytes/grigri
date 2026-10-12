# Theme

Dark only, for now, in mountain colors
([grigri_app/lib/theme.dart](../grigri_app/lib/theme.dart), `Mountain`):

| Name | Color | Used for |
|---|---|---|
| night | `#161A16` | The background: dark rock with a hint of green |
| surface | `#1F241E` | Cards, sheets, the navigation bar |
| surfaceHigh | `#2A3028` | Chips, inputs, raised surfaces |
| olive | `#A3B06A` | Primary: main buttons, selection |
| moss | `#6F9468` | Icons and large accents only (3.9:1 on surfaceHigh) |
| pine | `#3F5C45` | Primary containers, the navigation indicator, selected chips |
| sand | `#E2D3B3` | Headings and highlights |
| tan | `#B9936A` | Tertiary: warm accents |
| granite | `#9AA09A` | Secondary text, unselected icons |
| sky | `#86B8DC` | Secondary: links, information, the match highlight |
| clay | `#D9826B` | Errors and "pass" |
| snow | `#ECE6D6` | Body text |

The colors share low saturation and warm undertones, so they sit together
like a landscape: greens and browns for the ground, the blue as the one
cool accent. Every text color reads at WCAG AA (4.5:1) or better on the
background and on raised surfaces. Cards have 20 px rounded corners and a
thin outline instead of shadows.
