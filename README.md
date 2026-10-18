# HydroCoop
Experimental **two-player-only** online multiplayer research for Hydroneer (Unreal Engine 4.26 / UE4SS). **Not playable online co-op yet.**

## Current state
v0.4 is a read-only diagnostic probe. It captures local player controller/pawn positions and rotations once per second for 10 seconds on **Ctrl+Alt+F8**. Network transport, remote-character spawning, shared world state, and proper online multiplayer are **not implemented**.

## One-command update / install (Windows PowerShell)
Close Hydroneer first. Requires UE4SS already installed in the Hydroneer Win64 folder. This command downloads the installer from this public repository and executes it:
```powershell
irm https://raw.githubusercontent.com/SirPepperPot/HydroCoop/main/Install-HydroCoop.ps1 | iex
```
**Security:** This executes remote repository code. Review `Install-HydroCoop.ps1` before running if desired. The installer only downloads our Lua file, backs up the previous `main.lua`, copies the file into UE4SS's Mods directory, and adds `enabled.txt`. It assumes Hydroneer is installed at `E:\Steam\steamapps\common\Hydroneer` (edit the installer for another location).

## Uninstall
Close the game and remove `Mining\Binaries\Win64\Mods\HydroneerMPProbe`. UE4SS itself is not removed.

Test in a disposable world. Earlier experimental player-function hooks disrupted local co-op; v0.4 does not register any gameplay hooks.
