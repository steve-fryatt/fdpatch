FilerDirPatch
=============

Patch the Desktop Filer's directory menu.


Introduction
------------

FilerDirPatch is a small patch to cause a new directory to be created if New directory is selected in a Filer window (instead of moving the pointer right to open the dialogue box).

As a long-time user of MS Windows, this had always seemed an omission and with the arrival of RISC OS 4 and the Alt-click renaming in the window, I often found myself wishing that the option worked as expected.

Although the patch is trivial, having written it it seems daft to make others who would like the feature re-invent the wheel.


Building
--------

FilerDirPatch consists of a collection of ARM assembler and un-tokenised BASIC, which must be assembled using the [SFTools build environment](https://github.com/steve-fryatt). It will be necessary to have suitable Linux system with a working installation of the [GCCSDK](http://www.riscos.info/index.php/GCCSDK) to be able to make use of this.

With a suitable build environment set up, making FilerDirPatch is a matter of running

	make

from the root folder of the project. This will build everything from source, and assemble a working FilerDirPatch module and its associated files within the build folder. If you have access to this folder from RISC OS (either via HostFS, LanManFS, NFS, Sunfish or similar), it will be possible to run it directly once built.

To clean out all of the build files, use

	make clean

To make a release version and package it into Zip files for distribution, use

	make release

This will clean the project and re-build it all, then create a distribution archive (no source), source archive and RiscPkg package in the folder within which the project folder is located. By default the output of `git describe` is used to version the build, but a specific version can be applied by setting the `VERSION` variable -- for example

	make release VERSION=1.23


Licence
-------

FilerDirPatch is licensed under the EUPL, Version 1.2 only (the "Licence"); you may not use this work except in compliance with the Licence.

You may obtain a copy of the Licence at <http://joinup.ec.europa.eu/software/page/eupl>.

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "**as is**"; basis, **without warranties or conditions of any kind**, either express or implied.

See the Licence for the specific language governing permissions and limitations under the Licence.