{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];  # 导入硬件配置模块，用于加载硬件扫描结果

  # 引导加载器配置
  boot.loader.systemd-boot.enable = true;  # 启用systemd-boot引导程序
  boot.loader.efi.canTouchEfiVariables = true;  # 允许修改EFI变量，支持UEFI引导

  # 网络配置
  networking.hostName = "nixos";  # 设置主机名
  networking.networkmanager.enable = true;  # 启用NetworkManager，支持无线网络管理

  # 时区设置
  time.timeZone = "Asia/Shanghai";  # 设置时区为上海（中国标准时间）

  # Nix包管理器配置
  nix.settings = {
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"  # 添加清华大学镜像源，提高下载速度
      "https://mirrors.ustc.edu.cn/nix-channels/store?priority=5"  # 添加中科大镜像源
      "https://cache.nixos.org/"  # 默认官方缓存
    ];
    experimental-features = [ "nix-command" "flakes" ];  # 启用实验性功能：nix命令增强和flakes支持
  };

  # X11服务器和桌面环境配置
  services.xserver.enable = true;  # 启用X11窗口系统
  services.desktopManager.gnome.enable = true;  # 启用GNOME桌面环境
  services.displayManager.gdm.enable = true;  # 启用GDM显示管理器（GNOME登录界面）
  programs.niri.enable = true;  # 启用Niri Wayland合成器（作为GNOME的替代或补充）

  # 键盘布局配置
  services.xserver.xkb.layout = "us";  # 设置X11键盘布局为美式

  # 打印服务
  services.printing.enable = true;  # 启用CUPS打印系统

  # 音频配置
  services.pulseaudio.enable = false;  # 禁用PulseAudio（使用PipeWire替代）
  security.rtkit.enable = true;  # 启用RTKit实时内核支持（用于音频权限）
  services.pipewire = {
    enable = true;  # 启用PipeWire多媒体框架
    alsa.enable = true;  # 启用PipeWire的ALSA兼容层
    alsa.support32Bit = true;  # 支持32位ALSA应用
    pulse.enable = true;  # 启用PulseAudio兼容层
  };

  # 用户账户配置
  users.users.<你的用户名> = {
    isNormalUser = true;  # 创建普通用户
    description = "<你的用户名>";  # 用户描述
    extraGroups = [ "networkmanager" "wheel" ];  # 添加用户到额外组（网络管理和sudo权限）
    packages = with pkgs; [ ];  # 用户专属包列表（当前为空）
  };

  # 应用程序配置
  programs.firefox.enable = true;  # 启用Firefox浏览器（系统级安装）
  services.flatpak.enable = true;  # 启用Flatpak包管理器，支持第三方应用

  # Nixpkgs配置
  nixpkgs.config.allowUnfree = true;  # 允许安装非自由软件包

  # 系统级包列表
  environment.systemPackages = with pkgs; [
    vim  # 文本编辑器
    wget  # 文件下载工具
    alacritty  # 终端模拟器
  ];

  # 服务配置
  services.openssh.enable = true;  # 启用OpenSSH服务器，支持远程登录

  # 系统版本
  system.stateVersion = "25.05";  # 指定NixOS状态版本（保持为首次安装版本）
}