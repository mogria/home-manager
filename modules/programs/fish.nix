{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.fish;

  abbrsStr = concatStringsSep "\n" (
    mapAttrsToList (k: v: "abbr --add --global ${k} '${v}'") cfg.shellAbbrs
  );

  aliasesStr = concatStringsSep "\n" (
    mapAttrsToList (k: v: "alias ${k}='${v}'") cfg.shellAliases
  );

in

{
  options = {
    programs.fish = {
      enable = mkEnableOption "fish friendly interactive shell";

      package = mkOption {
        default = pkgs.fish;
        defaultText = literalExample "pkgs.fish";
        description = ''
          The fish package to install. May be used to change the version.
        '';
        type = types.package;
      };

      shellAliases = mkOption {
        default = {};
        description = ''
          Set of aliases for fish shell. See
          <option>environment.shellAliases</option> for an option
          format description.
        '';
        type = types.attrs;
      };

      shellAbbrs = mkOption {
        default = {};
        description = ''
          Set of abbreviations for fish shell.
        '';
        type = types.attrs;
      };

      shellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during fish shell initialisation.
        '';
        type = types.lines;
      };

      loginShellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during fish login shell initialisation.
        '';
        type = types.lines;
      };

      interactiveShellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during interactive fish shell initialisation.
        '';
        type = types.lines;
      };

      promptInit = mkOption {
        default = "";
        description = ''
          Shell script code used to initialise fish prompt.
        '';
        type = types.lines;
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.dataFile."fish/home-manager_generated_completions".source =
      let
        # paths later in the list will overwrite those already linked
        destructiveSymlinkJoin =
          args_@{ name
              , paths
              , preferLocalBuild ? true
              , allowSubstitutes ? false
              , postBuild ? ""
              , ...
              }:
          let
            args = removeAttrs args_ [ "name" "postBuild" ]
              // { inherit preferLocalBuild allowSubstitutes; }; # pass the defaults
          in pkgs.runCommand name args
            ''
              mkdir -p $out
              for i in $paths; do
                if [ -z "$(find $i -prune -empty)" ]; then
                  cp -srf $i/* $out
                fi
              done
              ${postBuild}
            '';
        generateCompletions = package: pkgs.runCommand
          "${package.name}-fish-completions"
          {
            src = package;
            nativeBuildInputs = [ pkgs.python2 ];
            buildInputs = [ cfg.package ];
            preferLocalBuild = true;
            allowSubstitutes = false;
          }
          ''
            mkdir -p $out
            if [ -d $src/share/man ]; then
              find $src/share/man -type f \
                | xargs python ${cfg.package}/share/fish/tools/create_manpage_completions.py --directory $out \
                > /dev/null
            fi
          '';
      in
        destructiveSymlinkJoin {
          name = "${config.home.username}-fish-completions";
          paths =
            let
              cmp = (a: b: (a.meta.priority or 0) > (b.meta.priority or 0));
            in
              map generateCompletions (sort cmp config.home.packages);
        };

    programs.fish.interactiveShellInit = ''
      # add completions generated by Home Manager to $fish_complete_path
      begin
        set -l joined (string join " " $fish_complete_path)
        set -l prev_joined (string replace --regex "[^\s]*generated_completions.*" "" $joined)
        set -l post_joined (string replace $prev_joined "" $joined)
        set -l prev (string split " " (string trim $prev_joined))
        set -l post (string split " " (string trim $post_joined))
        set fish_complete_path $prev "${config.xdg.dataHome}/fish/home-manager_generated_completions" $post
      end
    '';

    xdg.configFile."fish/config.fish".text = ''
      # ~/.config/fish/config.fish: DO NOT EDIT -- this file has been generated automatically.
      # if we haven't sourced the general config, do it
      if not set -q __fish_general_config_sourced
        set fish_function_path ${pkgs.fish-foreign-env}/share/fish-foreign-env/functions $fish_function_path
        fenv source ${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh > /dev/null
        set -e fish_function_path[1]

        ${cfg.shellInit}
        # and leave a note so we don't source this config section again from
        # this very shell (children will source the general config anew)
        set -g __fish_general_config_sourced 1
      end
      # if we haven't sourced the login config, do it
      status --is-login; and not set -q __fish_login_config_sourced
      and begin

        ${cfg.loginShellInit}
        # and leave a note so we don't source this config section again from
        # this very shell (children will source the general config anew)
        set -g __fish_login_config_sourced 1
      end
      # if we haven't sourced the interactive config, do it
      status --is-interactive; and not set -q __fish_interactive_config_sourced
      and begin
        # Abbrs
        ${abbrsStr}

        # Aliases
        ${aliasesStr}

        ${cfg.promptInit}
        ${cfg.interactiveShellInit}
        # and leave a note so we don't source this config section again from
        # this very shell (children will source the general config anew,
        # allowing configuration changes in, e.g, aliases, to propagate)
        set -g __fish_interactive_config_sourced 1
      end
    '';
  };
}
