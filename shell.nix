{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = [ pkgs.hugo ];
    shellHook = ''
      alias ll="ls -l"
      export FOO=bar
    '';
}

