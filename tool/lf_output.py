"""Shared UTF-8/LF output policy for generated Dart files.

Generated files are byte-deterministic across Windows, Linux and macOS:
generators write UTF-8 with LF newlines, and the policy is enforced again
after invoking the formatter because `dart format` preserves whatever line
endings the file already carries. Without the post-format pass, a generator
host with CRLF defaults would emit CRLF and byte comparison would depend on
the host rather than on the generator contract.
"""


def write_lf(path, text):
    """Writes text as UTF-8 with LF newlines, never host newline defaults.

    Templates read from a CRLF working tree carry `\r\n` in their content, so
    the text itself is normalized rather than only the write translation.
    """
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def enforce_lf(path):
    """Normalizes an existing file to UTF-8/LF bytes after formatting."""
    with open(path, 'rb') as f:
        data = f.read()
    normalized = data.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
    if normalized != data:
        with open(path, 'wb') as f:
            f.write(normalized)
