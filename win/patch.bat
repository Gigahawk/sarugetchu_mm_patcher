echo Patcher started at %date% %time%

echo Creating blank iso to write to

for %%I in (mm.iso) do .\qemu\qemu-img.exe create -f raw mm_patched.iso %%~zI

echo Booting patcher VM

.\qemu\qemu-system-x86_64.exe ^
    -drive id=drive0,file=ssmm_build_vm.qcow2,format=qcow2,if=none ^
    -device virtio-blk-pci,drive=drive0,bootindex=1 ^
    -drive id=drive1,file=mm.iso,format=raw,if=none ^
    -device virtio-blk-pci,drive=drive1,bootindex=2 ^
    -drive id=drive2,file=sdk.iso,format=raw,if=none ^
    -device virtio-blk-pci,drive=drive2,bootindex=3 ^
    -drive id=drive3,file=mm_patched.iso,format=raw,if=none ^
    -device virtio-blk-pci,drive=drive3,bootindex=4 ^
    -serial stdio ^
    -m 8G ^
    -smp 4

echo Patcher finished at %date% %time%

pause