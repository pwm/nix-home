{ pkgs }:
let
  solarized-osaka = pkgs.vimUtils.buildVimPlugin {
    pname = "solarized-osaka";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/craftzdog/solarized-osaka.nvim.git";
      rev = "f6e66670e31c09cfb7142a16d5dc2f26d2a31a40";
      sha256 = "mX55sCnfMYs6owU54/1AdyJ2EVrE5gR9ubqRCHgf10c=";
    };
  };
  kanagawa = pkgs.vimUtils.buildVimPlugin {
    pname = "kanagawa";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/rebelot/kanagawa.nvim.git";
      rev = "c19b9023842697ec92caf72cd3599f7dd7be4456";
      sha256 = "pbLcomZHzC2JGKF4oII6AAm5q/dzQtNfFAZVNX74nB8=";
    };
  };
  nordic = pkgs.vimUtils.buildVimPlugin {
    pname = "nordic";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/AlexvZyl/nordic.nvim.git";
      rev = "36f6edce282266996239043a969df1a7cacbe68d";
      sha256 = "B9O4GfxllQDbdY3Lp4QEEf/mzF3QdVUxGnSdp+b083g=";
    };
  };
  moonfly = pkgs.vimUtils.buildVimPlugin {
    pname = "moonfly";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/bluz71/vim-moonfly-colors";
      rev = "a1a0dfc621f41ffb4e98a813e021ba41e8199adc";
      sha256 = "wrE6IdTE4ImkhvWDwFhUilMNdx0MWrFJDr8+71A2RHE=";
    };
  };
  oxocarbon = pkgs.vimUtils.buildVimPlugin {
    pname = "oxocarbon";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/nyoom-engineering/oxocarbon.nvim";
      rev = "c5846d10cbe4131cc5e32c6d00beaf59cb60f6a2";
      sha256 = "++JALLPklok9VY2ChOddTYDvDNVadmCeB98jCAJYCZ0=";
    };
  };
  gruvbox = pkgs.vimUtils.buildVimPlugin {
    pname = "gruvbox";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/ellisonleao/gruvbox.nvim";
      rev = "6e4027ae957cddf7b193adfaec4a8f9e03b4555f";
      sha256 = "jWnrRy/PT7D0UcPGL+XTbKHWvS0ixvbyqPtTzG9HY84=";
    };
  };
  vscode = pkgs.vimUtils.buildVimPlugin {
    pname = "vscode";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/Mofiqul/vscode.nvim";
      rev = "380c1068612b1bfbe35d70a4f2e58be5030a0707";
      sha256 = "dAZy4XWGljMn+FwvkZSHCL1neGRPLHVn/L0jSLmRAdM=";
    };
  };
  tokyonight = pkgs.vimUtils.buildVimPlugin {
    pname = "tokyonight";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/folke/tokyonight.nvim";
      rev = "610179f7f12db3d08540b6cc61434db2eaecbcff";
      sha256 = "mzCdcf7FINhhVLUIPv/eLohm4qMG9ndRJ5H4sFU2vO0=";
    };
  };
  midnight = pkgs.vimUtils.buildVimPlugin {
    pname = "midnight";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/dasupradyumna/midnight.nvim";
      rev = "13d812355db1e535ba5c790186d301e1fe9e7e1b";
      sha256 = "EB+FplD/Y3vLVXhZBIbWrNnSfNs2XqjI/8ROwuWO3Po=";
    };
  };
  mellifluous = pkgs.vimUtils.buildVimPlugin {
    pname = "mellifluous";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/ramojus/mellifluous.nvim";
      rev = "da719202489e37e3d5de29b5a0d650fa7f980cfd";
      sha256 = "2oxKAHH5dkx2hRdjxBN2utnk23X9Or0LpFVxVjK+n/0=";
    };
  };
  aurora = pkgs.vimUtils.buildVimPlugin {
    pname = "aurora";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/ray-x/aurora";
      rev = "6157dffe86f20d891df723c0c6734676295b01e0";
      sha256 = "WTYK1JCb/8DpljwKhoRjlI1lkY3IXs5BXd45AswNeWs=";
    };
  };
  citruszest = pkgs.vimUtils.buildVimPlugin {
    pname = "citruszest";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/zootedb0t/citruszest.nvim";
      rev = "6c090d537c4fcc5d187632e7e47943e41a218ba8";
      sha256 = "LCIcudEAPlSA1VPJEvtSZqIM4E2GApKXr84McsJ/CXQ=";
    };
  };
  github = pkgs.vimUtils.buildVimPlugin {
    pname = "github";
    version = "2024-02-02";
    src = pkgs.fetchgit {
      url = "https://github.com/projekt0n/github-nvim-theme";
      rev = "d92e1143e5aaa0d7df28a26dd8ee2102df2cadd8";
      sha256 = "FO4mwRY2qjutjVTiW0wN5KVhuoBZmycfOwMFInaTnNo=";
    };
  };
in
[
  solarized-osaka
  kanagawa
  nordic
  moonfly
  oxocarbon
  gruvbox
  vscode
  tokyonight
  midnight
  mellifluous
  aurora
  citruszest
  github
]
