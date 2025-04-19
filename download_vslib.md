Download the Visual Studio MSVC/SDK library
===========================================

The original files are downloadable from the Microsoft servers. You
need to accept the [license](
https://visualstudio.microsoft.com/en/license-terms/vs2022-ga-community/).

You can use a Python script in the [msvc-wine](
https://github.com/mstorsjo/msvc-wine) github repository to download the files.

Only the file `vsdownload.py` is needed.

Before using it, you must check the following are installed:

- _Python_.
- On Linux, the package _msitools_.
	
Then open a terminal and run:

	# On Linux:
	chmod u+x vsdownload.py
	./vsdownload.py --dest "<download_directory>"
	
	:: On Windows:
	vsdownload.py --dest "<download_directory>"

where `<download_directory>` is the directory where you want to put the
downloaded files.

