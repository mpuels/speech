nnet3_affix=_chain  # cleanup affix for nnet3 and chain dirs, e.g. _cleaned
tree_dir=exp/nnet3${nnet3_affix}/tree_sp
train_set=train
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires_comb
train_data_dir=data/${train_set}_sp_hires_comb
gmm=tri2b_chain # the gmm for the target data
lat_dir=exp/nnet3${nnet3_affix}/${gmm}_${train_set}_sp_comb_lats

NOW_FMT="+%Y-%m-%d-%H-%M-%S"

log_begin_end() {
    local cmd=$1; shift
    local begin_utc=$1; shift

    local end_utc=$(now_utc)

    echo {\"cmd\": \"${cmd}\", \"begin_utc\": \"${begin_utc}\", \
\"end_utc\": \"${end_utc}\"}
}

now_utc() {
    date -u ${NOW_FMT}
}

get_oov_symbol() {
    local lang=$(basename $(dirname "${PWD}"))

    case "$lang" in
        de) echo "nspc";;
        en) echo "<UNK>";;
        *) echo "Unknown language ${lang}"; exit 1;;
    esac
}
