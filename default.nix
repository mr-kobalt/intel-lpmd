{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "intel-lpmd";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = with pkgs; [
    autoreconfHook
    pkg-config
    gtk-doc
    autoconf-archive
  ];

  buildInputs = with pkgs; [
    glib
    libxml2
    libnl
    systemd
    upower
  ];

  configureFlags = [
    "--with-systemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
    "--with-dbus-sys-dir=${placeholder "out"}/share/dbus-1/system.d"
  ];

  prePatch = ''
    # Remove gzip and mandb lines from install-data-hook
    sed -i '/^install-data-hook:/,/^[^[:space:]]/ { /gzip.*intel_lpmd\.8/d; /mandb/d; }' Makefile.am
  '';

  postInstall = "";

  meta = with pkgs.lib; {
    description = "Intel Low Power Mode Daemon";
    homepage = "https://github.com/intel/intel-lpmd";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}