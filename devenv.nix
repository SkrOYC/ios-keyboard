{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Xcode and its iOS SDK are supplied by the macOS runner under Apple's license.
  # scripts/ios.zsh checks this version before using any Apple tool.
  env.XCODE_VERSION = "26.4.1";
  apple.sdk = null;

  packages =
    with pkgs;
    [
      devenv
      direnv
      git
      gh
      curl
      coreutils
      jq
      ripgrep
      eza
      zsh
      zip
      unzip
      shellcheck
      actionlint
      nixfmt
      (python3.withPackages (python: [ python.pyyaml ]))
      libimobiledevice
      ideviceinstaller
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.xcodegen ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.iloader
      pkgs.usbmuxd
      pkgs.usbutils
    ];

  scripts =
    lib.mapAttrs
      (_: command: {
        exec = ''
          cd ${lib.escapeShellArg config.devenv.root}
          exec ${command}
        '';
      })
      {
        check = "zsh scripts/check.zsh";
        ios-build = "zsh scripts/ios.zsh build";
        ios-test = "zsh scripts/ios.zsh test";
        ios-project = "zsh scripts/ios.zsh project";
        ios-simulator = "zsh scripts/ios.zsh simulator";
        ios-test-build = "zsh scripts/ios.zsh test-build";
        ios-test-run = "zsh scripts/ios.zsh test-run";
        ios-ipad-test = "zsh scripts/ios.zsh ipad-test";
        ios-archive = "zsh scripts/ios.zsh archive";
        ios-package = "zsh scripts/ios.zsh package";
        ipa-check = ''python3 scripts/verify-ipa.py "$@"'';
        phone-check = "zsh scripts/phone.zsh";
      };

  enterTest = "check";
}
