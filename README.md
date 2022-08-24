# Monterey & Apple Silicon(M1)/arm64 compatible Macfusion 2
The original code of Macfusion 2 is bundled with pre-compiled binaries.
This made it difficult to build apps for the successor new environments.
Now these pre-complied binaries are wiped out and replacement binaries will be generated for your environment instead.

- Sparkle.framework is included as submodule.
- The plugins, SSHFS and FTPFS, are automatically built according to your environment.<br>
(These source codes are not submoduled, because almost obsolete and require minor modifications.)
    - SSHFS: v2.10 (mainstream is v3.x)
    - FTPFS(curlftpfs): Last update in 2007, and some modification in 2014.<br>
    (https://github.com/JackSlateur/curlftpfs)

# Development Environment
- MacBook Pro (2021, M1) + Monterey
- MacBook Pro (2018, Intel) + Monterey

# Build
```
$ git clone --recursive https://github.com/hepacc/macfusion2.git -b 2.1.1-dev3
$ cd macfusion2
$ xcodebuild -target All [-arch x86_64/arm64; recommended*]
```
Clone the `2.1.1-dev3` branch, it is based on the latest release.
(Currently the master branch based one looks not work correctly.)
After successful build, the `Macfusion.app` is placed below `macfusion2/Release`.
I recommend to specify `-arch` option because of the limitation described below.

# Limitations
- Build binaries included in the plugins are not static-linked, but dynamically refer to external libraries; in my case, libraries below homebrew directory.
The original version was bundled with static-linked binraies.
- This means that even if the app itself (including Sparkle.framework) appears to be "univarsal", 
the plugins are build environment specific (x86_64 or arm64),
and will not work properly in the other environment.
- FTPFS(curlftpfs) plugin is not tested (because I don't use it).<br>
(Anonymous access looks OK, but user authentication DON'T.)

<br>
<br>
The followings is the README.md in the original repository forked.

---
---
---
<br>
<br>

Macfusion 2
===========

[Macfusion][] brings servers from across the internet directly to your Mac's desktop!

![icon](http://i.imgur.com/zGp4o.png)

- Mount files and documents as a "Volume" in the Mac OS X Finder
- Work with your files using your favorite Mac OS X applications directly. No manual upload or download needed!
- Support for SSH (Secure Shell) and FTP (File Transfer)
- Uses your machine's native configuration for SSH, including support for private keys and custom settings.
- Quickly connect to any server using the *Quick Connect* dialog, accessible from Macfusion's optional menu item.


Download
========

You can download a [build of the development version][], currently only tested in Mac OS X Lion.

Remember that depending on the operating system you are using you will have to install any of the following dependencies:

- X11, OSX 10.8 needs a manual installation of [XQuartz][]; it is very likely that you already have this installed in your computer if you are using 10.7 or lower.
- For Mac OS X 10.6, you will need [MacFUSE][].
- For Mac OS X 10.7 and greater, you need [Fuse for OSX][], note that **you will need to check** the *"install MacFUSE compatibility layer"* option during the installation process, otherwise some parts of the software will be broken.

Roadmap
=======

- Update the icons and resources for a retina display resolution, if you are a designer and you can help, please contact me [@yoshikivb][].
- Fix as many bugs as possible.
- Release a stable 2.1 version in the near future.

Current fixes
=============

- Include a way to call a newer version of sshfs to work in OS X Lion and greater.
- Application no longer crashes when deleting a filesystem.
- Ability to expand the mount path, for example: `~/filesystem` to `/Users/yoshiki/filesystem`. 
- Modified the menu application to toggle between mount and un-mount filesystem.
- Added a checkbox to add (or not) a mounted filesystem into Finder's sidebar.
- Added the output of `git rev-parse --short HEAD` to the about window.

[Macfusion]:http://macfusionapp.org/
[MacFUSE]:http://code.google.com/p/macfuse/
[Fuse for OSX]:http://osxfuse.github.com
[XQuartz]:http://xquartz.macosforge.org
[build of the development version]:https://github.com/ElDeveloper/macfusion2/releases/tag/2.1-dev
[@yoshikivb]:https://twitter.com/yoshikivb
