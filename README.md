# PyPhotron
This section is part of a larger project, aimed at automating Photron Fastcam high-speed cameras.

While Photron provides source code for camera interaction, I lacked proficiency in C. 
After reaching out to their support team, they recommended using an [open-source Python wrapper](https://gitlab.com/icm-institute/renier/pyphotron) for their SDK.
Special thanks to PyPhotron and the Photron support team for their assistance.

SDK's dlls are compatible with **windows**.


Installation
============

  - Create a suitable environment (python >=3.10 with at least the **cython package**)
  - Clone the repository
  - cd to the repository folder
  - run 

		python setup.py install

Please add you python interpretor to the firewall and define a rule to allowing acess to High speec camera ports.

Running
=======
Changes must be applied to pyphotron\pyphotron_pdclib.pyx file and previos package must be uninstalled, compiled and then installed.

    C:/Users/[your username]/anaconda3/python.exe -m pip uninstall pyphotron -y

    C:/Users/[your username]/anaconda3/python.exe .\setup.py install

    C:/Users/[your username]/anaconda3/python.exe .\test.py

To get started, you can try the test function

	>>> from pyphotron.pyphotron_pdclib import test
	>>> test()

You can see how the function is implemented to see how to use the library
