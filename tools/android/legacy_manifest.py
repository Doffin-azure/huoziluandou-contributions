"""Godot 4.7.2 legacy APK binary XML type repair; no external dependencies."""
import struct

def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def pool_strings(chunk):
    count, _, flags, start, _ = struct.unpack_from("<5I", chunk, 8)
    header = struct.unpack_from("<H", chunk, 2)[0]
    strings = []
    for index in range(count):
        at = start + u32(chunk, header + index * 4)
        if flags & 0x100:
            def length8(pos):
                value = chunk[pos]
                return (((value & 0x7F) << 8) | chunk[pos + 1], pos + 2) if value & 0x80 else (value, pos + 1)
            _, at = length8(at)
            length, at = length8(at)
            strings.append(bytes(chunk[at:at + length]).decode("utf-8"))
        else:
            length = struct.unpack_from("<H", chunk, at)[0]
            at += 2
            if length & 0x8000:
                length = ((length & 0x7FFF) << 16) | struct.unpack_from("<H", chunk, at)[0]
                at += 2
            strings.append(bytes(chunk[at:at + length * 2]).decode("utf-16le"))
    return strings


def repair_manifest(data):
    assert struct.unpack_from("<H", data, 0)[0] == 3
    header_size = struct.unpack_from("<H", data, 2)[0]
    chunks = []
    offset = header_size
    strings = []
    resource_map_index = None
    fixes = []
    while offset < len(data):
        kind, _, size = struct.unpack_from("<HHI", data, offset)
        chunk = bytearray(data[offset:offset + size])
        assert size >= 8 and offset + size <= len(data)
        if kind == 1:
            strings = pool_strings(chunk)
        elif kind == 0x180:
            resource_map_index = len(chunks)
        elif kind == 0x102 and strings[u32(chunk, 20)] == "uses-feature":
            start, stride, count = struct.unpack_from("<3H", chunk, 24)
            attrs = {strings[u32(chunk, 16 + start + i * stride + 4)]: 16 + start + i * stride for i in range(count)}
            name_at = attrs.get("name")
            feature = strings[u32(chunk, name_at + 16)] if name_at is not None else ""
            if feature in ("android.hardware.vulkan.level", "android.hardware.vulkan.version"):
                for attribute, value_type in (("required", 0x12), ("version", 0x10)):
                    at = attrs[attribute]
                    if chunk[at + 15] == 3:
                        text = strings[u32(chunk, at + 16)]
                        value = (0xFFFFFFFF if text == "true" else 0) if attribute == "required" else int(text, 0)
                        struct.pack_into("<I", chunk, at + 8, 0xFFFFFFFF)
                        chunk[at + 15] = value_type
                        struct.pack_into("<I", chunk, at + 16, value)
                        fixes.append(f"{feature}.{attribute}: {text} -> typed {value_type:#x}")
        chunks.append(chunk)
        offset += size
    if not fixes:
        return data, []
    assert len(fixes) == 4, fixes
    assert resource_map_index is not None
    resource_map = chunks[resource_map_index]
    version_index = strings.index("version")
    required_size = 8 + (version_index + 1) * 4
    if len(resource_map) < required_size:
        resource_map.extend(b"\0" * (required_size - len(resource_map)))
    # android.R.attr.version, AOSP core/res/res/values/public-final.xml.
    old_id = u32(resource_map, 8 + version_index * 4)
    assert old_id in (0, 0x01010519)
    struct.pack_into("<I", resource_map, 8 + version_index * 4, 0x01010519)
    struct.pack_into("<I", resource_map, 4, len(resource_map))
    result = bytearray(data[:header_size]) + b"".join(chunks)
    struct.pack_into("<I", result, 4, len(result))
    return result, fixes
