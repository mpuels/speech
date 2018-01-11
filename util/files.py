def copy_and_fill_template(template_file, dst_file, **kwargs):
    """Copy template and fill template strings

    File `template_file` is copied to `dst_file`. Then, each template variable
    is replaced by a value. Template variables are of the form

        {{val}}

    Example:

    Contents of template_file:

        VAR1={{val1}}
        VAR2={{val2}}
        VAR3={{val3}}

    copy_and_fill_template(template_file, output_file, val1="hello",
                           val2="world")

    Contents of output_file:

        VAR1=hello
        VAR2=world
        VAR3={{val3}}

    :param template_file: Path to the template file.
    :param dst_file: Path to the destination file.
    :param kwargs: Keys correspond to template variables.
    :return: 
    """
    with open(template_file) as f:
        template_text = f.read()

    dst_text = template_text

    for key, value in kwargs.iteritems():
        dst_text = dst_text .replace("{{" + key + "}}", value)

    with open(dst_file, "wt") as f:
        f.write(dst_text)
