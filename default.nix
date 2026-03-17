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
    sed -i 's|-DTDRUNDIR=\\"\$(lpmd_rundir)\\"|-DTDRUNDIR=\\"/run/intel_lpmd\\"|' Makefile.am
    sed -i 's|-DTDCONFDIR=\\"\$(lpmd_confdir)\\"|-DTDCONFDIR=\\"/etc/intel_lpmd\\"|' Makefile.am

    # Fix error logging to respect print_level parameter
    # Use substituteInPlace for robust replacements
    
    # lpmd_read_int: Open error
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sOpen %s failed\n", prefix, name);' \
                'if (print_level >= 0) lpmd_log_error ("%sOpen %s failed\n", prefix, name);'
    
    # lpmd_read_int: Read error  
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sRead %s failed, ret %d\n", prefix, name, ret);' \
                'if (print_level >= 0) lpmd_log_error ("%sRead %s failed, ret %d\n", prefix, name, ret);'
    
    # lpmd_write_int: Open error
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sOpen %s failed\n", prefix, name);' \
                'if (print_level >= 0) lpmd_log_error ("%sOpen %s failed\n", prefix, name);'
    
    # lpmd_write_int: Write error
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sWrite "%d" to %s failed, ret %d\n", prefix, val, name, ret);' \
                'if (print_level >= 0) lpmd_log_error ("%sWrite "%d" to %s failed, ret %d\n", prefix, val, name, ret);'
    
    # _write_str: Open error
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sOpen %s failed\n", prefix, name);' \
                'if (print_level >= 0) lpmd_log_error ("%sOpen %s failed\n", prefix, name);'
    
    # _write_str: Write error (first line of multi-line)
    substituteInPlace src/lpmd_helpers.c \
      --replace 'lpmd_log_error ("%sWrite "%s" to %s failed, strlen %zu, ret %d\n", prefix, str, name,' \
                'if (print_level >= 0) lpmd_log_error ("%sWrite "%s" to %s failed, strlen %zu, ret %d\n", prefix, str, name,'

    # Add unistd.h include for access() in lpmd_misc.c
    sed -i '/^#include "lpmd.h"/a #include <unistd.h>' src/lpmd_misc.c

    # Replace ITMT path define with dynamic path resolution
    # First remove any existing PATH_ITMT_CONTROL definition
    sed -i '/#define PATH_ITMT_CONTROL/d' src/lpmd_misc.c
    
    # Insert new dynamic path resolution after the includes
    sed -i '/^#include "lpmd.h"/a \
/* ITMT Management */\
static const char *get_itmt_path(void) {\
    static const char *path = NULL;\
    if (!path) {\
        if (access("/proc/sys/kernel/sched_itmt_enabled", F_OK) == 0) {\
            path = "/proc/sys/kernel/sched_itmt_enabled";\
        } else {\
            path = "/sys/kernel/debug/x86/sched_itmt_enabled";\
        }\
    }\
    return path;\
}\
#define PATH_ITMT_CONTROL get_itmt_path()' src/lpmd_misc.c

    # Replace PATH_ITMT_CONTROL macro usage with get_itmt_path() function calls
    # The macro already does this, but ensure any direct usage is replaced
    sed -i 's/"PATH_ITMT_CONTROL"/get_itmt_path()/g' src/lpmd_misc.c
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