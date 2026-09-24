import os
import struct
import sys
import tempfile

from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

SECTOR_SIZE = 512
TOTAL_SECTORS = 131072
FS_OFFSET = SECTOR_SIZE
FS_SECTORS = TOTAL_SECTORS - 1
IMAGE_SIZE = TOTAL_SECTORS * SECTOR_SIZE


def make_filesystem(path, efi, kernel):
    with open(path, "wb") as output:
        output.truncate(FS_SECTORS * SECTOR_SIZE)
    fat = PyFat()
    fat.mkfs(
        path,
        PyFat.FAT_TYPE_FAT32,
        size=FS_SECTORS * SECTOR_SIZE,
        sector_size=SECTOR_SIZE,
        label="ASTRALOS",
    )
    fat.close()
    filesystem = PyFatFS(path, preserve_case=False)
    try:
        filesystem.makedir("EFI")
        filesystem.makedir("EFI/BOOT")
        with filesystem.openbin("EFI/BOOT/BOOTX64.EFI", "w") as output:
            output.write(efi)
        with filesystem.openbin("ASTRALOS.KRN", "w") as output:
            output.write(kernel)
    finally:
        filesystem.close()


def make_image(image_path, efi_path, kernel_path):
    efi = open(efi_path, "rb").read()
    kernel = open(kernel_path, "rb").read()

    with tempfile.TemporaryDirectory() as temporary_directory:
        filesystem_path = os.path.join(temporary_directory, "filesystem.fat")
        make_filesystem(filesystem_path, efi, kernel)
        filesystem = open(filesystem_path, "rb").read()

    if len(filesystem) != FS_SECTORS * SECTOR_SIZE:
        raise RuntimeError(f"unexpected FAT filesystem size: {len(filesystem)}")

    image = bytearray(IMAGE_SIZE)
    mbr = bytearray(SECTOR_SIZE)
    mbr[446:462] = struct.pack(
        "<B3sB3sII",
        0x80,
        b"\x01\x01\x00",
        0xEF,
        b"\xfe\xff\xff",
        1,
        FS_SECTORS,
    )
    mbr[510:512] = b"\x55\xaa"
    image[:SECTOR_SIZE] = mbr
    image[FS_OFFSET:] = filesystem

    with open(image_path, "wb") as output:
        output.write(image)

    print(f"created {image_path} ({IMAGE_SIZE} bytes, EFI {len(efi)} bytes, kernel {len(kernel)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: make_uefi_image.py IMAGE BOOTX64.EFI KERNEL")
    make_image(*sys.argv[1:])
