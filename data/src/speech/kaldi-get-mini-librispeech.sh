#!/bin/bash

. ./mini-librispeech-path.sh

# base url for downloads.
data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

for part in dev-clean-2 train-clean-5; do
    local_minilibrispeech/download_and_untar.sh \
        $SPEECH_DATA_ROOT $data_url $part
done

if [ $stage -le 0 ]; then
    libri_lm_dir=../librispeech-lm/data/local/lm
    mkdir -p ${libri_lm_dir}
    local_minilibrispeech/download_lm.sh $lm_url ${libri_lm_dir}
    if ! [ -L data/local/lm ]; then
        ln -s ../../${libri_lm_dir} data/local/lm
    fi
fi

# TODO Only execute the following block if it hasn't been executed before.

if [ $stage -le 1 ]; then
    # format the data as Kaldi data directories
    for part in dev-clean-2 train-clean-5; do
        # use underscore-separated names in data directories.
        local_minilibrispeech/data_prep.sh \
            $SPEECH_DATA_ROOT/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
    done

    local_minilibrispeech/prepare_dict.sh \
        --stage 3 --nj 30 --cmd "$train_cmd" \
        data/local/lm data/local/lm data/local/dict_nosp

    utils/prepare_lang.sh data/local/dict_nosp \
                          "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

    local_minilibrispeech/format_lms.sh --src-dir data/lang_nosp data/local/lm
    # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
    utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
                                 data/lang_nosp data/lang_nosp_test_tglarge
fi
