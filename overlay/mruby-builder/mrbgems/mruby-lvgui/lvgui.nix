{ stdenv
, pkgs
, lib
, fetchFromGitHub
, pkg-config
, SDL2
, withSimulator ? false
}:

let
  inherit (lib) optional optionals optionalString;
  simulatorDeps = [
    SDL2
  ];

  # Allow libevdev to cross-compile.
  libevdev = (pkgs.libevdev.override({
    python3 = null;
  })).overrideAttrs({nativeBuildsInputs ? [], ...}: {
    nativeBuildInputs = nativeBuildsInputs ++ [
      pkgs.buildPackages.python3
    ];
  });
  libxkbcommon = pkgs.callPackage (
    { stdenv                                             
    , libxkbcommon                             
    , meson             
    , ninja                                         
    , pkgconfig               
    , yacc                              
    }:                            

    libxkbcommon.overrideAttrs({...}: {
      nativeBuildInputs = [ meson ninja pkgconfig yacc ];
      buildInputs = [ ];                                     

      mesonFlags = [   
        "-Denable-wayland=false"
        "-Denable-x11=false"             
        "-Denable-docs=false"            

        # This is because we're forcing uses of this build
        # to define config and locale root; for stage-1 use.
        # In stage-2, use the regular xkbcommon lib.
        "-Dxkb-config-root=/NEEDS/OVERRIDE/etc/X11/xkb"
        "-Dx-locale-root=/NEEDS/OVERRIDE/share/X11/locale"
      ];

      outputs = [ "out" "dev" ];

      # Ensures we don't get any stray dependencies.
      allowedReferences = [
        "out"
        "dev"
        stdenv.cc.libc_lib
      ];
    })

  ) {};

in
  stdenv.mkDerivation {
    pname = "lvgui";
    version = "2020-11-20";

    src = fetchFromGitHub {
      repo = "lvgui";
      owner = "mobile-nixos";
      rev = "c94c3916012f5615af027389e77e7a974cc3e634";
      sha256 = "16dfdky5v72jqs9v22h1k73g74bnif6fg52vhxw2k8sh6mw1cmzp";
    };

    # Document `LVGL_ENV_SIMULATOR` in the built headers.
    # This allows the mrbgem to know about it.
    # (In reality this should be part of a ./configure step or something similar.)
    postPatch = ''
      sed -i"" '/^#define LV_CONF_H/a #define LVGL_ENV_SIMULATOR ${if withSimulator then "1" else "0"}' lv_conf.h
    '';

    nativeBuildInputs = [
      pkg-config
    ];

    buildInputs = [
      libevdev
      libxkbcommon
    ]
    ++ optionals withSimulator simulatorDeps
    ;

    NIX_CFLAGS_COMPILE = [
      "-DX_DISPLAY_MISSING"
    ];

    makeFlags = [
      "PREFIX=${placeholder "out"}"
    ]
    ++ optional withSimulator "LVGL_ENV_SIMULATOR=1"
    ++ optional (!withSimulator) "LVGL_ENV_SIMULATOR=0"
    ;

    enableParallelBuilding = true;
  }
