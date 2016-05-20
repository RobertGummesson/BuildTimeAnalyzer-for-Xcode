Build Time Analyzer for Xcode
======================

## Overview

Build Time Analyzer is an Xcode plugin that shows you a break down of Swift build times. See [this post on Medium]( https://medium.com/p/fc92cdd91e31) for context.

## Usage

Open the analyzer window by tapping `Shift+Ctrl+B` or `View` > `Build Time Analyzer`. From there just follow the instructions.

![screenshot.png](https://raw.githubusercontent.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode/master/Screenshots/screenshot2.png)

## Installation

Build Time Analyzer is available through [Alcatraz - The package manager for Xcode](http://alcatraz.io/). Make sure you restart Xcode after the plug-in is installed.

If you rather compile it yourself, simply build the Xcode project and restart Xcode. The plugin will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. To uninstall, just remove the plugin from there (and restart Xcode).

Currently, the plugin supports Xcode 7.2.1 and above. See https://github.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode/issues/20 to add support for other Xcode versions.

## Contributions

If you encounter any issues or have ideas for improvement, I am open to code contributions.

## License

    Copyright (c) 2016, Robert Gummesson
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
