#!/usr/bin/env python2
# -*- coding: utf-8 -*- 

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
#
# export speech training data to create a kaldi case
#

import os
import os.path
import sys
import logging

from optparse import OptionParser

from nltools                import misc
from nltools.tokenizer      import tokenize
from nltools.phonetics      import ipa2xsampa
from nltools.sequiturclient import sequitur_gen_ipa

from speech_lexicon     import Lexicon
from speech_transcripts import Transcripts

from util.files import copy_and_fill_template

WORKDIR = 'data/dst/speech/%s/kaldi'

misc.init_app ('speech_kaldi_export')


def main():
    (options, args) = parse_args()

    if options.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    if options.regression_test and options.lang != "en":
        raise ValueError("The flag --regression-test requires --lang=en.")

    config = load_config(options.config)

    #
    # config
    #

    work_dir = WORKDIR % options.lang
    kaldi_root = config.get("speech", "kaldi_root")

    data_dir = "%s/data" % work_dir
    mfcc_dir = "%s/mfcc" % work_dir

    wav16_dir = config.get("speech", "wav16_dir_%s" % options.lang)

    create_basic_work_dir_structure(data_dir, wav16_dir, mfcc_dir, work_dir,
                                    kaldi_root)

    if options.regression_test:
        augment_work_dir_with_mini_librispeech(kaldi_root, work_dir)
    else:
        generate_speech_and_text_corpora(data_dir,
                                         mfcc_dir,
                                         options.debug,
                                         options.add_all,
                                         options.lang,
                                         options.exclude_missing_wavs)

    copy_scripts_and_config_files(work_dir, kaldi_root)

    if options.regression_test:
        speech_data_root = config.get("speech",
                                      "speech_data_root_%s" % options.lang)

        copy_files_for_regression_test(data_dir, work_dir, speech_data_root)


def parse_args():
    parser = OptionParser("usage: %prog [options] )")
    parser.add_option("-a", "--add-all", action="store_true", dest="add_all",
                      help="use all transcripts, generate missing words using sequitur g2p")
    parser.add_option("-e", "--exclude-missing-wavs", action="store_true",
                      dest="exclude_missing_wavs",
                      help="Exclude wav files which are in transcriptions*.csv "
                           "but are not in wav16_dir.")
    parser.add_option("-d", "--debug", dest="debug", type='int', default=0,
                      help="limit number of transcripts (debug purposes only), default: 0 (unlimited)")
    parser.add_option("-l", "--lang", dest="lang", type="str", default='de',
                      help="language (default: de)")
    parser.add_option("-r", "--regression-test", action="store_true",
                      dest="regression_test",
                      help="Is intended for regression testing of bash scripts. "
                           "If set, then the script get-mini-librispeech.sh and "
                           "its depdencies will be placed into the target "
                           "directory. The script can be used to download a mini "
                           "version of the LibriSpeech corpus from openslr.org. "
                           "The option only works with --lang=en.")
    parser.add_option("-c", "--config", dest="config", type="str",
                      default="~/.speechrc",
                      help="Path to config file. Default: %default")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                      help="enable verbose logging")

    return parser.parse_args()


def load_config(config_path):
    config_path_ = os.path.expanduser(config_path)

    logging.info("Loading config file %s" % config_path_)
    config = misc.configparser.ConfigParser({})
    config.read(config_path_)

    return config


def create_basic_work_dir_structure(data_dir, wav16_dir, mfcc_dir, work_dir,
                                    kaldi_root):
    misc.mkdirs('%s/lexicon' % data_dir)
    misc.mkdirs('%s/local/dict' % data_dir)
    misc.mkdirs(wav16_dir)
    misc.mkdirs(mfcc_dir)
    misc.symlink('%s/egs/wsj/s5/steps' % kaldi_root, '%s/steps' % work_dir)
    misc.symlink('%s/egs/wsj/s5/utils' % kaldi_root, '%s/utils' % work_dir)


def augment_work_dir_with_mini_librispeech(kaldi_root, work_dir):
    misc.symlink('%s/egs/mini_librispeech/s5/local' % kaldi_root,
                 '%s/local_minilibrispeech' % work_dir)
    misc.symlink('train_clean_5', '%s/data/train' % work_dir)
    misc.symlink('dev_clean_2', '%s/data/test' % work_dir)


