import math
import os
import struct
import sys

SECTOR_SIZE = 512
TOTAL_SECTORS = 2880
RESERVED_SECTORS = 1
FAT_COUNT = 2
SECTORS_PER_FAT = 9
ROOT_ENTRIES = 224
ROOT_SECTORS = 14
DATA_START = RESERVED_SECTORS + FAT_COUNT * SECTORS_PER_FAT + ROOT_SECTORS
CLUSTER_SIZE = SECTOR_SIZE


def short_name(name, extension=""):
    return name.ljust(8)[:8].encode("ascii") + extension.ljust(3)[:3].encode("ascii")


def directory_entry(name, extension, attributes, cluster, size):
    entry = bytearray(32)
    entry[0:11] = short_name(name, extension)
    entry[11] = attributes
    entry[26:28] = struct.pack("<H", cluster)
    entry[28:32] = struct.pack("<I", size)
    return entry


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: make_uefi_image.py IMAGE BOOTX64.EFI KERNEL")

    image_path, efi_path, kernel_path = sys.argv[1:]
    efi = open(efi_path, "rb").read()
    kernel = open(kernel_path, "rb").read()
    image = bytearray(TOTAL_SECTORS * SECTOR_SIZE)

    boot = bytearray(SECTOR_SIZE)
    boot[0:3] = b"\xeb\x3c\x90"
    boot[3:11] = b"ASTRALOS "
    struct.pack_into("<H", boot, 11, SECTOR_SIZE)
    boot[13] = 1
    struct.pack_into("<H", boot, 14, RESERVED_SECTORS)
    boot[16] = FAT_COUNT
    struct.pack_into("<H", boot, 17, ROOT_ENTRIES)
    struct.pack_into("<H", boot, 19, TOTAL_SECTORS)
    boot[21] = 0xF0
    struct.pack_into("<H", boot, 22, SECTORS_PER_FAT)
    struct.pack_into("<H", boot, 24, 18)
    struct.pack_into("<H", boot, 26, 2)
    boot[36] = 0
    boot[38] = 0x29
    struct.pack_into("<I", boot, 39, 0x20260924)
    boot[43:54] = b"ASTRALOS   "
    boot[54:62] = b"FAT12   "
    boot[510:512] = b"\x55\xaa"
    image[0:SECTOR_SIZE] = boot

    fat = bytearray(SECTORS_PER_FAT * SECTOR_SIZE)
    fat[0:3] = b"\xf0\xff\xff"
    next_cluster = 2
    chains = {}

    def allocate(data):
        nonlocal next_cluster
        count = max(1, math.ceil(len(data) / CLUSTER_SIZE))
        first = next_cluster
        clusters = list(range(first, first + count))
        next_cluster += count
        chains[first] = (clusters, data)
        return first

    efi_cluster = allocate(efi)
    kernel_cluster = allocate(kernel)
    efi_dir_cluster = 2
    boot_dir_cluster = 3
    # The allocator starts after the fixed directory clusters.
    next_cluster = max(next_cluster, 4)
    # Rebuild file allocation if a file was assigned a directory cluster.
    if efi_cluster < 4 or kernel_cluster < 4:
        chains.clear()
        next_cluster = 4
        efi_cluster = allocate(efi)
        kernel_cluster = allocate(kernel)

    efi_dir = bytearray(CLUSTER_SIZE)
    efi_dir[0:32] = directory_entry(".", "", 0x10, efi_dir_cluster, 0)
    efi_dir[32:64] = directory_entry("..", "", 0x10, 0, 0)
    efi_dir[64:96] = directory_entry("BOOT", "", 0x10, boot_dir_cluster, 0)

    boot_dir = bytearray(CLUSTER_SIZE)
    boot_dir[0:32] = directory_entry(".", "", 0x10, boot_dir_cluster, 0)
    boot_dir[32:64] = directory_entry("..", "", 0x10, efi_dir_cluster, 0)
    boot_dir[64:96] = directory_entry("BOOTX64", "EFI", 0x20, efi_cluster, len(efi))

    root = bytearray(ROOT_SECTORS * SECTOR_SIZE)
    root[0:32] = directory_entry("EFI", "", 0x10, efi_dir_cluster, 0)
    root[32:64] = directory_entry("ASTRALOS", "KRN", 0x20, kernel_cluster, len(kernel))

    for cluster, data in ((efi_dir_cluster, efi_dir), (boot_dir_cluster, boot_dir)):
        chains[cluster] = ([cluster], data)

    def set_fat(cluster, value):
        offset = cluster + cluster // 2
        if cluster & 1:
            fat[offset] = (fat[offset] & 0x0F) | ((value << 4) & 0xF0)
            fat[offset + 1] = (value >> 4) & 0xFF
        else:
            fat[offset] = value & 0xFF
            fat[offset + 1] = (fat[offset + 1] & 0xF0) | ((value >> 8) & 0x0F)

    for clusters, data in chains.values():
        for index, cluster in enumerate(clusters):
            set_fat(cluster, clusters[index + 1] if index + 1 < len(clusters) else 0xFFF)
            start = (DATA_START + cluster - 2) * SECTOR_SIZE
            chunk = data[index * CLUSTER_SIZE:(index + 1) * CLUSTER_SIZE]
            image[start:start + len(chunk)] = chunk

    fat_start = RESERVED_SECTORS * SECTOR_SIZE
    for copy_index in range(FAT_COUNT):
        start = fat_start + copy_index * len(fat)
        image[start:start + len(fat)] = fat
    root_start = (RESERVED_SECTORS + FAT_COUNT * SECTORS_PER_FAT) * SECTOR_SIZE
    image[root_start:root_start + len(root)] = root

    with open(image_path, "wb") as output:
        output.write(image)

    print(f"created {image_path} ({len(image)} bytes, EFI {len(efi)} bytes, kernel {len(kernel)} bytes)")


if __name__ == "__main__":
    main()
