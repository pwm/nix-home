function codex --description 'Use the company Codex account'
    set -l codex_profile_home "$HOME/.codex-work"
    command mkdir -p -m 700 "$codex_profile_home"; or return
    command chmod 700 "$codex_profile_home"; or return
    command env CODEX_HOME="$codex_profile_home" codex -c 'cli_auth_credentials_store="file"' $argv
end
