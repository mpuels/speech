import speech_transcripts as mut

class TestTranscripts:
    def test_when__exclude_missing_wavs_in_dir__is_set_then_init_excludes_missing_wav_files(self, monkeypatch):
        # given
        wavs_dir = "test_data/16kHz"
        lang = "de"
        TSDIR_MOCK = "test_data/speech/%s"
        monkeypatch.setattr(mut, 'TSDIR', TSDIR_MOCK)

        expected_ts_all = {
            u'spk1-uttid1': {
                'cfn': u'spk1-uttid1',
                'dirfn': u'dirfn1',
                'audiofn': u'audiofn1',
                'prompt': u"prompt1",
                'ts': u"ts1",
                'quality': 2,
                'spk': u"spk1"
            },
            u"spk1-uttid4": {
                'cfn': u'spk1-uttid4',
                'dirfn': u'dirfn4',
                'audiofn': u'audiofn4',
                'prompt': u"prompt4",
                'ts': u"ts4",
                'quality': 2,
                'spk': u"spk1"
            }
        }

        # when
        sut = mut.Transcripts(lang=lang,
                              exclude_missing_wavs_in_dir=wavs_dir)

        # then
        assert sut.ts == expected_ts_all

    def test_when__exclude_missing_wavs_in_dir__is_not_set_then_init_includes_missing_wav_files(self, monkeypatch):
        # given
        lang = "de"
        TSDIR_MOCK = "test_data/speech/%s"
        monkeypatch.setattr(mut, 'TSDIR', TSDIR_MOCK)

        expected_ts_all = {
            u'spk1-uttid1': {
                'cfn': u'spk1-uttid1',
                'dirfn': u'dirfn1',
                'audiofn': u'audiofn1',
                'prompt': u"prompt1",
                'ts': u"ts1",
                'quality': 2,
                'spk': u"spk1"
            },
            u'spk1-uttid2': {
                'cfn': u'spk1-uttid2',
                'dirfn': u'dirfn2',
                'audiofn': u'audiofn2',
                'prompt': u"prompt2",
                'ts': u"ts2",
                'quality': 2,
                'spk': u"spk1"
            },
            u'spk1-uttid3': {
                'cfn': u'spk1-uttid3',
                'dirfn': u'dirfn3',
                'audiofn': u'audiofn3',
                'prompt': u"prompt3",
                'ts': u"ts3",
                'quality': 2,
                'spk': u"spk1"
            },
            u"spk1-uttid4": {
                'cfn': u'spk1-uttid4',
                'dirfn': u'dirfn4',
                'audiofn': u'audiofn4',
                'prompt': u"prompt4",
                'ts': u"ts4",
                'quality': 2,
                'spk': u"spk1"
            }
        }

        # when
        sut = mut.Transcripts(lang=lang)

        # then
        assert sut.ts == expected_ts_all
