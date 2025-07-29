{
  description = "Nmap development environment with all build dependencies";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Custom build environment for nmap with all dependencies
        nmapBuildEnv = pkgs.stdenv.mkDerivation {
          name = "nmap-build-env";
          version = "dev";

          # Build dependencies based on configure.ac and build analysis
          nativeBuildInputs = with pkgs; [
            # Core build tools
            gcc
            gnumake
            autoconf
            automake
            libtool
            pkg-config

            # Version control and development tools
            git

            # Required for autotools
            m4
            perl

            # Python for scripts and zenmap (if needed)
            python3
            python3Packages.setuptools
            python3Packages.pip

            # Documentation tools
            groff

            # Archive tools
            gzip
            gnutar
          ];

          buildInputs = with pkgs; [
            # SSL/TLS support - critical for modern nmap functionality
            openssl

            # Network packet capture
            libpcap

            # PCRE for pattern matching
            pcre2

            # SSH2 support for SSH scanning
            libssh2

            # Compression
            zlib

            # Lua for NSE (Nmap Scripting Engine)
            lua5_4

            # Linear algebra for some advanced features
            # Note: nmap includes its own liblinear, but system version can be used

            # Network interface manipulation
            # Note: nmap includes libdnet-stripped

            # Additional libraries that might be useful
            ncurses  # For terminal UI components
            readline # For interactive features

            # Development libraries
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            glibc.dev
            linux-headers
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # macOS specific libraries if needed
          ];

          # Environment variables for build
          shellHook = ''
            echo "🗺️  Nmap Development Environment"
            echo "================================"
            echo "Available tools:"
            echo "  • GCC ${pkgs.gcc.version}"
            echo "  • OpenSSL ${pkgs.openssl.version}"
            echo "  • libpcap ${pkgs.libpcap.version}"
            echo "  • PCRE2 ${pkgs.pcre2.version}"
            echo "  • libssh2 ${pkgs.libssh2.version}"
            echo "  • Lua ${pkgs.lua5_4.version}"
            echo "  • Python ${pkgs.python3.version}"
            echo ""
            echo "Build commands:"
            echo "  ./configure --with-openssl=${pkgs.openssl.dev} \\"
            echo "              --with-libpcap=yes \\"
            echo "              --with-libpcre=yes \\"
            echo "              --with-libssh2=${pkgs.libssh2.dev} \\"
            echo "              --with-liblua=yes"
            echo "  make -j$(nproc)"
            echo ""
            echo "For static build (recommended for distribution):"
            echo "  ./configure --with-openssl=${pkgs.openssl.dev} \\"
            echo "              --with-libdnet=included \\"
            echo "              --with-libpcap=included \\"
            echo "              --with-libpcre=included \\"
            echo "              --with-liblua=included \\"
            echo "              --with-libz=included"
            echo "  make static"
            echo ""

            # Set up build environment
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.libpcap}/lib/pkgconfig:${pkgs.pcre2.dev}/lib/pkgconfig:${pkgs.libssh2.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export CPPFLAGS="-I${pkgs.openssl.dev}/include -I${pkgs.libpcap}/include -I${pkgs.pcre2.dev}/include -I${pkgs.libssh2.dev}/include -I${pkgs.zlib.dev}/include $CPPFLAGS"
            export LDFLAGS="-L${pkgs.openssl.out}/lib -L${pkgs.libpcap}/lib -L${pkgs.pcre2.out}/lib -L${pkgs.libssh2.out}/lib -L${pkgs.zlib.out}/lib $LDFLAGS"

            # Lua environment for NSE development
            export LUA_PATH="${pkgs.lua5_4}/share/lua/5.4/?.lua;${pkgs.lua5_4}/share/lua/5.4/?/init.lua;;"
            export LUA_CPATH="${pkgs.lua5_4}/lib/lua/5.4/?.so;;"

            # Set up Python environment for zenmap and ndiff
            export PYTHONPATH="${pkgs.python3Packages.setuptools}/${pkgs.python3.sitePackages}:$PYTHONPATH"

                         # Ensure we can find system headers (Linux only)
             ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
               export C_INCLUDE_PATH="${pkgs.glibc.dev}/include:$C_INCLUDE_PATH"
               export CPLUS_INCLUDE_PATH="${pkgs.glibc.dev}/include:$CPLUS_INCLUDE_PATH"
             ''}

            echo "✅ Environment configured successfully!"
          '';

          # Prevent the derivation from actually building anything
          dontBuild = true;
          dontInstall = true;
        };

            in
      {
        # Alternative shells for different use cases
        devShells = {
          # Full development environment (default)
          default = nmapBuildEnv;

                     # Minimal build environment (for CI/automated builds)
           minimal = pkgs.mkShell {
             nativeBuildInputs = with pkgs; [
               gcc
               gnumake
              autoconf
              automake
              libtool
              pkg-config
            ];

            buildInputs = with pkgs; [
              openssl
              libpcap
              pcre2
              libssh2
              zlib
              lua5_4
            ];

            shellHook = ''
              echo "🗺️  Nmap Minimal Build Environment"
              echo "Build with: ./configure && make"
            '';
          };

                     # Static build environment (for creating portable binaries)
           static = pkgs.mkShell {
             nativeBuildInputs = with pkgs; [
               gcc
               gnumake
              autoconf
              automake
              libtool
              pkg-config
              upx  # For binary compression
            ];

                         buildInputs = with pkgs; [
               openssl
               libpcap
               pcre2
               libssh2
               zlib
               lua5_4
             ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
               # Static libraries for Linux builds
               glibc.static
             ];

            shellHook = ''
              echo "🗺️  Nmap Static Build Environment"
              echo "Build with: ./configure --with-libdnet=included --with-libpcap=included --with-libpcre=included --with-liblua=included --with-libz=included && make static"
              echo "This will create a portable nmap binary with minimal dependencies."
            '';
          };

          # Cross-compilation environments
          cross-windows = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              pkgsCross.mingwW64.stdenv.cc
              gnumake
              autoconf
              automake
              libtool
              pkg-config
            ];

            shellHook = ''
              echo "🗺️  Nmap Windows Cross-Compilation Environment"
              echo "Configure for Windows build with appropriate cross-compilation flags"
            '';
          };
        };

        # Packages
        packages = {
          # Custom nmap build (example - you'd typically build from source)
          nmap-dev = pkgs.stdenv.mkDerivation {
            pname = "nmap-dev";
            version = "dev";

            src = ./.;

                         nativeBuildInputs = with pkgs; [
               gcc
               gnumake
              autoconf
              automake
              libtool
              pkg-config
            ];

            buildInputs = with pkgs; [
              openssl
              libpcap
              pcre2
              libssh2
              zlib
              lua5_4
            ];

            configureFlags = [
              "--with-openssl=${pkgs.openssl.dev}"
              "--with-libpcap=yes"
              "--with-libpcre=yes"
              "--with-libssh2=${pkgs.libssh2.dev}"
              "--with-liblua=yes"
            ];

            enableParallelBuilding = true;

            meta = with pkgs.lib; {
              description = "Network exploration tool and security scanner (development build)";
              homepage = "https://nmap.org/";
              license = licenses.gpl2Plus;
              platforms = platforms.linux ++ platforms.darwin;
              maintainers = [ maintainers.thoughtpolice ];
            };
          };
        };

        # Default package
        defaultPackage = self.packages.${system}.nmap-dev;

        # Apps
        apps = {
          # Run nmap directly
          nmap = flake-utils.lib.mkApp {
            drv = self.packages.${system}.nmap-dev;
            exePath = "/bin/nmap";
          };

          # Run configure script with optimal flags
          configure = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "configure-nmap" ''
              set -e
              echo "🗺️  Configuring nmap with optimal settings..."
              ./configure \
                --with-openssl=${pkgs.openssl.dev} \
                --with-libpcap=yes \
                --with-libpcre=yes \
                --with-libssh2=${pkgs.libssh2.dev} \
                --with-liblua=yes \
                --enable-debug \
                --prefix="$PWD/install"
              echo "✅ Configuration complete! Run 'make -j$(nproc)' to build."
            '';
          };

          # Build script
          build = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "build-nmap" ''
              set -e
              echo "🗺️  Building nmap..."
              if [ ! -f Makefile ]; then
                echo "❌ No Makefile found. Run 'nix run .#configure' first."
                exit 1
              fi
              make -j$(nproc)
              echo "✅ Build complete!"
            '';
          };
        };
      });
}
