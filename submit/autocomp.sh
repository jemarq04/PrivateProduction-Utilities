function _listsettings {
  [[ ! -f settings.cfg ]] && return

  local valid_years="2022 2022EE 2023 2023BPix 2024"
  local valid_steps="GENSIM HLT RECO MINI NANO"

  local prev="${COMP_WORDS[COMP_CWORD - 1]}"
  case "$prev" in
    -@(y|-year))
      COMPREPLY=( $(compgen -W "$valid_years" -- $2) )
      ;;
    -@(s|-step))
      COMPREPLY=( $(compgen -W "$valid_steps" -- "$2") )
      ;;
    *)
      local settings_list=( $(grep "^\s*\[.*\]\s*$" settings.cfg) )
      local settings_list=(${settings_list[@]##*\[})
      local settings_list=(${settings_list[@]%%\]*})
      local settings_list=(${settings_list[@]/DEFAULT})
      COMPREPLY=( $(compgen -W "${settings_list[*]}" -- $2) )
      ;;
  esac
}
complete -F _listsettings crabSubmit.sh
