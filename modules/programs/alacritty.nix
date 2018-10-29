{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.alacritty;

in

{
  options.programs.alacritty = {
    enable = mkEnableOption "Alacritty terminal emulator";

    package = mkOption {
      type = types.package;
      default = pkgs.alacritty;
      defaultText = "pkgs.alacritty";
      description = "Alacritty package to install.";
    };

    configFile = mkOption {
      type = fileType "<varname>xdg.configHome</varname>" cfg.configHome;
      defaultText = ".config/alacritty/alacritty.yml";
      description = "Path to the YAML configuration file of Alacritty";
    };

  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".config/alacritty/settings.yml" = cfg.configFile;
  };
}
