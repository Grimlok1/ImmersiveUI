ImmersiveUI 0.1.0 - WoW Forever interface 16001

Installation:
Extract the ImmersiveUI folder into your client Interface/AddOns directory.
Restart the game or reload the UI, and enable ImmersiveUI in the addon list.

Behavior:
Out of combat with no target: fades from full opacity to zero over 10 seconds.
Taking any target or entering combat: immediately restores full opacity.
The next fade begins when BOTH conditions are clear.
No settings or dependencies.

This initial version fades UIParent, including chat, bags and menus.
Frames that ignore parent alpha may remain visible. Transparent controls can
still receive clicks. To access the UI, select a target first.

In-game test:
Clear your target out of combat; verify the UI disappears over 10 seconds.
Select a target halfway through or after the fade; verify immediate restoration.
Clear the target during combat; verify the UI stays visible until combat ends.

Not yet tested inside the WoW Forever client.
