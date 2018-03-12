#!/usr/bin/env bash


if [ -f run-chain-cfg.sh ]; then
    . run-chain-cfg.sh
else
    echo "missing run-chain-cfg.sh"
    exit 1
fi

if [ -f cmd.sh ]; then
      . cmd.sh; else
         echo "missing cmd.sh"; exit 1;
fi

# Path also sets LC_ALL=C for Kaldi, otherwise you will experience strange (and hard to debug!) bugs. It should be set here, after the python scripts and not at the beginning of this script
if [ -f path.sh ]; then
    . path.sh
else
    echo "missing path.sh"; exit 1;
fi

stage=0
dir=exp/nnet3${nnet3_affix}/tdnn_sp
nnet3_train_stage=-10
min_seg_len=1.55
xent_regularize=0.1
common_egs_dir=  # you can set this to use previously dumped egs.

. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

mkdir -p $dir

if [ $stage -le 0 ]; then
    echo
    echo run_ivector_common.sh
    echo

    run_ivector_common_begin_utc=$(now_utc)
    local/nnet3/run_ivector_common.sh --stage 0 \
                                      --nj $nJobs \
                                      --min-seg-len $min_seg_len \
                                      --train-set $train_set \
                                      --gmm $gmm \
                                      --num-threads-ubm $num_threads_ubm \
                                      --nnet3-affix "$nnet3_affix" \
        || exit 1
    log_begin_end local/nnet3/run_ivector_common.sh \
                  ${run_ivector_common_begin_utc}
fi

gmm_dir=exp/$gmm
ali_dir=exp/${gmm}_ali_${train_set}_sp_comb
lang=data/lang_chain
lores_train_data_dir=data/${train_set}_sp_comb

for f in $gmm_dir/final.mdl $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $ali_dir/ali.1.gz; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 1 ]; then
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
        gen_topo_begin_utc=$(now_utc)
        steps/nnet3/chain/gen_topo.py $nonsilphonelist \
                                      $silphonelist \
                                      > data/lang_chain/topo \
            || exit 1
        log_begin_end steps/nnet3/chain/gen_topo.py ${gen_topo_begin_utc}
    fi
fi

if [ $stage -le 2 ]; then
    echo
    echo 'Get the alignments as lattices (gives the chain training more freedom).'
    echo

    align_fmllr_lats_begin_utc=$(now_utc)
    steps/align_fmllr_lats.sh --nj $nJobs --cmd "$train_cmd" \
                              ${lores_train_data_dir} \
                              data/lang \
                              $gmm_dir \
                              $lat_dir \
        || exit 1
    log_begin_end steps/align_fmllr_lats.sh ${align_fmllr_lats_begin_utc}
    rm $lat_dir/fsts.*.gz # save space
fi

if [ $stage -le 3 ]; then
    echo
    echo 'Build a tree using our new topology.  We know we have alignments for the'
    echo 'speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use'
    echo 'those.'
    echo

    if [ -f $tree_dir/final.mdl ]; then
        echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
        exit 1;
    fi

    build_tree_begin_utc=$(now_utc)
    steps/nnet3/chain/build_tree.sh \
        --frame-subsampling-factor 3 \
        --context-opts "--context-width=2 --central-position=1" \
        --cmd "$train_cmd" \
        4000 \
        ${lores_train_data_dir} \
        data/lang_chain \
        $ali_dir $tree_dir \
        || exit 1
    log_begin_end steps/nnet3/chain/build_tree.sh ${build_tree_begin_utc}
fi

if [ $stage -le 4 ]; then
    echo
    echo "$0: creating neural net configs using the xconfig parser";
    echo

    num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
    learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)

    mkdir -p $dir/configs
    cat <<EOF > $dir/configs/network.xconfig
input dim=100 name=ivector
input dim=40 name=input

# please note that it is important to have input layer with the name=input
# as the layer immediately preceding the fixed-affine-layer to enable
# the use of short notation for the descriptor
fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

