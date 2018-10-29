{ config, lib, pkgs, ... }:

with lib;

{
  meta.maintainers = [ maintainers.mogria ];

  options = {
    services.searx = {
      enable = mkEnableOption "Searx a customizable, self-hostable Metasearch Engine";

      extraConfig = mkOption {
        type = types.string;
        default = "";
        description = ''
          Additional YAML configuration to add to settings.yml
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf config.services.searx.enable {
      systemd.user.services = {
        searx = {
          Unit = {
            Description = "Searx - Metasearch-Engine";
            After = [ "network.target" ];
          };

          Service = {
            ExecStart = "${pkgs.searx}/bin/searx-run";
            EnvironmentFile = pkgs.writeText "searx-systemd-environment-file" ''
              SEARX_SETTINGS_PATH=${pkgs.writeText "settings.yml" config.services.searx.extraConfig}
            '';
            Restart = "on-failure";
          };

          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
    })
  ];
}
