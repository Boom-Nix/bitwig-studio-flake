{
  description = "独立flake管理Bitwig Studio（复用本地包文件）";

  # 仅依赖nixpkgs（无需其他输入）
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; # 或指定稳定分支
  };

  outputs = { self, nixpkgs }:
    let
      # 初始化目标系统的pkgs（仅x86_64-linux支持Bitwig）
      supportedSystems = [ "x86_64-linux" ];
      mkPkgs = system: import nixpkgs {
        inherit system;
        config = { allowUnfree = true; }; # 允许非自由包（Bitwig必需）
      };

      # 为每个系统构建Bitwig包
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f (mkPkgs system) system);
    in
    {
      # 定义可直接使用的包
      packages = forAllSystems (pkgs: system: {
        # 1. 构建unwrapped包（对应bitwig-studio5.nix）
        bitwig-studio-unwrapped = pkgs.callPackage ./bitwig/bitwig-studio5.nix {
          bitwigJarSource = ./bitwig.jar;
        };

        # 2. 构建最终包（依赖unwrapped包，对应bitwig-wrapper.nix）
        bitwig-studio = pkgs.callPackage ./bitwig/bitwig-wrapper.nix {
          bitwig-studio-unwrapped = self.packages.${system}.bitwig-studio-unwrapped;
        };

        # 默认包（nix build时直接构建bitwig-studio）
        default = self.packages.${system}.bitwig-studio;
      });

      # 可选：提供NixOS模块，方便系统配置直接引用
      nixosModules.bitwig = { config, pkgs, ... }: {
        environment.systemPackages = [ self.packages.${pkgs.system}.bitwig-studio ];
      };
    };
}

