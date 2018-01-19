# Notes on Experiments Conducted with this Reposity

This docoument contains notes on experiments conducted with the scripts
contained in this repository.


## Executed Commands

Script (needs German Parole Corpus) probably computes machine to predict
punctuation for German:

    /kaldi-experiments/speech$ ./speech_sentences_de.py --train-punkt

wrote

    /kaldi-experiments/speech/data/dst/speech/de/punkt.pickle

Script (needs Euro Parl Corpus and `punkt.pickle`)

    /kaldi-experiments/speech$ ./speech_sentences_de.py

wrote

    /kaldi-experiments/speech/data/dst/speech/de/sentences.txt

Script

    /kaldi-experiments/speech$ ./speech_kaldi_export.py

reads

    data/src/speech/de/transcripts_*.csv

and writes the following files to

    /kaldi-experiments/speech/data/dst/speech/de/kaldi

    run-lm.sh
    run-chain.sh
    cmd.sh
    path.sh
    conf/mfcc.conf
    conf/mfcc_hires.conf
    conf/online_cmvn.conf
    local/score.sh
    local/nnet3/run_ivector_common.sh
    data/local/lm/wordlist.txt
    data/local/lm/train_nounk.txt
    data/local/dict/nonsilence_phones.txt
    data/local/dict/silence_phones.txt
    data/local/dict/optional_silence.txt
    data/local/dict/extra_questions.txt
    data/local/dict/lexicon.txt


Script

    /kaldi-experiments/speech/data/dst/speech/de/kaldi$ ./run-lm.sh

wrote

    /kaldi-experiments/speech/data/dst/speech/de/kaldi/data/local/lm/oovs_lm.txt
    /kaldi-experiments/speech/data/dst/speech/de/kaldi/data/lang_test/G.fst

Script

    /kaldi-experiments/speech/data/dst/speech/de/kaldi$ ./speech_pull_voxforge.sh

downloaded German and English VoxForge corpus into

    /kaldi-experiments/projects/ai/data/speech/de/voxforge
    /kaldi-experiments/projects/ai/data/speech/en/voxforge

Script

    /kaldi-experiments/speech/data/dst/speech/de/kaldi$ ./speech_audio_scan.py

example output:

    guenter-20140206-xck_de5-098: converting /kaldi-experiments/projects/ai/data/speech/de/voxforge/audio/guenter-20140206-xck/wav/de5-098.wav => /kaldi-experiments/projects/ai/data/speech/de/16kHz/guenter-20140206-xck_de5-098.wav (16kHz mono)

Next goal: Run

    /kaldi-experiments/speech/data/dst/speech/de/kaldi$ ./run-chain.sh

Yields error message (last message is critical)

    utils/validate_data_dir.sh: Successfully validated data-directory data/train
    steps/make_mfcc.sh: [info]: no segments file exists: assuming wav.scp indexed by utterance.
    run.pl: 6 / 12 failed, log is in exp/make_mfcc_chain/train/make_mfcc_train.*.log

Possible causes:

- There are paths to wav files in `wav.scp` which don't exist on my disk.
  I'll test this hypothesis and cut `wav.scp` to a few files that exist on
  my disk.


I have renamed `transcripts_xx.csv` to `transcripts_xx.csv.org` in
`/kaldi-experiments/speech/data/src/speech/de` and rerun

    /kaldi-experiments/speech$ ./speech_audio_scan.py

