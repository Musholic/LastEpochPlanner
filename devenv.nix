{
  pkgs,
  ...
}: {
  packages = with pkgs; [
    luajitPackages.busted
    luajitPackages.luacov
    libxml2
  ];

  languages.lua = {
    enable = true;
    package = pkgs.luajit;
  };

  enterShell = ''
    EMMY_DIR="$DEVENV_STATE/emmylua"
    mkdir -p "$EMMY_DIR"

    # Download Linux binary if missing
    if [ ! -f "$EMMY_DIR/emmy_core.so" ]; then
      echo "Downloading EmmyLua Debugger (Linux)..."
      curl -# -L "https://github.com/EmmyLua/EmmyLuaDebugger/releases/download/1.9.0/linux-x64.zip" -o "$EMMY_DIR/linux.zip"
      unzip -q -o "$EMMY_DIR/linux.zip" -d "$EMMY_DIR/" "emmy_core.so"
      rm "$EMMY_DIR/linux.zip"
    fi

    # Download Windows DLL if missing
    if [ ! -f "$EMMY_DIR/emmy_core.dll" ]; then
      echo "Downloading EmmyLua Debugger (Windows)..."
      curl -# -L "https://github.com/EmmyLua/EmmyLuaDebugger/releases/download/1.9.0/win32-x64.zip" -o "$EMMY_DIR/win.zip"
      unzip -q -o "$EMMY_DIR/win.zip" -d "$EMMY_DIR/" "emmy_core.dll"
      rm "$EMMY_DIR/win.zip"
    fi

    ln -sf "$EMMY_DIR/emmy_core.dll" "$DEVENV_ROOT/runtime/emmy_core.dll"
    export LUA_CPATH="$EMMY_DIR/emmy_core.so;"
  '';

  # See full reference at https://devenv.sh/reference/options/
}
