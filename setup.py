import os
import struct
import numpy as np

from setuptools import setup, find_packages, Extension
from Cython.Build import cythonize

from pyphotron.utils import write_codes
write_codes()  # Write the file with the error codes (required before install)

requirements = [
    'numpy'
]

sdk_root = '.'
lib_dir = os.path.abspath(os.path.normpath(os.path.join(sdk_root, 'Lib\\64bit(x64)')))
include_dir = os.path.abspath(os.path.normpath(os.path.join(sdk_root, 'Include')))

assert os.path.exists(lib_dir), "Library directory '{}' missing".format(lib_dir)
assert os.path.exists(include_dir), "Include directory '{}' missing".format(lib_dir)
assert 8 * struct.calcsize("P") == 64, 'Not running 64 bit python'


photron_camera_extension = Extension(
    name='pyphotron.pyphotron_pdclib',
    sources=['pyphotron/pyphotron_pdclib.pyx'],
    include_dirs=[include_dir, np.get_include()],
    libraries=['PDCLIB'],
    library_dirs=[lib_dir],
    extra_compile_args=['/Gz', '/fp:precise', '/Zc:wchar_t', '/Zc:forScope', '/Zc:inline'],
    extra_link_args=['/DEBUG', '/MACHINE:X64'], #'/VERBOSE'],
)
setup(
    name='pyphotron',
    version='0.0.1',
    description='Python bindings for the Photron PDC library',
    install_requires=requirements,
    packages=find_packages(exclude=('config', 'doc', 'tests*')),
    ext_modules=cythonize( [photron_camera_extension], language_level=3, ),
    requires=['Cython'],
    author='crousseau',
    # zip_safe=False,  # TODO: remove ?
)
