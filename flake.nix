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
        
        # 使用 nixos-hardware 的 AMD CPU 通用配置
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd

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

          # ---------- 引导 ----------
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          
          # Early KMS: 尽早加载 amdgpu 驱动,避免启动闪屏
          boot.initrd.kernelModules = [ "amdgpu" ];
          
          # AMD Ryzen 6000 系列优化内核参数
          boot.kernelParams = [
            # 使用 amd-pstate 驱动 (比 acpi-cpufreq 更高效)
            "amd_pstate=active"
            # 启用 AMD GPU 的省电功能
            "amdgpu.ppfeaturemask=0xffffffff"
          ];

          # ---------- 显卡 / Graphics / Vulkan ----------
          hardware.enableAllFirmware = true;
          hardware.graphics = {
            enable = true;
            enable32Bit = true; # 支持 32 位应用和游戏
            
            # AMD Radeon 680M 视频加速 (VA-API)
            extraPackages = with pkgs; [
              # VA-API 实现 (视频解码/编码硬件加速)
              libva
              vaapiVdpau
              # AMD 专用 VA-API 驱动
              mesa.drivers
            ];
          };
          # AMD 开源驱动 (radv + radeonsi) 已由 Mesa 提供

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
          services.xserver.enable = true;
          services.xserver.displayManager.gdm.enable = true;
          services.xserver.displayManager.gdm.wayland = true;

          # ---------- 电源管理 ----------
          powerManagement.enable = true;
          
          # AMD Ryzen 6000 系列 CPU 频率管理
          powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil"; # 平衡性能和功耗
          
          services.tlp = {
            enable = true;
            settings = {
              # CPU 动态调频策略
              CPU_SCALING_GOVERNOR_ON_AC = "performance";
              CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
              
              # AMD GPU 电源管理
              RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
              RADEON_DPM_PERF_LEVEL_ON_BAT = "low";
              
              # AMD P-State 偏好设置
              CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
              CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
              
              # 平台配置
              PLATFORM_PROFILE_ON_AC = "performance";
              PLATFORM_PROFILE_ON_BAT = "low-power";
            };
          };

          # ---------- zram (已禁用,不使用交换内存) ----------
          # services.zram.enable = false; # 默认即为 false
          
          # 内存管理优化 (无 swap 环境下的推荐设置)
          boot.kernel.sysctl = {
            "vm.swappiness" = 10; # 降低 swap 倾向 (即使没有 swap 也影响内存回收策略)
            "vm.vfs_cache_pressure" = 50; # 减少缓存回收压力
          };

          # ---------- 输入法：fcitx5 ----------
          i18n.inputMethod = {
            enable = true;
            type = "fcitx5";
            fcitx5.addons = with pkgs; [
              fcitx5-rime
              fcitx5-chinese-addons
              fcitx5-gtk
            ];
          };

          # ---------- 常用工具 / Shell ----------
          programs.zsh.enable = true;
          programs.zsh.ohMyZsh.enable = true;

          security.sudo.enable = true;
          security.sudo.wheelNeedsPassword = true;

          # ---------- 网络 ----------
          networking.networkmanager.enable = true;

          # ---------- 音频 (PipeWire) ----------
          hardware.pulseaudio.enable = false;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            # wireplumber 是新的会话管理器,取代了 media-session
            wireplumber.enable = true;
          };

          # ---------- 其它服务 ----------
          systemd.services."logrotate".enable = true;

        })
      ];
    };
  };
}
