{
  description = "Nix flake to set up Zotero Translation Server.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      # Translation Server Version
      translationServerVersion = "0a9199e0673452218382aa5a979ec9e2107ca9a1";

    in {
      packages.default = pkgs.buildNpmPackage rec {
        pname = "zotero-translation-server";
        version = translationServerVersion;
       
        src = builtins.fetchGit {
          url = "https://github.com/zotero/translation-server";
          submodules = true;
          rev = translationServerVersion;
        };
        npmDepsHash = "sha256-JHoBxUybs1GGRxEVG5GgX2mOCplTgR5dcPjnR42SEbY=";
        makeCacheWritable = true;
	    dontNpmBuild = true;
           
        postInstall = ''
          mkdir "$out/bin"
          cat > $out/bin/zotero-translation-server <<'EOF'
          #!/usr/bin/env bash
          cd "$(dirname "$0")/../lib/node_modules/translation-server"
          exec ${pkgs.nodejs}/bin/node src/server.js "$@"
          EOF

          chmod +x $out/bin/zotero-translation-server
        '';

        executable = true;
        packageJson = "${src}/package.json";
       
        meta = with pkgs.lib; {
          description = "Zotero Translation Server";
          homepage = "https://github.com/zotero/translation-server";
          license = licenses.mit;
          platforms = platforms.all;
        };
      };
      apps.default = flake-utils.lib.mkApp {
        drv = self.packages.${system}.default;
        name = "zotero-translation-server";
      };

      nixosModules.zotero-translation-server = {config, lib, ... }:
      let cfg = config.services.zotero-translation-server;
      in {
        options.services.zotero-translation-server = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Start zotero's translation server on port 1969.
              Query webpages with
              `curl -d 'https://www.ncbi.nlm.nih.gov/pubmed/?term=crispr' \
                -H 'Content-Type: text/plain' http://127.0.0.1:1969/web`
              or other non-webpages with
              `curl -d 10.2307/4486062 -H 'Content-Type: text/plain' http://127.0.0.1:1969/search`
            '';
          };
        };
   
        # Define the configuration.
        config = lib.mkIf cfg.enable {
          # Add dependencies for the search service.
          # environment.systemPackages = [ meiliwatch ];
   
          # Systemd service for the directory watcher.
          systemd.services.zotero-translation-server = {
            description = "have Zotero's translation server liston on port 1969";
            wants = [ "network-online.target" ]; # Ensure Meilisearch is up before starting
            after = [ "network-online.target" ];
            serviceConfig = {
              ExecStart = self.packages.${system}.default;
              Restart = "on-failure";
              RestartSec = 5;
            };
            wantedBy = [ "multi-user.target" ];
          };
        };
      };
    }
  );
}