This has produced the file

    /kaldi-experiments/speech/data/src/speech/de/transcripts_00.csv`

which should contain only entries corresponding to existing audio files from the
VoxForge corpus.

Rerunning

    /kaldi-experiments/speech$ ./speech_kaldi_export.py

to recompute `wav.scp` yielded an empty `wav.scp` in `train/` and `test/`.
Reason: [Transcript.split()](https://github.com/gooofy/speech/blob/bdc33c1f1054aa81dc123f8e9bfe953391d58526/speech_transcripts.py#L136)
ignores all German VoxForge transcripts because their quality is 0. The quality
isn't zero in the original files `transcripts_00.csv` files contained in the
repo. But `speech_audio_scan.py` sets quality to 0 when regenerating
`transcripts_00.csv` based on the VoxForge corpus.


## Experiments

### Experiment 1: Training with German VoxForge Corpus

- Started at: 2018-01-16 08:01:48 UTC
- Ended at: 2018-01-17 19:10:00 UTC
- Duration: 35h
- AWS Instance Type: p2.xlarge, i.e. 4 CPUs, 1 GPU
- AWS AMI: ami-f0725c95, "AWS Deep Learning"
- Configuration and provisioning scripts: [mpuels/mh-kaldi-on-aws/rc-ec2](https://github.com/mpuels/mh-kaldi-on-aws/tree/a17a6eb57f7cebf6a7ee48d25ee138b1fe876799/rc-ec2)

Steps executed (on AWS EC2 instance):

1. `/kaldi-experiments/speech$ source activate tensforflow_27`
1. `/kaldi-experiments/speech$ ./speech_sentences_de.py --train-punkt`
1. `/kaldi-experiments/speech$ ./speech_sentences_de.py`
1. `/kaldi-experiments/speech$ ./speech_kaldi_export.py --exclude-missing-wavs`
1. `/kaldi-experiments/speech/data/dst/de$ mv kaldi kaldi.alt`
1. `/kaldi-experiments/speech$ ./speech_kaldi_export.py`
1. `/kaldi-experiments/speech/data/dst/de$ cp kaldi.alt/data/test/{text,utt2spk,wav.scp} kaldi/data/test`
1. `/kaldi-experiments/speech/data/dst/de$ cp kaldi.alt/data/train/{text,utt2spk,wav.scp} kaldi/data/train`
1. `/kaldi-experiments/speech/data/dst/de/kaldi$ ./run-lm.sh`
1. `/kaldi-experiments/speech/data/dst/de/kaldi$ screen`
1. `/kaldi-experiments/speech/data/dst/de/kaldi$ ./run-chain-wrapper.sh`

Notes:
1. Regarding steps 2. and 3.: The files created by these steps are
   probably not used Kaldi at all.
2. Regarding steps 4. to 8.: The script `speech_kaldi_export.py`
   copies the source files `text`, `utt2spk`, and `wav.scp` into their
   destination folder. The problem is, that the source files are under
   version control and contain pointers to audio files that don't
   exist on my machine. Because of that the training would fail. My
   workaround was to modify `speech_kaldi_export.py` by adding
   `--exlude-missing-wavs`, so that it would recreate the source files
   based on the audio files that are available. But that alone didn't
   solve the problem, as `run-lm.sh` would then still fail. The
   hacky solution was to call `speech_kaldi_export.py` twice, once
   with and once without `--exclude-missing-wavs`.

[Metrics](https://goo.gl/hgSU9j) for CPU and GPU usage on CloudWatch for machine.

![Graph of GPU and CPU usage](https://s3.us-east-2.amazonaws.com/mh-public/gooofy-speech/experiment-1-cpu-gpu-usage.png)

Word error rates (from `RESULTS.txt`):

    %WER 0.81 [ 109 / 13436, 7 ins, 37 del, 65 sub ] exp/nnet3_chain/tdnn_sp/decode_test/wer_11_1.0
    %WER 0.91 [ 122 / 13436, 7 ins, 43 del, 72 sub ] exp/nnet3_chain/tdnn_250/decode_test/wer_11_0.5


## Possible Pull Requests

While a model is being trained, I can use the time and create pull requests to
improve the code.

- I had to manually install the following packages to be able to install
   `py-nltools`:

  - cython (probably required by `py-kaldi-asr`)
  - swig (probably required by `py-kaldi-asr`)
  - nltk (required by `speech` and mentioned in README.md)
  - setproctitle (required by `py-nltools`)

- [X] Correct dependencies of `py-nltools`

  - See [gooofy-speech-02-install-requirements.sh](https://github.com/mpuels/mh-kaldi-on-aws/blob/163cf6b6a1028fb44e28b9f8446d9db8850cfa43/rc-ec2/provisioning-scripts/gooofy-speech-02-install-requirements.sh#L20) for hints

   - [X] `setproctitle`

- [ ] Correct the dependencies of `py-kaldi-asr`

  - `apt-get install -y libatlas-dev`?

  - See [gooofy-speech-02-install-requirements.sh](https://github.com/mpuels/mh-kaldi-on-aws/blob/163cf6b6a1028fb44e28b9f8446d9db8850cfa43/rc-ec2/provisioning-scripts/gooofy-speech-02-install-requirements.sh#L20) for further hints

- [X] Propose fix for hard coded path in data/src/speech/kaldi-path.sh

  See [57c35efc](https://github.com/mpuels/speech/commit/57c35efc7c27f8b96d3bc67c8de9eb797cd96072)
  for my implemented fix. PR should be created for `py-nltools`.

- [X] PR for `environment.yml`

   Maybe I also should edit `README.md` and explain how to use `environment.yml`.


## To be done later

These tasks can be done later and have low priority right now.


### Download TUDa Corpus from VoxForge

In [`speech_audio_scan.py`](https://github.com/mpuels/speech/blob/7973890b6ce2e3e709ed642c715a2c96f9d9b505/speech_audio_scan.py#L71)
the config parameter `gspv2_dir` is used to search for wav files. According the
[author](https://github.com/gooofy/speech/issues/1#issuecomment-299564621) of
`speech` it corresponds to the
[TUDa Corpus](http://www.repository.voxforge1.org/downloads/de/german-speechdata-package-v2.tar.gz)
(16GB of data).


### Create MFCCs once

The script `data/dst/speech/run-chain.sh` seems to compute MFCCs on each run.
Why isn't it sufficient to compute them once and then do multiple experiments
with them?


## Inbox

This inbox contains things that I have to process and decide what to do with
them.


### kaldi-tuda-de

Contains Kaldi scripts to train an ASR system based on the VoxForge corpus that
has been created by the Technische Universität Darmstadt.
https://github.com/tudarmstadt-lt/kaldi-tuda-de


### In what format expects Kaldi the dictionary for training?

What do the files

- `lexicon.txt`: Contains map from word to list of phonemes.
- `nonsilence_phones.txt`
- `silence_phones.txt`: Hard coded entires: `SIL`, `SPN`, and `NSN`.
- `optional_silence.txt`: Hard coded entry: `SIL`.
- `extra_questions.txt`

contain?


### What does `train-lm.sh` do?
