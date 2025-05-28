# SSMM 1(ish) Click Patcher for Windows

This is a collection of scripts that boots a full Alpine Linux VM in QEMU which will automatically run the patch tool and then copy the patched ISO out to the host filesystem.

It is incredibly inefficient and resource intensive compared to directly running the patcher, but is a more or less 1 click solution for those too lazy to setup Linux or WSL.

## Prereqs

### Software

- Windows 10
    - Windows 11 probably works but untested
- A `.iso` copy of the Japanese version of Sarugetchu Million Monkeys.
    - It MUST be named `mm.iso`
    - md5: `946d0aeb90772efd9105b0f785b2c7ec`
- A `.iso` copy of the leaked [PS2 SDK (3.0.3)](https://archive.org/download/PlayStation2July2005SDKversion3.0.3/PlayStation%202%20July%202005%20SDK%20%28version%203.0.3%29.iso)
    - It MUST be named `sdk.iso`
    - md5: `c70d267ef19d81ab51e503a76a9882bd`

### Hardware

- At least 16GB of RAM
    - The VM takes up to 8GB of RAM.
- At least 64GB of free space.
    - The VM image may expand up to 96GB, but in practice it should not get larger than 64GB
    - Build times may improve with an SSD

### Personal

- A lot of patience

## Usage

1. Download the all files for the latest patcher package from https://github.com/Gigahawk/sarugetchu_mm_patcher/releases and extract it somewhere
    - GitHub limits release artifacts to about 2Gb in size, so the package is split into a multifile zip
2. Move/copy `mm.iso` and `sdk.iso` into the same folder as `patch.bat`
3. Double click `check_integrity.bat` to check the MD5s of your files match
4. Double click `patch.bat` to start the patcher VM. Once the VM shuts down the patched version will be called `mm_patched.iso`.
    - This will take forever, on my Ryzen 5 5600 (running from a harddrive), this takes over 2 hours.