# the first splicing is moved before the lda layer, so no splicing here
relu-batchnorm-layer name=tdnn1 dim=450 self-repair-scale=1.0e-04
relu-batchnorm-layer name=tdnn2 input=Append(-1,0,1) dim=450
relu-batchnorm-layer name=tdnn3 input=Append(-1,0,1,2) dim=450
relu-batchnorm-layer name=tdnn4 input=Append(-3,0,3) dim=450
relu-batchnorm-layer name=tdnn5 input=Append(-3,0,3) dim=450
relu-batchnorm-layer name=tdnn6 input=Append(-6,-3,0) dim=450

## adding the layers for chain branch
relu-batchnorm-layer name=prefinal-chain input=tdnn6 dim=450 target-rms=0.5
output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5

# adding the layers for xent branch
# This block prints the configs for a separate output that will be
# trained with a cross-entropy objective in the 'chain' models... this
# has the effect of regularizing the hidden parts of the model.  we use
# 0.5 / args.xent_regularize as the learning rate factor- the factor of
# 0.5 / args.xent_regularize is suitable as it means the xent
# final-layer learns at a rate independent of the regularization
# constant; and the 0.5 was tuned so as to make the relative progress
# similar in the xent and regular final layers.
relu-batchnorm-layer name=prefinal-xent input=tdnn6 dim=450 target-rms=0.5
output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5

EOF
    steps/nnet3/xconfig_to_configs.py \
        --xconfig-file $dir/configs/network.xconfig \
        --config-dir $dir/configs/ \
        || exit 1

    echo
    echo train.py
    echo

    chain_train_begin_utc=$(now_utc)
    steps/nnet3/chain/train.py \
        --stage $nnet3_train_stage \
        --cmd "$decode_cmd" \
        --feat.online-ivector-dir $train_ivector_dir \
        --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
        --chain.xent-regularize 0.1 \
        --chain.leaky-hmm-coefficient 0.1 \
        --chain.l2-regularize 0.00005 \
        --chain.apply-deriv-weights false \
        --chain.lm-opts="--num-extra-lm-states=2000" \
        --egs.dir "$common_egs_dir" \
        --egs.opts "--frames-overlap-per-eg 0" \
        --egs.chunk-width 150 \
        --trainer.num-chunk-per-minibatch 128 \
        --trainer.frames-per-iter 1500000 \
        --trainer.num-epochs 4 \
        --trainer.optimization.proportional-shrink 20 \
        --trainer.optimization.num-jobs-initial 1 \
        --trainer.optimization.num-jobs-final 1 \
        --trainer.optimization.initial-effective-lrate 0.001 \
        --trainer.optimization.final-effective-lrate 0.0001 \
        --trainer.max-param-change 2.0 \
        --cleanup.remove-egs true \
        --feat-dir $train_data_dir \
        --tree-dir $tree_dir \
        --lat-dir $lat_dir \
        --dir $dir \
        || exit 1
    log_begin_end steps/nnet3/chain/train.py ${chain_train_begin_utc}
fi

if [ $stage -le 5 ]; then
    echo
    echo mkgraph
    echo

    mkgraph_begin_utc=$(now_utc)
    utils/mkgraph.sh --self-loop-scale 1.0 data/lang_test $dir $dir/graph \
        || exit 1
    log_begin_end utils/mkgraph.sh ${mkgraph_begin_utc}
fi

if [ $stage -le 6 ]; then
    echo
    echo decode
    echo

    decode_begin_utc=$(now_utc)
    steps/nnet3/decode.sh \
        --num-threads 1 \
        --nj $nDecodeJobs \
        --cmd "$decode_cmd" \
        --acwt 1.0 \
        --post-decode-acwt 10.0 \
        --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_test_hires \
        --scoring-opts "--min-lmwt 5 " \
        $dir/graph \
        data/test_hires \
        $dir/decode_test \
        || exit 1;
    log_begin_end steps/nnet3/decode.sh ${decode_begin_utc}

    grep WER $dir/decode_test/scoring_kaldi/best_wer >>RESULTS.txt
fi
