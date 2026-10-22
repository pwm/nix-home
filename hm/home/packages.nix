{ pkgs, desktop }:
with pkgs; [
  _1password-cli
  awscli
  bash
  bat
  bun
  cachix
  claude-code
  codex
  csvlens
  curl
  delta
  difftastic
  direnv
  dust
  duckdb
  eza
  fastgron
  fd
  # File search MCP server (dmtrKovalenko/fff). Register it once with:
  #   claude mcp add -s user fff -- ~/.nix-profile/bin/fff-mcp --no-update-check
  # ~/.claude.json holds that registration and cannot be managed here, as
  # Claude Code rewrites it at runtime. NB nixpkgs `fff` is an unrelated project.
  fff-mcp
  ffmpeg
  fish
  fontconfig
  fzf
  fzy
  gh
  git
  gnupg
  graph-easy
  graphviz
  htop
  # neofetch was removed from nixpkgs, hyfetch's neowofetch is its maintained fork
  hyfetch
  hyperfine
  imagemagick
  inetutils
  innoextract
  irssi
  jdk
  jq
  librsvg
  litellm
  lua
  lftp
  miller
  nil
  nix-diff
  nix-prefetch-git
  nix-tree
  omp
  openssl
  otel-cli
  pi-coding-agent
  qemu
  p7zip
  pandoc
  pstree
  pwgen
  # macOS's /usr/bin/python3 is 3.9; devserver/migrate/codex.sh needs tomllib (3.11+)
  python3
  qpdf
  restish
  ripgrep
  scc
  sd
  shellcheck
  sops
  termshark
  tesseract
  tig
  tldr
  tokei
  tree
  wget
  yq-go
  yt-dlp
  zellij
  zenith
] ++ lib.optionals stdenv.hostPlatform.isDarwin [
  # Linux keeps the distribution's ssh: it matches /etc/ssh/ssh_config (nixpkgs'
  # openssh warns on every connection about Ubuntu's GSSAPIAuthentication) and
  # gets the distribution's security updates
  openssh
] ++ lib.optionals desktop [
  fira-code
  fira-code-symbols
  inkscape
  sqlitebrowser
  vscode
]
