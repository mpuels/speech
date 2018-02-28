#!/bin/bash

#
# Copyright 2016, 2017 Guenter Bartsch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# adapted from kaldi's egs/tedlium/s5_r2/local/chain/run_tdnn.sh

mfccdir=mfcc_chain

stage=0
min_seg_len=1.55
num_threads_ubm=12

xent_regularize=0.1

if [ -f kaldi-run-chain-cfg.sh ]; then
    . kaldi-run-chain-cfg.sh
else
    echo "missing kaldi-run-chain-cfg.sh"
    exit 1
fi

# pre-flight checks

if [ -f cmd.sh ]; then
      . cmd.sh; else
         echo "missing cmd.sh"; exit 1;
fi

# Path also sets LC_ALL=C for Kaldi, otherwise you will experience strange (and hard to debug!) bugs. It should be set here, after the python scripts and not at the beginning of this script
if [ -f path.sh ]; then
      . path.sh; else
         echo "missing path.sh"; exit 1;

fi

# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call train_tdnn.sh with --gpu false,
# --num-threads 16 and --minibatch-size 128.

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

echo "Runtime configuration is: nJobs $nJobs, nDecodeJobs $nDecodeJobs. If this is not what you want, edit cmd.sh"

# now start preprocessing with KALDI scripts

# remove old lang dir if it exists
rm -rf data/lang

# Prepare phoneme data for Kaldi
# utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
utils/prepare_lang.sh data/local/dict "nspc" data/local/lang data/lang

#
# make mfcc
#

for datadir in train test; do
    utils/fix_data_dir.sh data/$datadir 
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nJobs data/$datadir exp/make_mfcc_chain/$datadir $mfccdir || exit 1;
    utils/fix_data_dir.sh data/${datadir} # some files fail to get mfcc for many reasons
    steps/compute_cmvn_stats.sh data/${datadir} exp/make_mfcc_chain/$datadir $mfccdir || exit 1;
    utils/fix_data_dir.sh data/${datadir} # some files fail to get mfcc for many reasons
done

echo
echo mono0a_chain
echo

steps/train_mono.sh --nj $nJobs --cmd "$train_cmd" \
  data/train data/lang exp/mono0a_chain || exit 1;

echo
echo tri1_chain
echo

steps/align_si.sh --nj $nJobs --cmd "$train_cmd" \
  data/train data/lang exp/mono0a_chain exp/mono0a_ali_chain || exit 1;

steps/train_deltas.sh --cmd "$train_cmd" 2000 10000 \
  data/train data/lang exp/mono0a_ali_chain exp/tri1_chain || exit 1;

echo
echo tri2b_chain
echo

steps/align_si.sh --nj $nJobs --cmd "$train_cmd" \
  data/train data/lang exp/tri1_chain exp/tri1_ali_chain || exit 1;

steps/train_lda_mllt.sh --cmd "$train_cmd" \
  --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
  data/train data/lang exp/tri1_ali_chain exp/tri2b_chain || exit 1;

utils/mkgraph.sh data/lang_test \
  exp/tri2b_chain exp/tri2b_chain/graph || exit 1;

echo
echo run_ivector_common.sh
echo

local/nnet3/run_ivector_common.sh --stage $stage \
                                  --nj $nJobs \
                                  --min-seg-len $min_seg_len \
                                  --train-set $train_set \
                                  --gmm $gmm \
                                  --num-threads-ubm $num_threads_ubm \
                                  --nnet3-affix "$nnet3_affix"


gmm_dir=exp/$gmm
ali_dir=exp/${gmm}_ali_${train_set}_sp_comb
lang=data/lang_chain

lores_train_data_dir=data/${train_set}_sp_comb

for f in $gmm_dir/final.mdl $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $ali_dir/ali.1.gz; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

echo
echo creating lang directory with one state per phone.
echo

if [ -d data/lang_chain ]; then
  if [ data/lang_chain/L.fst -nt data/lang/L.fst ]; then
    echo "$0: data/lang_chain already exists, not overwriting it; continuing"
  else
    echo "$0: data/lang_chain already exists and seems to be older than data/lang..."
    echo " ... not sure what to do.  Exiting."
    exit 1;
  fi
else
  cp -r data/lang data/lang_chain
  silphonelist=$(cat data/lang_chain/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat data/lang_chain/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >data/lang_chain/topo
fi

echo
echo 'Get the alignments as lattices (gives the chain training more freedom).'
echo

steps/align_fmllr_lats.sh --nj $nJobs --cmd "$train_cmd" ${lores_train_data_dir} \
    data/lang $gmm_dir $lat_dir
rm $lat_dir/fsts.*.gz # save space

echo
echo 'Build a tree using our new topology.  We know we have alignments for the'
echo 'speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use'
echo 'those.'
echo

if [ -f $tree_dir/final.mdl ]; then
  echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
  exit 1;
fi
steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" 4000 ${lores_train_data_dir} data/lang_chain $ali_dir $tree_dir
