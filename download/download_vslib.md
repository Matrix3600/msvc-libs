Download the Visual Studio MSVC/SDK library
===========================================

The original files are downloadable from the Microsoft servers. You
need to accept the [license](
https://go.microsoft.com/fwlink/?LinkId=2179911).

You can use the `vsdownload.py` _Python_ script to download the files.

Before using it, you must check the following are installed:

- _Python 3_.
- On Linux, a recent version of the _msitools_ package.

On Windows, the download directory must have a __short path__ (less than 38
characters), otherwise the packages extraction will fail.

Open a terminal and run:

	# On Linux:
	chmod u+x vsdownload.py
	./vsdownload.py --dest "<download_directory>"

	:: On Windows:
	vsdownload.py --dest "<download_directory>"

where `<download_directory>` is the directory where you want to put the
downloaded files.
