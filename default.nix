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
    
    # Patch runtime directories to use system paths instead of store paths
    # TDRUNDIR should be /run/intel_lpmd (created by systemd's RuntimeDirectory)
    # TDCONFDIR should be /etc/intel_lpmd (symlinked by activation script)
    sed -i 's|-DTDRUNDIR="\$(lpmd_rundir)"|-DTDRUNDIR="/run/intel_lpmd"|' Makefile.am
    sed -i 's|-DTDCONFDIR="\$(lpmd_confdir)"|-DTDCONFDIR="/etc/intel_lpmd"|' Makefile.am
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