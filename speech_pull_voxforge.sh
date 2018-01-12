#!/bin/bash

set -e -o pipefail -u

. lib/speechrc.bash

#
# english
#

vf_audiodir_en=$(speechrc_read_param "${HOME}/.speechrc" vf_audiodir_en)
vf_en=$(dirname ${vf_audiodir_en})

echo "Changing to directory ${vf_en}"
cd "${vf_en}"

pushd audio-arc

rm index.*
wget -c -r -nd -l 1 -np http://www.repository.voxforge1.org/downloads/SpeechCorpus/Trunk/Audio/Main/16kHz_16bit/

popd

pushd audio
for i in ../audio-arc/*.tgz ; do

    echo $i

    tar xfz $i

done

popd

#
# german
#

vf_audiodir_de=$(speechrc_read_param "${HOME}/.speechrc" vf_audiodir_de)
vf_de=$(dirname ${vf_audiodir_de})

echo "Changing to directory ${vf_de}"
cd "${vf_de}"

pushd audio-arc

rm index.*
wget -c -r -nd -l 1 -np http://www.repository.voxforge1.org/downloads/de/Trunk/Audio/Main/16kHz_16bit/
# rm openpento*

popd

pushd audio
for i in ../audio-arc/*.tgz ; do

    echo $i

    tar xfz $i

done

popd
