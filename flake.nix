{
  description = "NixOS flake for laptop (Ryzen 5 6600H, Radeon 680M) - Niri + Noctalia + Btrfs + Chinese input (fcitx5)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    noctalia.url = "github:noctalia-dev/noctalia-shell";
  };

  outputs = { self, nixpkgs, nixos-hardware, noctalia, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = system;

      modules = [
        ./hardware-configuration.nix

        ({ config, pkgs, lib, ... }: let
            # 尝试安全取 noctalia 的 nixos module / package（外部 flake 未必提供）
            noctaliaModule = if builtins.hasAttr "nixosModules" noctalia then noctalia.nixosModules.default else null;
            noctaliaPkg = if builtins.hasAttr "packages" noctalia && builtins.hasAttr system noctalia.packages then noctalia.packages.${system}.default else null;
          in
        {
          # ---------- 基础 ----------
          networking.hostName = "nixos-laptop";
          time.timeZone = "Asia/Shanghai";
          i18n.defaultLocale = "zh_CN.UTF-8";
          i18n.extraLocales = [ "en_US.UTF-8" ];

          # ---------- 用户（不要把真实密码提交到仓库） ----------
          users.users.yangyus8 = {
            isNormalUser = true;
            description = "Primary user";
            extraGroups = [ "wheel" "video" "audio" ];
            initialPassword = "CHANGE_ME"; # 安装后请立即 `passwd` 修改或移除此字段并使用 SSH key
            openssh.authorizedKeys.keys = [
              # "ssh-ed25519 AAAA.... yourkey@host"
            ];
          };

          nixpkgs.config.allowUnfree = true;

          # ---------- Btrfs / 文件系统 ----------
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

          # ---------- 引导 ----------
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # ---------- 显卡 / OpenGL / Vulkan ----------
          hardware.enableAllFirmware = true;
          hardware.opengl.enable = true;
          hardware.opengl.extraPackages = [ pkgs.amdvlk ];

          # ---------- Niri + Noctalia ----------
          programs.niri.enable = true;

          # 仅在 noctalia module 存在时导入（防止报错）
          imports = lib.filter (x: x != null) [
            noctaliaModule
          ];

          # ---------- 合并后的 systemPackages（唯一定义） ----------
          environment.systemPackages = let
            basePkgs = [
              pkgs.alacritty
              pkgs.firefox
              pkgs.git
              pkgs.vim
              pkgs.htop
              pkgs.ripgrep
            ];
          in
            basePkgs ++ (if noctaliaPkg != null then [ noctaliaPkg ] else []);

          # ---------- Display manager / Wayland ----------
          # 使用 GDM（支持 Wayland 会话）。不要设置 desktopManager.default 或 windowManager.default。
          services.xserver.enable = true;
          services.xserver.displayManager.gdm.enable = true;
          services.xserver.desktopManager = { }; # 保留空集以避免旧配置引用导致错误

          # ---------- 电源管理 ----------
          powerManagement.enable = true;
          services.tlp.enable = true;
          services.tlp.settings = {
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          };

          # ---------- zram ----------
          services.zram.enable = true;
          services.zram.swapSize = 0;

          # ---------- 输入法：fcitx5 ----------
          i18n.inputMethod = {
            type = "fcitx5";
            enable = true;
            fcitx5 = {
              addons = [
                pkgs.fcitx5-rime
                pkgs.fcitx5-chinese-addons
                pkgs.fcitx5-gtk
                pkgs.fcitx5-qt
              ];
              settings = {
                inputMethod = [
                  { Name = "keyboard-us"; }
                  { Name = "rime"; }
                  { Name = "chinese-addons"; }
                ];
              };
            };
          };

          # ---------- 常用工具 / Shell ----------
          programs.zsh.enable = true;
          programs.zsh.ohMyZsh.enable = true;

          security.sudo.enable = true;
          security.sudo.wheelNeedsPassword = true;

          # ---------- 网络 ----------
          networking.networkmanager.enable = true;

          # ---------- 音频 ----------
          sound.enable = true;
          hardware.pulseaudio.enable = false;
          services.pipewire.enable = true;
          services.pipewire.media-session.enable = true;

          # ---------- 其它服务 ----------
          systemd.services."logrotate".enable = true;

        })
      ];
    };
  };
}
