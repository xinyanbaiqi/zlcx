"""Shared label grammar for the TB-side and log-side scanners."""
import re

# governed label: FAMILY-NN[a][-n] (family may contain digits/dashes), SUPnnX, SUPRST, TCn
GOV = re.compile(r'(?<![A-Za-z0-9_])('
                 r'[A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*-\d{1,3}[A-Za-z]?(?:-\d+)?'
                 r'|SUP\d{2}[A-Z]?|SUPRST|TC\d{1,2}[a-z]?'
                 r')(?![A-Za-z0-9_])')
# tokens of that shape that are not check labels (precision names, signal-ish words)
NOISE_FAM = {'SAR', 'RED-SAR', 'RUN', 'LEDEN', 'IR-SAR', 'Q', 'V', 'P', 'N'}


def family(tok):
    if re.match(r'^SUP(\d|RST$)', tok):
        return 'SUP'
    if re.match(r'^TC\d', tok):
        return 'TC'
    return re.match(r'^(.*?)-\d', tok).group(1)
