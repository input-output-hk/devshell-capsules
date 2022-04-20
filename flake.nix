{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    iogo.url = "github:input-output-hk/bitte-iogo";
    ragenix.url = "github:input-output-hk/ragenix";
    bitte.url = "github:input-output-hk/bitte";
  };

  outputs = inputs: let
    nixpkgs = inputs.nixpkgs.legacyPackages;

    withCategory = category: attrset: attrset // {inherit category;};
    clouder = map (withCategory "cloud");
    metaler = map (withCategory "metal");
    integrator = map (withCategory "integrations");
    tooler = map (withCategory "tools");
    baser = map (withCategory "base");

    _file = "github:input-outupt-hk/devshell-capsules";
  in {
    # --------------------------------------
    # Base: should be part of any devshell
    # --------------------------------------
    base = {pkgs, ...}: let
      nixpkgs' = nixpkgs.${pkgs.system};
      iogo = inputs.iogo.defaultPackage.${pkgs.system};
    in {
      commands = baser [
        {package = nixpkgs'.arion;}
      ];
      packages = with nixpkgs'; [
        treefmt
        alejandra
        nodePackages.prettier
        nodePackages.prettier-plugin-toml
        shfmt
        editorconfig-checker
      ];
      devshell.startup.nodejs-setuphook = nixpkgs'.lib.stringsWithDeps.noDepEntry ''
        export NODE_PATH=${nixpkgs'.nodePackages.prettier-plugin-toml}/lib/node_modules:$NODE_PATH
      '';
      devshell.startup.iogo-login = nixpkgs'.lib.stringsWithDeps.noDepEntry ''
        eval "$(${iogo}/bin/iogo login)"
      '';
    };

    # --------------------------------------
    # Hooks: use the default company-wide git hooks
    # --------------------------------------
    hooks = {extraModulesPath, ...}: {
      inherit _file;
      imports = ["${extraModulesPath}/git/hooks.nix"];
      git.hooks.enable = true;
      git.hooks.pre-commit.text = builtins.readFile ./pre-commit.sh;
    };

    # --------------------------------------
    # Cloud: tools for managing the company cloud
    # --------------------------------------
    cloud = {pkgs, ...}: let
      nixpkgs' = nixpkgs.${pkgs.system};
    in {
      inherit _file;
      commands = clouder [
        {
          package = nixpkgs'.vault-bin;
          name = "vault";
        }
        {package = nixpkgs'.consul;}
        {package = nixpkgs'.nomad;}
        {package = nixpkgs'.sops;}
        {
          name = "htdigest";
          command = ''${nixpkgs'.apacheHttpd}/bin/htdigest "$@"'';
          help = "create new http authentication tokens";
        }
        {package = nixpkgs'.skopeo;}
        {
          package = nixpkgs'.writeShellApplication {
            name = "nomad-exec";
            runtimeInputs = [
              nixpkgs'.consul
              nixpkgs'.curl
              nixpkgs'.jq
              nixpkgs'.nomad
            ];
            text = builtins.readFile ./nomad-exec.sh;
          };
          help = "Nomad allocation shell exec helper";
        }
      ];
    };

    # --------------------------------------
    # Metal: tools for managing the bare metal
    # --------------------------------------
    metal = {pkgs, ...}: let
      nixpkgs' = nixpkgs.${pkgs.system};
      bitte = inputs.bitte.packages.${pkgs.system}.bitte;
      ragenix = inputs.ragenix.defaultPackage.${pkgs.system};
    in {
      inherit _file;
      commands = metaler [
        {package = bitte;}
        {package = ragenix;}
        {
          package = nixpkgs'.awscli;
          name = "aws";
        }
        {
          package = nixpkgs'.writeShellApplication {
            name = "diff-bitte";
            runtimeInputs = [nixpkgs'.nix-diff];
            text = builtins.readFile ./diff-bitte.sh;
          };
          help = "What changes with bitte commit XYZ";
        }
      ];
    };

    # --------------------------------------
    # Intergations: interations with jira et al.
    # --------------------------------------
    integrations = {pkgs, ...}: let
      nixpkgs' = nixpkgs.${pkgs.system};
    in {
      inherit _file;
      commands = integrator [
        {
          package = nixpkgs'.go-jira;
          name = "jira";
        }
        {
          package = nixpkgs'.bitwarden-cli;
          name = "bw";
          help = "cli to interact with vaultwarden";
        }
      ];
    };

    # --------------------------------------
    # Tools: utility tooling - enjoy!
    # --------------------------------------
    tools = {pkgs, ...}: let
      nixpkgs' = nixpkgs.${pkgs.system};
    in {
      inherit _file;
      commands = tooler [
        {package = nixpkgs'.jq;}
        {package = nixpkgs'.ijq;}
        {
          package = nixpkgs'.fx;
          name = "fx";
        }
        {package = nixpkgs'.curlie;}
        {package = nixpkgs'.pwgen;}
        {
          package = nixpkgs'.difftastic;
          name = "difft";
        }
      ];
    };

    # for local use only ...
    # --------------------------------------
    devShell."x86_64-linux" = with nixpkgs."x86_64-linux";
      mkShell {
        name = "Devshell-Capsules";
        packages = [
          treefmt
          alejandra
          nodejs # for node path setup hook for prettier plugin
          nodePackages.prettier
          nodePackages.prettier-plugin-toml
          shfmt
        ];
      };
  };
}
