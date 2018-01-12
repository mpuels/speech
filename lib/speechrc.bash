speechrc_read_param() { # speechrc, param -> param_value
    local speechrc=$1
    local param=$2

    grep "${param}" "${speechrc}" | cut -f2 -d=
}
