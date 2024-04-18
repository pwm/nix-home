zellij ls | grep 'EXITED' | awk '{print $1}' | while read session
  echo $session
  # zellij k $session
end


zellij ls | grep 'EXITED' | awk '{print $1}' | while read session; echo $session; end
