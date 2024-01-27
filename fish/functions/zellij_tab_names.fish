function zellij_tab_names --on-variable PWD
    if set -q ZELLIJ
        set tab_name ''
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set git_root (basename (git rev-parse --show-toplevel))
            set git_prefix (git rev-parse --show-prefix)
            set tab_name "$git_root/$git_prefix"
            set tab_name (string trim -c / "$tab_name") # Remove trailing slash
        else
            set tab_name $PWD
            if test "$tab_name" = "$HOME"
                set tab_name "~"
            else
                set tab_name (basename "$tab_name")
            end
        end
        command nohup zellij action rename-tab $tab_name >/dev/null 2>&1 &
    end
end
