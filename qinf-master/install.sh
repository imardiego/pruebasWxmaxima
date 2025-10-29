!/bin/sh

# This will install files in your home directory in
# Maxima's search path. It would be a good idea to
# store them in a subdirectory

FILES=' qinf.mac qinf.lisp qinf_utils.mac log2.mac  mmacompat.mac '

mkdir ${HOME}/.maxima
echo "cd src && cp -a ${FILES} ${HOME}/.maxima"
cd src && cp -a ${FILES} ${HOME}/.maxima