def generate_speech_and_text_corpora(data_dir,
                                     wav16_dir,
                                     debug,
                                     add_all,
                                     lang,
                                     exclude_missing_wavs):
    """Generates files in data/local/dict and """
    #
    # load lexicon, transcripts
    #
    logging.info("loading lexicon...")
    lex = Lexicon(lang=lang)
    logging.info("loading lexicon...done.")
    logging.info("loading transcripts...")
    if exclude_missing_wavs:
        logging.info("Excluding transcripts of missing wav files.")
        transcripts = Transcripts(lang=lang,
                                  exclude_missing_wavs_in_dir=wav16_dir)
    else:
        logging.info("Including transcripts of missing wav files.")
        transcripts = Transcripts(lang=lang)

    ts_all, ts_train, ts_test = transcripts.split(limit=debug,
                                                  add_all=add_all)

    logging.info("loading transcripts (%d train, %d test) ...done." % (
        len(ts_train), len(ts_test)))

    export_kaldi_data(wav16_dir, lang, '%s/train/' % data_dir, ts_train)
    export_kaldi_data(wav16_dir, lang, '%s/test/' % data_dir, ts_test)

    if add_all:
        # add missing words to dictionary using sequitur.
        lex = add_missing_words(transcripts, lex)
    ps, utt_dict = export_dictionary(ts_all,
                                     lex,
                                     '%s/local/dict/lexicon.txt' % data_dir)
    write_nonsilence_phones(
        ps, '%s/local/dict/nonsilence_phones.txt' % data_dir)

    write_silence_phones('%s/local/dict/silence_phones.txt' % data_dir)
    write_optional_silence('%s/local/dict/optional_silence.txt' % data_dir)
    write_extra_questions(ps, '%s/local/dict/extra_questions.txt' % data_dir)
    create_training_data_for_language_model(transcripts, utt_dict, data_dir)


def export_kaldi_data (wav16_dir, options_lang, destdirfn, tsdict):
    logging.info ( "Exporting to %s..." % destdirfn)

    misc.mkdirs(destdirfn)

    with open(destdirfn+'wav.scp','w') as wavscpf,  \
         open(destdirfn+'utt2spk','w') as utt2spkf, \
         open(destdirfn+'text','w') as textf:

        for utt_id in sorted(tsdict):
            ts = tsdict[utt_id]

            textf.write((u'%s %s\n' % (utt_id, ts['ts'])).encode('utf8'))

            wavscpf.write('%s %s/%s.wav\n' % (utt_id, wav16_dir, utt_id))

            utt2spkf.write('%s %s\n' % (utt_id, ts['spk']))

    misc.copy_file ('data/src/speech/%s/spk2gender' % options_lang,
                    '%s/spk2gender' % destdirfn)


def add_missing_words(transcripts, lex):
    logging.info("looking for missing words...")
    missing = {}  # word -> count
    num = len(transcripts)
    cnt = 0
    for cfn in transcripts:
        ts = transcripts[cfn]

        cnt += 1

        if ts['quality'] > 0:
            continue

        for word in tokenize(ts['prompt']):
            if word in lex:
                continue

            if word in missing:
                missing[word] += 1
            else:
                missing[word] = 1
    cnt = 0
    for item in reversed(sorted(missing.items(), key=lambda x: x[1])):
        lex_base = item[0]

        ipas = sequitur_gen_ipa(lex_base)

        logging.info(u"%5d/%5d Adding missing word : %s [ %s ]" % (
        cnt, len(missing), item[0], ipas))

        lex_entry = {'ipa': ipas}
        lex[lex_base] = lex_entry
        cnt += 1

    return lex


def export_dictionary(ts_all, lex, dictfn2):
    logging.info("Exporting dictionary...")
    utt_dict = {}
    for ts in ts_all:

        tsd = ts_all[ts]

        tokens = tsd['ts'].split(' ')

        # logging.info ( '%s %s' % (repr(ts), repr(tokens)) )

        for token in tokens:
            if token in utt_dict:
                continue

            if not token in lex.dictionary:
                logging.error(
                    "*** ERROR: missing token in dictionary: '%s' (tsd=%s, tokens=%s)" % (
                    token, repr(tsd), repr(tokens)))
                sys.exit(1)

            utt_dict[token] = lex.dictionary[token]['ipa']
    ps = {}
    with open(dictfn2, 'w') as dictf:

        dictf.write('!SIL SIL\n')

        for token in sorted(utt_dict):

            ipa = utt_dict[token]
            xsr = ipa2xsampa(token, ipa, spaces=True)

            xs = (xsr.replace('-', '')
                     .replace('\' ', '\'')
                     .replace('  ', ' ')
                     .replace('#', 'nC'))

            dictf.write((u'%s %s\n' % (token, xs)).encode('utf8'))

            for p in xs.split(' '):

                if len(p) < 1:
                    logging.error(
                        u"****ERROR: empty phoneme in : '%s' ('%s', ipa: '%s')" % (
                        xs, xsr, ipa))

                pws = p[1:] if p[0] == '\'' else p

                if not pws in ps:
                    ps[pws] = {p}
                else:
                    ps[pws].add(p)
    logging.info("%s written." % dictfn2)
    logging.info("Exporting dictionary ... done.")

    return ps, utt_dict


def write_nonsilence_phones(ps, psfn):
    with open(psfn, 'w') as psf:
        for pws in ps:
            for p in sorted(list(ps[pws])):
                psf.write((u'%s ' % p).encode('utf8'))

            psf.write('\n')
    logging.info('%s written.' % psfn)


