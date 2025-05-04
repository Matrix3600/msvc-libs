Download and build the repackaged MSVC/SDK library
--------------------------------------------------

You can use the Makefile included in this directory to download the Visual
Studio library and create a repackaged standalone library from it.

It runs on Windows or Linux.

The original files are downloadable from the Microsoft servers. You
must accept the [license](https://go.microsoft.com/fwlink/?LinkId=2179911).

Note that the Visual Studio library is not redistributable, so neither is the
repackaged version.



Requirements
------------

- On Windows, the download directory (where the Makefile is located) must
  have a __short path__ (less than 38 characters), otherwise the packages
  extraction will fail.
- The following must be installed:

  * _GNU make_.
  * _Python 3_, to run the download script.
  * On Linux, a recent version of these packages:

    - _msitools_ (0.98+)
    - _libgcab-1.0-0_ (1.2+)
<br />


Running the Makefile
--------------------

In the Windows command prompt or Linux terminal, change the working directory
to this `download` directory, then run:

	make

This downloads the files and creates the repackaged library in a new
`msvc-libs` subdirectory.

Move it to the final location and set the `MSVC_LIBS_PATH` environment 
variable to it to use it.



Configuration
-------------

You can select the downloaded packages by specifying arguments in the `make`
command line. See the description at the beginning of the Makefile for details,
or run `make help`.

You can also precisely filter which directories you want to include in the
library by editing the `make_msvc-libs_conf.txt` configuration file of the
script that creates it.

If you want to add packages to the download directory, run `make` again with
different arguments. To remove packages, use one of the following commands:

	make clean-msvc # Delete the "VC" directory.
	make clean-sdk  # Delete the "Windows Kits" directory.
	make clean-atl  # Delete the ATL download directory (inside "VC").
	make clean-dl   # Delete all the download directories.

To delete the created library without removing the downloaded files, run:

	make clean

To remove all the directories created by the Makefile, including the download
directory and the created library, run:

	make clean-all



Credits
-------

Thanks to:

_Martin Storsjö_ for the download script (vsdownload.py).
