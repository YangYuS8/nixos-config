{
  description = "NixOS flake for laptop (Ryzen 5 6600H, Radeon 680M) - Niri + Noctalia + Btrfs + Chinese input (fcitx5)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";   # 使用 unstable 以获取较新 Wayland 组件
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    # Niri is packaged in nixpkgs; we enable it via programs.niri.enable below.
  };

  outputs = { self, nixpkgs, nixos-hardware, noctalia, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # 这里的 "laptop" 就是我们后续引用的配置名： .#laptop
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = system;

      modules = [
        ./hardware-configuration.nix   # 请确保此文件与 flake 同目录（nixos-generate-config 生成）
        # 你也可以选择把特定硬件模块从 nixos-hardware 加进来（可选）
        # nixos-hardware.nixosModules.lenovo-legion-15ach6h

        # 主配置（内联，便于直接复制）
        ({ config, pkgs, lib, ... }: {

          # ---------- 基本系统信息 ----------
          networking.hostName = "Client-Alpha";    # <- 改成你想要的主机名
          time.timeZone = "Asia/Shanghai";
          i18n.defaultLocale = "zh_CN.UTF-8";
          i18n.extraLocales = [ "en_US.UTF-8" ];

          # ---------- 用户（请勿把真实密码 commit） ----------
          users.users.yangyus8 = {
            isNormalUser = true;
            description = "Primary user";
            extraGroups = [ "wheel" "video" "audio" ];
            # 初始密码占位（**不要**把真实密码保存在公开仓库，安装后请用 `passwd` 修改）
            initialPassword = "CHANGE_ME";
            # 推荐使用 SSH 公钥登录：把你的公钥添加到下面数组（未填则注释/删除）
            openssh.authorizedKeys.keys = [
              # "ssh-ed25519 AAAA.... yourkey@host"
            ];
          };

          # ---------- 启用 flake 的不自由软件（若需要显卡专有驱动） ----------
          nixpkgs.config.allowUnfree = true;

          # ---------- 文件系统（Btrfs 子卷） ----------
          # 我们在安装步骤中已经把分区打标签为 nixos-root
          fileSystems."/" = {
            device = "/dev/disk/by-label/nixos-root";
            fsType = "btrfs";
            options = [ "subvol=root" "compress=zstd:3" "ssd" "space_cache=v2" ];
          };
          fileSystems."/home" = {
            device = "/dev/disk/by-label/nixos-root";
            fsType = "btrfs";
            options = [ "subvol=home" "compress=zstd:3" "ssd" "space_cache=v2" ];
          };
          fileSystems."/nix" = {
            device = "/dev/disk/by-label/nixos-root";
            fsType = "btrfs";
            options = [ "subvol=nix" "compress=zstd:1" "noatime" "ssd" "space_cache=v2" ];
          };
          fileSystems."/var" = {
            device = "/dev/disk/by-label/nixos-root";
            fsType = "btrfs";
            options = [ "subvol=var" "compress=zstd:1" "noatime" "ssd" "space_cache=v2" ];
          };

          # ---------- 引导加载器（UEFI） ----------
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # ---------- 显卡与 OpenGL/Vulkan ----------
          hardware.enableAllFirmware = true;
          hardware.opengl.enable = true;
          # AMD 集成显卡：mesa 通常在 hardware.opengl 中自动包含，额外可加 vulkan 驱动
          hardware.opengl.extraPackages = with pkgs; [ amdvlk ];

          # ---------- 窗口管理器 / 桌面（Niri + Noctalia） ----------
          # Niri: 启用 Niri 的 NixOS module（niri 已在 nixpkgs 中）
          programs.niri.enable = true;
          # Noctalia: 使用其 flake 提供的 NixOS module（noctalia flake）
          imports = [
            noctalia.nixosModules.default
          ];
          environment.systemPackages = (config.environment.systemPackages or []) ++ [
            noctalia.packages.${system}.default
          ];

          # Display manager: GDM 对 Wayland 支持较好（可改为 lightdm/sddm）
          services.xserver.enable = true;
          services.xserver.displayManager.gdm.enable = true;
          # 不启用 KDE/GNOME 默认桌面（我们用 Noctalia）
          services.xserver.desktopManager.default = "none";
          services.xserver.windowManager.default = "niri";

          # 如果你要用 LightDM（轻量），把上面 gdm 注释、启用 lightdm：
          # services.xserver.displayManager.gdm.enable = false;
          # services.xserver.displayManager.lightdm.enable = true;

          # ---------- 电源管理（笔记本重点） ----------
          powerManagement.enable = true;
          services.tlp.enable = true;
          services.tlp.settings = {
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          };

          # ---------- zram（可选） ----------
          # 启用 zram 以减少 swap IO（在笔记本上通常不错）
          services.zram.enable = true;
          services.zram.swapSize = 0; # 0 = 自动计算

          # ---------- 本地化与输入法（fcitx5） ----------
          # 使用 NixOS 的 i18n.inputMethod 模块启用 fcitx5
          i18n.inputMethod = {
            type = "fcitx5";
            enable = true;
            fcitx5 = {
              addons = with pkgs; [
                fcitx5-rime
                fcitx5-chinese-addons
                fcitx5-gtk
                fcitx5-qt
              ];
              # 下面 settings 可以用于在 Nix 层面预定输入法配置（示例）
              settings = {
                inputMethod = [
                  { Name = "keyboard-us"; }
                  { Name = "rime"; }
                  { Name = "chinese-addons"; }
                ];
              };
            };
          };

          # ---------- 常用软件包（按需增删） ----------
          environment.systemPackages = (environment.systemPackages or []) ++ with pkgs; [
            alacritty
            firefox
            git
            vim
            htop
            ripgrep
          ];

          # ---------- Shell / dev tools ----------
          programs.zsh.enable = true;
          programs.zsh.ohMyZsh.enable = true;

          # ---------- sudo ----------
          security.sudo.enable = true;
          security.sudo.wheelNeedsPassword = true;

          # ---------- services to enable ----------
          services = {
            # NetworkManager 方便笔记本网络配置（wifi）
            NetworkManager.enable = true;
            # PipeWire for audio (Wayland friendly)
            sound.enable = true;
            hardware.pulseaudio.enable = false;
            hardware.pulseaudio.package = null;
            services.pipewire.enable = true;
            services.pipewire.media-session.enable = true;
          };

          # ---------- Security & minimal logs ----------
          systemd.services."logrotate".enable = true;

          # ---------- Final tweaks / comments ----------
          # 如果你需要对 Noctalia / Niri 做更细粒度设置，建议把配置拆成单独的 .nix 文件并在此 imports 中引入。
        })
      ];
    };
  };
}

