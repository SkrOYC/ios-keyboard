{ pkgs, lib, ... }:
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

  scripts = {
    check.exec = "exec zsh scripts/check.zsh";
    ios-build.exec = "exec zsh scripts/ios.zsh build";
    ios-test.exec = "exec zsh scripts/ios.zsh test";
    ipa-check.exec = ''exec python3 scripts/verify-ipa.py "$@"'';
    phone-check.exec = "exec zsh scripts/phone.zsh";
  };

  enterTest = "check";
}
