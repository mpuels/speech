#!/bin/bash

# TODO Extract variable 'data' from this script.

# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=/kaldi-experiments/projects/ai/data/speech/en

# base url for downloads.
data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

# DONE Copy local/download_and_untar.sh to gooofy/speech (symlink).
# DONE Only download_and_untar.sh X if X doesn't exit yet locally.

for part in dev-clean-2 train-clean-5; do
    local_minilibrispeech/download_and_untar.sh $data $data_url $part
done

# DONE Copy local/download_lm.sh to gooofy/speech (symlink).
# TODO Download language model to other directory than data/local/lm
#      and copy it on demand to data/local/lm instead of downloading it
#      after a run of speech_kaldi_export.py.
if [ $stage -le 0 ]; then
    local_minilibrispeech/download_lm.sh $lm_url data/local/lm
fi

# TODO Only execute the following block if it hasn't been executed before.

if [ $stage -le 1 ]; then
    # format the data as Kaldi data directories
    for part in dev-clean-2 train-clean-5; do
        # use underscore-separated names in data directories.
        local_minilibrispeech/data_prep.sh \
            $data/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
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
