import os


def get_header_lines(header_name):
    header_path = os.path.normpath(os.path.join('.', 'Include', '{}.h'.format(header_name)))
    with open(header_path, 'r') as errors_file:
        lines = errors_file.readlines()
    return lines


def is_pdc_code(ln, prefix):
    elements = ln.split()
    return elements and elements[0] == '#define' and elements[1].startswith(prefix)


def is_error_code(txt):
    return is_pdc_code(txt, 'PDC_ERROR')


def is_status_code(ln):
    return is_pdc_code(ln, 'PDC_STATUS_')


def errors_to_dict():  # TODO: implement other parameters
    lines = get_header_lines('PDCERROR')
    errors_lines = [ln.split()[1:3] for ln in lines if is_error_code(ln)]
    return {int(v): k for k, v in errors_lines}


def statuses_to_dict():
    lines = get_header_lines('PDCVALUE')
    status_lines = [ln.split()[1:3] for ln in lines if is_status_code(ln)]
    return {int(v, 16): k for k, v in status_lines}


def write_codes():
    codes_module_fp = os.path.normpath('./pyphotron/codes.py')
    with open(codes_module_fp, 'w') as codes_module_file:
        codes_module_file.write('ERROR_CODES = {\n')
        for k, v in errors_to_dict().items():
            codes_module_file.write('    {code}: "{name}",\n'.format(code=k, name=v))
        codes_module_file.write('}\n')

        codes_module_file.write('STATUS_CODES = {\n')
        for k, v in statuses_to_dict().items():
            codes_module_file.write('    {code}: "{name}",\n'.format(code=k, name=v))
        codes_module_file.write('}\n')
