from os.path import join

import files as mut

class TestCopyAndFillTemplate:
    def test_it_copies_and_replaces_remplate_strings(self, tmpdir):
        # given
        template_text = """VAR1={{val1}}
        VAR2={{val2}}
        """

        val1 = "v1"
        val2 = "v2"

        expected_text = """VAR1=%s
        VAR2=%s
        """ % (val1, val2)

        src_path = join(str(tmpdir), "src.txt")
        dst_path = join(str(tmpdir), "dst.txt")

        with open(src_path, "wt") as f:
            f.write(template_text)

        # when
        mut.copy_and_fill_template(src_path, dst_path, val1=val1, val2=val2)

        # then
        with open(dst_path) as f:
            actual_text = f.read()

        assert expected_text == actual_text
