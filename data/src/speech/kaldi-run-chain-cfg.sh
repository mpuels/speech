nnet3_affix=_chain  # cleanup affix for nnet3 and chain dirs, e.g. _cleaned
tree_dir=exp/nnet3${nnet3_affix}/tree_sp
train_set=train
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_comb
train_data_dir=data/${train_set}_sp_hires_comb
gmm=tri2b_chain # the gmm for the target data
lat_dir=exp/nnet3${nnet3_affix}/${gmm}_${train_set}_sp_comb_lats
