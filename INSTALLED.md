# What was installed for this project

Everything added to this PC to build and run BO1 Zombies, and how to undo it.

| Date | What | Source | Where | Why | How to remove |
|---|---|---|---|---|---|
| 2026-10-11 | DirectX SDK (June 2010), `Include/` and `Lib/` only | `DXSDK_Jun10.exe` from download.microsoft.com, Authenticode signature valid (Microsoft Corporation), sha256 `705271dc83bfee54d9b94e028426e288d5f070784b7446d164f48ecfbb2a02cb` | `_deps/dxsdk/` in this repo (21 MB, git-ignored). Unpacked with 7-Zip; the SDK installer was never run, nothing system-wide | The engine links d3dx9, xapobase, dxerr from it (CMake `-DDXSDK_DIR`) | Delete `_deps/dxsdk/` |
| 2026-10-11 | Visual Studio 2022 workload "Desktop development with C++" (`Microsoft.VisualStudio.Workload.NativeDesktop`, recommended components; installed MSVC 14.44.35207 / cl 19.44) | Visual Studio Installer already on the PC (Microsoft) | `C:\Program Files\Microsoft Visual Studio\2022\Community\VC\` | Compiler and linker for the 32-bit engine | Visual Studio Installer → Modify → untick "Desktop development with C++" |

## Services, scheduled tasks, background processes

None created.

## Windows Firewall

No rule created. On the first 3-player test Windows asked whether BO1Zombies (build\Splitscreen\p3) may use public and
private networks; the prompt was left for the user. Splitscreen on one PC uses loopback only and works without it.
Playing across PCs (BZ-007) needs "Permitir". To remove a rule later: Windows Security, Firewall, Allow an app.
