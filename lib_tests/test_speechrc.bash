. ../lib/speechrc.bash

test_speechrc_read_param() {
    local actual_vf_login=$(speechrc_read_param speechrc vf_login)
    local expected_vf_login=mpuels

    assert_equals $actual_vf_login $expected_vf_login
}
