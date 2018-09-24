# About
DDev is a simple tool made in D to make it easier to work on the DMD compiler, DRuntime, and Phobos. (At least on Windows since it's a pain)

# Known issues
Currently there is only support for windows, but with some tiny tweaks/additions it should be easy enough to add other platforms.

I'll get round to adding Linux and OSX once I can be bothered to setup VMs for them.

Building DMD in debug mode seems to cause unittests to fail when it is used (for a 24/09/2018 build at least), so always build it in release mode.
If you accidentally build it in debug mode, then simply delete the `dmd.exe` at `dmd2/output/bin/dmd.exe` and the tool will go back to using
the HOST_DC you specify in it's configuration. From there, simply rebuild DMD in release.

# Usage
First, place the script into it's own folder.

Open the file and look under the 'CONFIGURATION' section and set it up for your own needs.

Run/compile it with dub using `dub run --single ddev.d` or `dub build --single ddev.d`.

Run `ddev setup` and it'll give you an error telling you to download something from the Dlang website. Follow it's instructions.

Run `ddev setup` again to setup your development environment. The tool will clone all the forks/official repos based on your configuration.

Run `ddev build dmd release` (debug dmd seems to fail unittests for some reason).
From this point on, the tool will use the newly-built DMD for building, instead of the one specified in the configuration.

Run `ddev build druntime`

Run `ddev build phobos` (I think you may need DMC on your path for this)

If all the above could be done without errors, then everything should be setup.

Modify the projects to your needs, then simply run the `ddev build xxx` command again.

# Future considerations
* Linux and OSX support

* `ddev clean dmd/druntime/phobos/all` (calls the 'clean' target for their makefiles. Here for convenience)

* `ddev sync-with-master dmd/druntime/phobos/all` (pulls upstream/master into the current branch. Here for convenience)

* The willpower to try and fix any issues that pop up.