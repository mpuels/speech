
if [ -f run-chain-cfg.sh ]; then
    . run-chain-cfg.sh
else
    echo "missing kaldi-run-chain-cfg.sh"
    exit 1
fi

if [ -f cmd.sh ]; then
      . cmd.sh; else
         echo "missing cmd.sh"; exit 1;
fi

dir=exp/nnet3${nnet3_affix}/tdnn_sp
train_stage=-10
common_egs_dir=  # you can set this to use previously dumped egs.

mkdir -p $dir

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
steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/


echo
echo train.py
echo

chain_train_begin_utc=$(now_utc)
steps/nnet3/chain/train.py --stage $train_stage \
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
  --dir $dir
log_begin_end steps/nnet3/chain/train.py ${chain_train_begin_utc}

echo
echo mkgraph
echo

mkgraph_begin_utc=$(now_utc)
utils/mkgraph.sh --self-loop-scale 1.0 data/lang_test $dir $dir/graph
log_begin_end utils/mkgraph.sh ${mkgraph_begin_utc}

echo
echo decode
echo

decode_begin_utc=$(now_utc)
steps/nnet3/decode.sh --num-threads 1 --nj $nDecodeJobs --cmd "$decode_cmd" \
                      --acwt 1.0 --post-decode-acwt 10.0 \
                      --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_test_hires \
                      --scoring-opts "--min-lmwt 5 " \
                      $dir/graph data/test_hires $dir/decode_test || exit 1;
log_begin_end steps/nnet3/decode.sh ${decode_begin_utc}

grep WER $dir/decode_test/scoring_kaldi/best_wer >>RESULTS.txt