def write_silence_phones(psfn):
    with open(psfn, 'w') as psf:
        psf.write('SIL\nSPN\nNSN\n')
    logging.info('%s written.' % psfn)


def write_optional_silence(psfn):
    with open(psfn, 'w') as psf:
        psf.write('SIL\n')
    logging.info('%s written.' % psfn)


def write_extra_questions(ps, psfn):
    with open(psfn, 'w') as psf:
        psf.write('SIL SPN NSN\n')

        for pws in ps:
            for p in ps[pws]:
                if '\'' in p:
                    continue
                psf.write((u'%s ' % p).encode('utf8'))
        psf.write('\n')

        for pws in ps:
            for p in ps[pws]:
                if not '\'' in p:
                    continue
                psf.write((u'%s ' % p).encode('utf8'))

        psf.write('\n')
    logging.info('%s written.' % psfn)


def create_training_data_for_language_model(transcripts, utt_dict, data_dir):
    misc.mkdirs('%s/local/lm' % data_dir)
    fn = '%s/local/lm/train_nounk.txt' % data_dir
    with open(fn, 'w') as f:

        for utt_id in sorted(transcripts):
            ts = transcripts[utt_id]
            f.write((u'%s\n' % ts['ts']).encode('utf8'))
    logging.info("%s written." % fn)
    fn = '%s/local/lm/wordlist.txt' % data_dir
    with open(fn, 'w') as f:

        for token in sorted(utt_dict):
            f.write((u'%s\n' % token).encode('utf8'))
    logging.info("%s written." % fn)


def copy_scripts_and_config_files(work_dir, kaldi_root):
    misc.copy_file('data/src/speech/kaldi-run-lm.sh', '%s/run-lm.sh' % work_dir)
    # misc.copy_file ('data/src/speech/kaldi-run-am.sh', '%s/run-am.sh' % work_dir)
    # misc.copy_file ('data/src/speech/kaldi-run-nnet3.sh', '%s/run-nnet3.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain.sh',
                   '%s/run-chain.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-wrapper.sh',
                   '%s/run-chain-wrapper.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-cfg.sh',
                   '%s/run-chain-cfg.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-cpu.sh',
                   '%s/run-chain-cpu.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-cpu-wrapper.sh',
                   '%s/run-chain-cpu-wrapper.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-gpu.sh',
                   '%s/run-chain-gpu.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-chain-gpu-wrapper.sh',
                   '%s/run-chain-gpu-wrapper.sh' % work_dir)
    misc.copy_file('data/src/speech/kaldi-cmd.sh', '%s/cmd.sh' % work_dir)
    # misc.copy_file ('data/src/speech/kaldi-path.sh', '%s/path.sh' % work_dir)
    copy_and_fill_template('data/src/speech/kaldi-path.sh.template',
                           '%s/path.sh' % work_dir, kaldi_root=kaldi_root)
    misc.mkdirs('%s/conf' % work_dir)
    misc.copy_file('data/src/speech/kaldi-mfcc.conf',
                   '%s/conf/mfcc.conf' % work_dir)
    misc.copy_file('data/src/speech/kaldi-mfcc-hires.conf',
                   '%s/conf/mfcc_hires.conf' % work_dir)
    misc.copy_file('data/src/speech/kaldi-online-cmvn.conf',
                   '%s/conf/online_cmvn.conf' % work_dir)
    misc.mkdirs('%s/local' % work_dir)
    misc.copy_file('data/src/speech/kaldi-score.sh',
                   '%s/local/score.sh' % work_dir)
    misc.mkdirs('%s/local/nnet3' % work_dir)
    misc.copy_file('data/src/speech/kaldi-run-ivector-common.sh',
                   '%s/local/nnet3/run_ivector_common.sh' % work_dir)


def copy_files_for_regression_test(data_dir, work_dir, speech_data_root_en):
    copy_and_fill_template(
        'data/src/speech/kaldi-mini-librispeech-path.sh.template',
        '%s/mini-librispeech-path.sh' % work_dir,
        speech_data_root_en=speech_data_root_en)

    misc.copy_file('data/src/speech/kaldi-get-mini-librispeech.sh',
                   '%s/get-mini-librispeech.sh' % work_dir)

    path_local_dict = '%s/local/dict' % data_dir
    if not os.path.exists(path_local_dict):
        misc.symlink('dict_nosp', path_local_dict)
    if os.path.islink(path_local_dict):
        pass
    elif os.path.isdir(path_local_dict):
        os.rmdir(path_local_dict)
        misc.symlink('dict_nosp', path_local_dict)

    path_data_lang_test = '%s/lang_test' % data_dir
    if not os.path.exists(path_data_lang_test):
        misc.symlink('lang_nosp_test_tgsmall', path_data_lang_test)


if __name__ == "__main__":
    main()
    logging.info ( "All done." )

