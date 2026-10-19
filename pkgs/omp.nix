# Install the official Oh My Pi release binary. Its Bun runtime and native
# addons are bundled, so it does not need npm or a separate Bun installation.
# To update, change version and the hashes from that release's GitHub assets.
# Keep macOS binary fixups disabled to preserve its upstream code signature.
{ pkgs }:
let
  version = "18.5.1";
  releaseUrl = "https://github.com/can1357/oh-my-pi/releases/download/v${version}";
  platform = {
    aarch64-darwin = {
      name = "omp-darwin-arm64";
      hash = "sha256-Kr2BYavxNUxZJUfmaeKnqfbmO+EVb6ZYZdKn2wsR/3k=";
    };
    x86_64-darwin = {
      name = "omp-darwin-x64";
      hash = "sha256-nnlsbZqh6+2fysINWTe1ezrxW5ZOuoSDrdWWZ9MVlJw=";
    };
    x86_64-linux = {
      name = "omp-linux-x64";
      hash = "sha256-+3Y46C8MnQh+luFdPrg6Zi2SN0zZBxh9bU0mBeOfHjo=";
    };
  }.${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported OMP release platform: ${pkgs.stdenv.hostPlatform.system}");
  license = pkgs.fetchurl {
    url = "${releaseUrl}/LICENSE";
    sha256 = "16c45f9d667442781f03fa198914cc39abcaa48ec5ed8f644643e554ca2fbf63";
  };
  notices = pkgs.fetchurl {
    url = "${releaseUrl}/THIRD-PARTY-NOTICES.txt";
    sha256 = "d0c2e7c05bb4d755044b13fa560be58d01ab7c980b87892400a979397e569a8b";
  };
in
pkgs.stdenvNoCC.mkDerivation ({
  pname = "omp";
  inherit version;

  src = pkgs.fetchurl {
    url = "${releaseUrl}/${platform.name}";
    inherit (platform) hash;
  };

  dontUnpack = true;
  dontFixup = pkgs.stdenv.hostPlatform.isDarwin;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
    install -Dm644 ${license} "$out/share/doc/omp/LICENSE"
    install -Dm644 ${notices} "$out/share/doc/omp/THIRD-PARTY-NOTICES.txt"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    actualVersion="$("$out/bin/omp" --version)"
    test "$actualVersion" = "omp/${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Oh My Pi coding agent with built-in subagents and development tools";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = pkgs.lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ];
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
} // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  # The executable and both embedded native addons need only glibc. Patch
  # the ELF interpreter, but keep the embedded Bun application intact.
  dontStrip = true;
})
