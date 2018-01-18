# Overview of Scripts

- [12review.sh](#12review.sh)

This document contains a short desription of each script contained in this
directory.

## `12review.sh`

Calls `auto_review.py` 12 times and writes each output into a separate file in
`tmp/`.

## `apply_review.py`

Description contained in file:

    apply review-result.csv file to transcripts

Inputs:

- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `cmd_args_csv`: files given as arguments to script. Files have 2 fields:
  `utt_id;quality`

Outputs:

- Updated transcripts: `data/src/speech/de/transcripts_*.csv`

What it does:

- Corresponding elements in `transcripts_*.csv` and `csv` files are matched
  with utterance id

- Update quality in `trancsripts_*.csv` according to list of `csv` files on
  command line

- Tokenize prompt and put it into `ts` field of `transcripts_*.csv`


## `auto_review.py`

Description contained in file:

    use kaldi to decode so far not reviewed submissions, auto-accept those
    that decode to their prompt correctly

Inputs:

- `wav16_dir` from `.speechrc`
- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `kaldi_model = KaldiNNet3OnlineModel('data/models/kaldi-chain-voxforge-de-latest', 'tdnn_sp')`

Outputs:

- `outfn = 'review-results.csv'`


## `noisy_gen.py`

Decscription contained in file:

    create new set of recordings from existing ones by adding
    noise and echo effects
    
    these additional, artifically created recordings should help with
    noise resistance when used in training

Inputs:

- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `wav16_dir` from `.speechrc`
- `noise_dir` from `.speechrc`

Outputs:

- `OUT_DIR = 'tmp/noisy_%s' % LANG # FIXME`
- `transcripts`: Entries for new utterance with added noise

What is does:

The script adds background and foreground noise to certain utterances.


## `speech_audio_scan.py`

Description contained in file:

    scan voxforge and kitchen dirs for new audio data and transcripts
    convert to 16kHz wav, add transcripts entries

Inputs:

- `scan_dirs = [config.get("speech", "vf_audiodir_de"), ...]`: Hard coded in
   source code. List of directories containing audio files and corresponding
   transcriptions.
- `wav16_dir` from `.speechrc`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`

Outputs:

- `trascripts`: Script adds entries for new utterances found in directory
   `scan_dirs`.
- `wav16_dir`: Script converts each audio file found in `scan_dirs` and writes
  output to `wav16_dir`.


## `speech_build_lm.py`

Description contained in file:

    train LM using srilm

Inputs:

- `srilm_root = config.get("speech", "srilm_root")`
- `work_dir = 'data/dst/speech/de/srilm'`
- `SOURCES = ['data/dst/speech/%s/sentences.txt', ...`: Hard coded in source
  code. Each txt file contains a list of sentences. Based on this the script
  trains a language model.
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `train_fn = '%s/train_all.txt' % workdir`: The script merges all sentences
  contained in `SOURCES` into `train_fn`.

Outputs:

- `lm_fn = 'data/dst/speech/de/srilm/lm_full.arpa'`: File containing language
  model trained with srilm's `ngram-count`. Training data is in `train_fn`.
- `lm_pruned = 'data/dst/speech/de/srilm/lm.arpa`: File contains pruned language
  model. Srilm's `ngram` creates it based on `lm_fn`.


## `speech_dist.sh`

What it does: Creates distribution of trained ASR system in a tar.gz file.

Inputs:

- Several files from `data/dst/speech/de/kaldi/exp/nnet3_chain/tdnn_sp/`

Outputs:

- `data/dist/de/kaldi-chain-voxforge-de-DATE.tar.gz`: Contains distribution
  of ASR system


## `speech_editor.py`

Description contained in file:

    interactive all-in-one curses application for audio review, transcription
    and lexicon editing

Inputs:

- `SEQUITUR_MODEL = 'data/models/sequitur-voxforge-de-latest'`: Model to
  transform graphemes to phonemes.
- `ts_filters`: List of filters given as command line args to filter by
  utterance id.
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `wav16_dir` from `.speechrc`

Outputs:

- `transcripts`: Modified transcripts are written back to disk.
- `lex`: Modified entries in the lexicon are written back to disk.

What it does:
With the ncurses script a human can manually correct transcripts of utterances
and correct entries in the phoneme dictionary.


## `speech_gender.py`

Description contained in file:

    interactive spk2gender editor

Inputs:

- `SPK2GENDERFN = 'data/src/speech/de/spk2gender'`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `wav16_dir` from `.speechrc`

Outpus:

- `SPK2GENDERFN = 'data/src/speech/de/spk2gender'`

What it does:
Plays back audio files one at a time and human must decide whether recorded
voice is male or female. Only plays back audio files where gender hasn't been
set yet.


## `speech_kaldi_export.py`

Description contained in file:

    export speech training data to create a kaldi case

Inputs:

- `wav16_dir` from `.speechrc`
- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`
- `data/src/speech/de/spk2gender`

Outputs:

- `'data/dst/speech/de/kaldi'`
  - `data/`
     - `{train,test}/`
         - `wav.scp`: Contains map from utterance id to path of audio file.
         - `utt2spk`: Contains map from utterance id to speaker id.
         - `text`: Contains map from utterance id to transcription.
         - `spk2gender`: Contains map from speaker id to gender.
     - `local/`
         - `dict/`
             - `lexicon.txt`: Contains map from word to list of phonemes.
             - `nonsilence_phones.txt`
             - `silence_phones.txt`: Hard coded entires: `SIL`, `SPN`, and `NSN`.
             - `optional_silence.txt`: Hard coded entry: `SIL`.
             - `extra_questions.txt`: Contains three lines: First contains
               silence phones (`SIL`, `SPN`, and `NSN`). Second has phones
               without `'`. Third has phones with `'`.
         - `lm/`
             - `train_nounk.txt`: List of transcribed utterances.
             - `wordlist.txt`: List of all words contained in `transcripts`
  - `run-lm.sh`
  - `run-chain.sh`: Script to train the acoustic model.
  - `run-chain-wrapper.sh`: Wrapper that redirects output of `run-chain.sh`
    to stdout and a log file.
  - `cmd.sh`: Contains configuration on how to start processes (e.g. on a grid).
  - `path.sh`: Contains paths to Kaldi tools.
  - `conf/`
      - `mfcc.conf`: Settings for creating MFCC features. Important: Contains
        the sample rate.
      - `mfcc_hires.conf`: Settings for creating high-resolution MFCC features
        for training of neural networks.
      - `online_cmvn.conf`: Comment in file: 'configuration file for
        apply-cmvn-online, used in the script
        `../local/online/run_online_decoding_nnet2.sh`'.
  - `local/`
      - `score.sh`
      - `nnet3/run_ivector_common.sh`

What it does:
- Optionally creates string of phonemes of missing words using sequitur.


## `speech_lex_edit.py`

Description contained in file:

    interactive curses lexicon editor

Input:

- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `SEQUITUR_MODEL = 'data/models/sequitur-voxforge-de-latest'`: A sequitur
  model map graphemes to phonemes.

Output:

- `lex = Lexicon('data/src/speech/de/dict.ipa')`: Script saves modified
  lexicon to disk.


## `speech_lex_export_espeak.py`

Description contained in file:

    compare lex entries to what eSpeak ng generates and export entries for differing words

Input:

- `lex = Lexicon('data/src/speech/de/dict.ipa')`

Output:

- `de_extra`: File contains words for which entries in `lex` and generated
  phonemes of eSpeak` differ


## `speech_lex_missing.py`

Description contained in file:

    compute top-n missing words in lexicon from submissions,
    optionally generate phoneme transcriptions for those using sequitur

Input:

- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`

Output:

- Script prints words with missing lex entries to stdout.
- Optionally generates phonemes for missing words with sequitur and
  writes them back to `lex` to disk.


## `speech_lex_review.py`

Description contained in file:

    pick 20 lex entries where sequitur disagrees at random

Input:

- `INPUTFILE = 'data/dst/speech/de/sequitur/model-6-all.test'`

Output:

- Guess: Script prints to stdout entries from `INPUTFILE` where the string
  `error` appears.


## `speech_pull_voxforge.sh`

Input:

- `vf_audiodir_en` from `.speechrc`
- `vf_audiodir_de` from `.speechrc`
- http://www.repository.voxforge1.org/downloads/SpeechCorpus/Trunk/Audio/Main/16kHz_16bit/:
  English VoxForge corpus
- http://www.repository.voxforge1.org/downloads/de/Trunk/Audio/Main/16kHz_16bit/:
  German VoxForge corpus

Output:

- `${vf_audiodir_en}/audio-arc/`: Contains *.tgz archives downloaded from the
  English VoxForge corpus
- `${vf_audiodir_en}/audio/`: Contains extracted *.tgz archives.
- `${vf_audiodir_de}/audio-arc/`: Contains *.tgz archives downloaded from the
  German VoxForge corpus
- `${vf_audiodir_de}/audio/`: Contains extracted *.tgz archives.


## `speech_sentences_de.py`

Description contained in file:

    generate training sentences for language models
    
    - train NLTK's punkt sentence segmenter on german parole corpus
    - use it to extract sentences from parole corpus
    - add sentences from europarl

Input:

- `parole` from `.speechrc`: Path to directory containing the Parole Corpus
- `europarl` from `.speechrc`: Path to directory containing the EuroParl Corpus

Output:

- `PUNKT_PICKLEFN = 'data/dst/speech/de/punkt.pickle'`: Pickled and trained
  Punkt model trained on `parole`, if script was told to train a model.
- `SENTENCEFN = 'data/dst/speech/de/sentences.txt'`: List of sentences coming
  from `europarl` and `parole` as predicted by the Punkt model.


## `speech_sentences_en.py`

Description contained in file:

    generate english training sentences for language models from these sources:
    
    - europarl english
    - cornell movie dialogs
    - web questions
    - yahoo answers

Input:

- `europarl` from `.speechrc`
- `movie_dialogs` from `.speechrc`
- `web_questions` from `.speechrc`
- `yahoo_answers` from `.speechrc`

Output:

- `SENTENCEFN = 'data/dst/speech/en/sentences.txt'`: Training sentences for
  language model.


## `speech_sequitur_export.py`

Description contained in file:

    export lexicon for sequitur model training

Input:

- `lex = Lexicon('data/src/speech/de/dict.ipa')`

Output:

- `data/dst/speech/de/sequitur/`
  - `train.lex`
  - `test.lex`
  - `all.lex`

What it does:
It transforms entries from ipa to sampa format.


## `speech_sequitur_train.sh`

Input:

- `data/dst/speech/de/sequitur/train.lex`: File contains map from word to
  list of phonemes.

Output:

- `data/dst/speech/de/sequitur/model-{1,2,3,4,5,6}`: Trained
  grapheme-to-phoneme models. Trained with Sequitur's `g2p.py`.

What it does:

Trains grapheme-to-phoneme models with Sequitur's `g2p.py`.


## `speech_sphinx_export.py`

Description contained in file:

    export speech training data to create a CMU Sphinx training cases

Note: Not interesting for me, as I intend to only use Kaldi.


## `speech_stats.py`

Description contained in file:

    print stats about audio, dictionary and models

Input:

- `wav16_dir` from `.speechrc`
- `lex = Lexicon('data/src/speech/de/dict.ipa')`
- `transcripts = Transcripts('data/src/speech/de/transcripts_*.csv')`

Output:
Script writes the following infos to stdout:

- total duration of all audio files with quality >= 2
- number of good (quality >= 2) submissions per user (one line per user)
- Stats about Sphinx model (not interesting for me)
- Stats about Kaldi model read from `'data/dst/speech/%s/kaldi/RESULTS.txt'`
- Stats about Sequitur model read from
  `'data/dst/speech/%s/sequitur/model-6.test'`

