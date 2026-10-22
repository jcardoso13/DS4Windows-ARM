# DS4Windows

Like those other DS4 tools, but sexier.

DS4Windows is an extract anywhere program that allows you to get the best
DualShock 4 experience on your PC. By emulating an Xbox 360 controller, many
more games are accessible. Other input controllers are also supported including the
DualSense, Switch Pro, and JoyCon controllers (**first party hardware only**).

This project is a fork of the work of Jays2Kings and Ryochan7. It adds various new features like switch 
[debouncing](https://www.ganssle.com/debouncing.pdf), a tool that helps to fix stick drift and pitch and roll simulation
for DS3 based on accelerometer value (which is a work of [sunnyqeen](https://github.com/sunnyqeen)).

## About this fork

I've made this fork because some of the buttons on my controller started bouncing. Normally I would just add a
feature that would fix my problem, make a pull request to the original repo and forget about the project. 
The issue here is that Ryochan7 stopped maintaining the original project, so I decided to make slight 
modifications to the code that detects if the installed version is up-to-date, so it now pulls version info from my 
repo. This way if you install my version, you don't get the annoying popup saying your version is outdated. If there 
are any feature requests, I'm more than happy to at least look at them and assess whether I could add them.

## License

DS4Windows is licensed under the terms of the GNU General Public License version 3.
You can find a copy of the terms and conditions of that license at
[https://www.gnu.org/licenses/gpl-3.0.txt](https://www.gnu.org/licenses/gpl-3.0.txt). The license is also
available in this source code from the COPYING file.

## Downloads

- **[Main builds of DS4Windows](https://ds4-windows.com)**
- This fork's GitHub releases include x64, x86, and native Windows ARM64 ZIPs.
  Choose `DS4Windows_<version>_arm64.zip` for Windows 11 on ARM.

### Windows ARM64 releases

The release workflow builds ARM64 separately on a Windows ARM runner. It rebuilds
ViGEmClient, its managed wrapper, FakerInputDll, FakerInputWrapper, and SharpOSC
from pinned upstream source revisions rather than reusing x64 DLLs. Before
uploading the ZIP, it checks the executable's ARM64 machine type and loads both
native DLLs in an ARM64 process.

Install the ARM64 .NET 8 Desktop Runtime and the ARM64-capable ViGEmBus driver.
The optional bundled HidHide and FakerInput driver installers only support x64
or x86, so those install options are disabled on ARM64. Use the default SendInput
keyboard/mouse handler. Driver installation and controller operation still need
testing on physical Windows ARM hardware. On ARM64, accepting an update opens
this fork's releases page for a manual ZIP update instead of running the upstream
x64-only updater.

To build the ARM64 executable locally on Windows (x64 or ARM64), install:

- Visual Studio 2022 or newer (including Build Tools) with the Desktop development
  with C++ workload, the MSVC ARM64/ARM64EC build tools, and a Windows SDK.
- CMake 3.24 or newer with a generator for your Visual Studio version, and the
  .NET 8 SDK, both available on `PATH`. Newer Visual Studio releases may require
  a newer CMake.
- Internet access for downloading the pinned dependency sources and NuGet packages.

From the repository root, run the build script in PowerShell:

```powershell
.\utils\build-arm64.ps1
```

The script builds the dependencies, publishes the app, and verifies that the EXE
and both native DLLs are ARM64. It stops if any build command fails.
Both the local script and the release workflow use `utils/configure-arm64.ps1`
to discover ARM64-capable Visual Studio installations through `vswhere`, then
select the newest installation supported by CMake. The chosen generator and
installation path are logged. Configuration refreshes the CMake cache to avoid
stale generator or installation settings after toolchain upgrades.
The executable is written to `bin/arm64/Release/output/DS4Windows.exe`.
Keep the entire output folder together when copying the application to your
Windows ARM device; this is not a single-file executable.

To include the .NET runtime in the output instead of requiring a separate Desktop
Runtime installation:

```powershell
.\utils\build-arm64.ps1 -SelfContained
```

The script can also be invoked from another directory using its full path.
It does not install drivers, start the application, or publish a GitHub release.
Linux/WSL cannot run this build because the native DLLs require the Windows
Visual C++ toolchain.

The equivalent manual commands are:

```powershell
.\utils\configure-arm64.ps1
cmake --build bin/arm64-deps --config Release
dotnet publish DS4Windows/DS4WinWPF.csproj -c Release -r win-arm64 --self-contained false /p:Platform=ARM64 -o bin/arm64/Release/output
```

Toolchain discovery regression tests can run in PowerShell without Visual Studio:

```powershell
.\utils\tests\configure-arm64.Tests.ps1
```

## Install

You can install DS4Windows by downloading it from [Official Website](https://ds4-windows.com) and place it to your preferred place.

Alternatively, you can download [`ds4w.bat`](https://github.com/ds4windowsapp/DS4Windows/blob/main/ds4w.bat) file and execute it. It will open a window that downloads and places the program in `%LOCALAPPDATA%\DS4Windows` and creates a desktop shortcut to the executable.

## Requirements

- Windows 10 or newer (Thanks Microsoft)
- Microsoft .NET 8.0 Desktop Runtime. [x64](https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-desktop-8.0.0-windows-x64-installer), [x86](https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-desktop-8.0.0-windows-x86-installer), or [ARM64](https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-desktop-8.0.0-windows-arm64-installer)
- Visual C++ 2015-2022 Redistributable. [x64](https://aka.ms/vs/17/release/vc_redist.x64.exe), [x86](https://aka.ms/vs/17/release/vc_redist.x86.exe), or [ARM64](https://aka.ms/vs/17/release/vc_redist.arm64.exe)
- [ViGEmBus](https://vigembusdriver.com/) driver (DS4Windows will install it for you)
- **Sony** DualShock 4 or other supported controller
- Connection method:
  - Micro USB cable
  - [Sony Wireless Adapter](https://www.amazon.com/gp/product/B01KYVLKG2)
  - Bluetooth 4.0 (via an
  [adapter like this](https://www.newegg.com/Product/Product.aspx?Item=N82E16833166126)
  or built in pc). Only use of Microsoft BT stack is supported. CSR BT stack is
  confirmed to not work with the DS4 even though some CSR adapters work fine
  using Microsoft BT stack. Toshiba's adapters currently do not work.
  *Disabling 'Enable output data' in the controller profile settings might help with latency issues, but will disable lightbar and rumble support.*
- Disable **PlayStation Configuration Support** and
**Xbox Configuration Support** options in Steam
