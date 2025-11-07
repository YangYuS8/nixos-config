# This is a placeholder hardware configuration file.
# During NixOS installation, run the following command to generate the actual configuration:
#   nixos-generate-config --root /mnt
# Then copy the generated /mnt/etc/nixos/hardware-configuration.nix to this location.
#
# 这是一个占位符硬件配置文件。
# 在 NixOS 安装过程中，运行以下命令生成实际配置：
#   nixos-generate-config --root /mnt
# 然后将生成的 /mnt/etc/nixos/hardware-configuration.nix 复制到此位置。

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  # 文件系统配置 - 请根据实际分区调整
  # 推荐的 Btrfs 子卷布局：
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE_WITH_YOUR_ROOT_UUID";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd:3" "ssd" "space_cache=v2" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/REPLACE_WITH_YOUR_ROOT_UUID";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "ssd" "space_cache=v2" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/REPLACE_WITH_YOUR_ROOT_UUID";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:1" "noatime" "ssd" "space_cache=v2" ];
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-uuid/REPLACE_WITH_YOUR_ROOT_UUID";
    fsType = "btrfs";
    options = [ "subvol=@var" "compress=zstd:1" "noatime" "ssd" "space_cache=v2" ];
  };

  # EFI 分区
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE_WITH_YOUR_EFI_UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # 不使用交换分区
  swapDevices = [ ];

  # CPU 微码更新
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
