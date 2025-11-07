# NixOS flake for laptop (Ryzen 5 6600H / Radeon 680M)

高性能笔记本电脑的 NixOS 配置，针对 AMD Ryzen 6000 系列优化。

## 🎯 特性

### 硬件优化
- **AMD Ryzen 5 6600H**: amd-pstate 驱动 + TLP 电源管理
- **Radeon 680M**: Mesa RADV 驱动 + VA-API 硬件加速
- **Early KMS**: 启动阶段提前加载 amdgpu 驱动
- **无交换分区**: 优化的内存管理策略

### 系统组件
- **文件系统**: Btrfs + zstd 压缩 + 子卷布局 (@, @home, @nix, @var)
- **窗口管理**: Niri (Wayland compositor) + Noctalia Shell
- **显示管理**: GDM + Wayland
- **输入法**: fcitx5 + Rime + 中文 addons
- **音频**: PipeWire + WirePlumber
- **Shell**: Zsh + Oh My Zsh

## 📦 安装步骤

### 1. 准备安装介质
从 NixOS 官网下载最新的 Live ISO 并启动。

### 2. 磁盘分区（示例）
```bash
# 假设目标磁盘为 /dev/nvme0n1
# EFI 分区
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary btrfs 512MiB 100%

# 格式化
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
mkfs.btrfs -L nixos-root /dev/nvme0n1p2
```

### 3. 创建 Btrfs 子卷
```bash
# 挂载根卷
mount /dev/disk/by-label/nixos-root /mnt

# 创建子卷（使用 @ 前缀符合 Btrfs 约定）
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@var

# 卸载
umount /mnt

# 重新挂载子卷
mount -o subvol=@,compress=zstd:3,ssd,space_cache=v2 /dev/disk/by-label/nixos-root /mnt
mkdir -p /mnt/{home,nix,var,boot}
mount -o subvol=@home,compress=zstd:3,ssd,space_cache=v2 /dev/disk/by-label/nixos-root /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime,ssd,space_cache=v2 /dev/disk/by-label/nixos-root /mnt/nix
mount -o subvol=@var,compress=zstd:1,noatime,ssd,space_cache=v2 /dev/disk/by-label/nixos-root /mnt/var
mount /dev/disk/by-label/BOOT /mnt/boot
```

### 4. 生成硬件配置
```bash
# 生成硬件配置文件
nixos-generate-config --root /mnt

# 复制生成的 hardware-configuration.nix 到本仓库
# 或者直接在仓库中更新 hardware-configuration.nix 的 UUID
```

### 5. 克隆此仓库并安装
```bash
# 进入 /mnt 并克隆配置
cd /mnt/home
git clone https://github.com/YangYuS8/nixos-config.git

# 复制生成的硬件配置（重要！）
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/nixos-config/

# 安装 NixOS
sudo nixos-install --flake /mnt/home/nixos-config#laptop

# 设置 root 密码
sudo nixos-install --root /mnt --no-root-passwd

# 重启
reboot
```

### 6. 首次启动后
```bash
# 修改用户密码
passwd

# 更新系统
sudo nixos-rebuild switch --flake /home/yangyus8/nixos-config#laptop

# 配置 fcitx5（添加 Rime 输入法）
fcitx5-configtool
```

## ⚙️ 配置说明

### 重要文件
- `flake.nix`: 主配置文件，包含系统设置、软件包、服务等
- `hardware-configuration.nix`: 硬件专属配置（由 nixos-generate-config 生成）
- `flake.lock`: 锁定依赖版本（自动生成）

### 自定义配置
在安装前，请修改 `flake.nix` 中的：
- `networking.hostName`: 主机名
- `users.users.yangyus8`: 用户名和配置
- `time.timeZone`: 时区
- `initialPassword`: **必须修改或删除！**

## 🔧 日常维护

### 更新系统
```bash
# 更新 flake 输入（nixpkgs、nixos-hardware 等）
nix flake update

# 重建系统
sudo nixos-rebuild switch --flake .#laptop
```

### 清理旧代

```bash
# 删除旧代系统配置
sudo nix-collect-garbage -d

# Btrfs 磁盘清理
sudo btrfs filesystem defragment -r /
```

## 🚨 重要提示

1. **不要提交密码到仓库**: 删除 `initialPassword` 字段或使用 SSH 密钥
2. **备份 hardware-configuration.nix**: 这个文件包含你的磁盘 UUID，丢失后需要手动编辑
3. **测试配置**: 使用 `nixos-rebuild dry-build` 测试配置是否有误

## 📚 参考资源

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [nixos-hardware](https://github.com/NixOS/nixos-hardware)
- [Niri Compositor](https://github.com/YaLTeR/niri)
