# HydroCoop
Experimental two-PC online multiplayer research for Hydroneer (UE4SS, Unreal Engine 4.26).

**Current status v0.5: NOT playable online co-op.** This build transfers read-only player position and rotation via a private UDP relay. There is no remote character or shared-world synchronization yet.

## Install / update
Close Hydroneer, ensure UE4SS is installed, and open PowerShell:

```powershell
irm https://raw.githubusercontent.com/SirPepperPot/HydroCoop/main/Install-HydroCoop.ps1 | iex
```

This runs the public repository installer (review its source if desired). It updates the Lua mod, installs HydroCoop-Relay.ps1 in Hydroneer's Win64 folder, and enables the mod automatically. The default game path is `E:\Steam\steamapps\common\Hydroneer\Mining\Binaries\Win64`.

## Two-PC movement transport test
Both players install UE4SS and HydroCoop; both connect using a private, trusted Tailscale network. Both launch separate single-player sessions in disposable worlds. Open PowerShell in Hydroneer's Win64 folder.

Host:
```powershell
powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Host
```

Friend:
```powershell
powershell -ExecutionPolicy Bypass -File .\HydroCoop-Relay.ps1 -Mode Client -HostIP 100.x.x.x
```

Replace `100.x.x.x` with host's actual Tailscale IPv4. The relay uses UDP port 49221 (Windows firewall may need an inbound rule for trusted network). The relay writes `Mods\HydroneerMPProbe\remote_state.txt` as packets arrive; consoles show sent/received counters. The protocol is not authenticated or encrypted itself; use trusted Tailscale peers, not public port forwarding.

If `local_state.txt` isn't created, check UE4SS.log for `[HydroCoop v0.5]` and Lua errors. Close Hydroneer before upgrading. Press Ctrl+C to exit relay.

To disable this experimental mod, close Hydroneer and delete `Mods\HydroneerMPProbe` (do not delete UE4SS).

## Future work
Remote player actor spawning and interpolation, interactions, inventory, physics, world persistence, and session lifecycle are not yet implemented.
