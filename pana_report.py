from __future__ import print_function
import sys
import json
import re


def parse_suggestions(data):
    for item in data:
        print('    -', item['description'].replace(
            '\n\n',
            '\n').replace('\n', '\n      '))


def parse_key(data):
    for key, val in data.iteritems():
        if val is False:
            continue
        if val == 0:
            continue
        if key == 'strongModeEnabled' and val is True:
            continue
        label = re.sub(r"([a-z])([A-Z])", r"\g<1> \g<2>", key).capitalize()
        if key == 'suggestions':
            print('  - {key}:'.format(key=label))
            parse_suggestions(val)
            continue
        print('  - {key}: {val}'.format(key=label, val=val))


def main():
    json_data = sys.stdin.read()
    data = json.loads(json_data)

    data['problems'] = data['health']['analyzeProcessFailed'] or data['health'][
        'formatProcessFailed'] or data['health']['resolveProcessFailed']
    data['healthErrors'] = data['health']['analyzerErrorCount']
    data['healthWarnings'] = data['health']['analyzerWarningCount']
    data['healthHint'] = data['health']['analyzerHintCount']
    data['healthConflict'] = data['health']['platformConflictCount']

    print('Package {packageName} version {packageVersion}'.format(**data))
    parse_key(data['health'])
    parse_key(data['maintenance'])

if __name__ == "__main__":
    main()
