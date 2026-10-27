function _listsettings {
  [[ ! -f settings.cfg ]] && return
  local settings_list=( $(grep "^\s*\[.*\]\s*$" settings.cfg) )
  local settings_list=(${settings_list[@]##*\[})
  local settings_list=(${settings_list[@]%%\]*})
  local settings_list=(${settings_list[@]/DEFAULT})
  COMPREPLY=( $(compgen -W "${settings_list[*]}" -- $2) )
}
complete -F _listsettings crabSubmit.sh
