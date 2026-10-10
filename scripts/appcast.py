"""Merge a stable own-fork release into an authenticated appcast's XML payload."""
import base64
import re
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)
MAX_FEED_BYTES = 4_000_000


def version_tuple(value):
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', value):
        raise ValueError('Use a stable canonical semantic release version.')
    return tuple(map(int, value.split('.')))


def validate_enclosure(enclosure):
    version = enclosure.get(f'{{{SPARKLE}}}shortVersionString', '')
    version_tuple(version)
    build = enclosure.get(f'{{{SPARKLE}}}version', '')
    length = enclosure.get('length', '')
    if not re.fullmatch(r'[1-9][0-9]*', build) or not re.fullmatch(r'[1-9][0-9]*', length):
        raise ValueError('Appcast build and archive length must be positive integers.')
    if enclosure.get('url') != f'https://github.com/mpwg/Latest/releases/download/v{version}/Latest.zip':
        raise ValueError('Appcast archive URL must match this fork and release version.')
    if enclosure.get('type') != 'application/octet-stream':
        raise ValueError('Unexpected appcast archive type.')
    try:
        signature = base64.b64decode(enclosure.get(f'{{{SPARKLE}}}edSignature', ''), validate=True)
    except ValueError as error:
        raise ValueError('Invalid appcast archive signature encoding.') from error
    if len(signature) != 64:
        raise ValueError('Appcast archive signature must contain 64 bytes.')
    return version, int(build)


def merge_feed(existing, *, version, build, length, signature):
    """Return unsigned XML. The caller authenticates input and signs all output."""
    version_tuple(version)
    if existing is None:
        rss = ET.Element('rss', version='2.0')
        channel = ET.SubElement(rss, 'channel')
        ET.SubElement(channel, 'title').text = 'Latest — mpwg fork'
        ET.SubElement(channel, 'link').text = 'https://github.com/mpwg/Latest'
    else:
        if not existing or len(existing) > MAX_FEED_BYTES or b'<!DOCTYPE' in existing.upper() or b'<!ENTITY' in existing.upper():
            raise ValueError('Existing appcast is empty, oversized or contains XML declarations that are not supported.')
        try:
            text = existing.decode('utf-8')
            if '\x00' in text:
                raise ValueError('Existing appcast must use UTF-8 XML.')
            rss = ET.fromstring(text)
        except (ET.ParseError, UnicodeDecodeError) as error:
            raise ValueError('Existing appcast is malformed XML.') from error
        if rss.tag != 'rss' or rss.get('version') != '2.0' or len(rss.findall('channel')) != 1:
            raise ValueError('Existing appcast must have exactly one RSS 2.0 channel.')
        channel = rss.find('channel')
        if channel.findtext('link') != 'https://github.com/mpwg/Latest':
            raise ValueError('Existing appcast does not belong to this fork.')

    enclosure = ET.Element('enclosure', {
        'url': f'https://github.com/mpwg/Latest/releases/download/v{version}/Latest.zip',
        'length': str(length), 'type': 'application/octet-stream',
        f'{{{SPARKLE}}}version': str(build), f'{{{SPARKLE}}}shortVersionString': version,
        f'{{{SPARKLE}}}edSignature': signature,
    })
    _, new_build = validate_enclosure(enclosure)
    seen_versions, seen_builds = set(), set()
    previous_releases = []
    items = channel.findall('item')
    for item in items:
        enclosures = item.findall('enclosure')
        if len(enclosures) != 1:
            raise ValueError('Each historical release must have exactly one enclosure.')
        old_version, old_build = validate_enclosure(enclosures[0])
        if old_version in seen_versions or old_build in seen_builds:
            raise ValueError('Existing appcast contains duplicate versions or builds.')
        if old_version == version or old_build == new_build:
            raise ValueError('Release version or build already exists; published entries cannot be replaced.')
        if version_tuple(old_version) >= version_tuple(version) or old_build >= new_build:
            raise ValueError('New release version and build must advance every historical entry.')
        seen_versions.add(old_version)
        seen_builds.add(old_build)
        previous_releases.append((old_build, version_tuple(old_version)))

    ordered = [entry[1] for entry in sorted(previous_releases)]
    if ordered != sorted(ordered):
        raise ValueError('Historical build and release version ordering is inconsistent.')

    item = ET.Element('item')
    ET.SubElement(item, 'title').text = 'Latest ' + version
    ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = '27.0'
    item.append(enclosure)
    # Preserve complete historical items, including notes and optional metadata.
    for old in items:
        channel.remove(old)
    channel.append(item)
    for old in sorted(items, key=lambda entry: int(entry.find('enclosure').get(f'{{{SPARKLE}}}version')), reverse=True):
        channel.append(old)
    result = ET.tostring(rss, encoding='utf-8', xml_declaration=True) + b'\n'
    if len(result) > MAX_FEED_BYTES:
        raise ValueError('Resulting appcast exceeds the feed size limit.')
    return result
