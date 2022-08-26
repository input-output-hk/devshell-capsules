{
  outputs = {
    self,
    nixpkgs,
    iogo,
    ragenix,
    bitte,
  }: let
    nixpkgs = nixpkgs.legacyPackages;

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
      iogo = iogo.defaultPackage.${pkgs.system};
    in {
      commands = baser [
        {package = nixpkgs'.arion;}
      ];
      packages = with nixpkgs'; [pwgen];
      devshell.startup.iogo-login = nixpkgs'.lib.stringsWithDeps.noDepEntry ''
        eval "$(${iogo}/bin/iogo login)"
      '';
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
      bitte = bitte.packages.${pkgs.system}.bitte;
      ragenix = ragenix.defaultPackage.${pkgs.system};
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
          package = nixpkgs'.reuse;
        }
        {
          package = nixpkgs'.gh;
        }
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
        {package = nixpkgs'.icdiff;}
        {
          package = nixpkgs'.fx;
          name = "fx";
        }
        {package = nixpkgs'.curlie;}
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

  nixConfig = {
    flake-registry = "https://raw.githubusercontent.com/input-output-hk/flake-registry/iog/flake-registry.json";

    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
