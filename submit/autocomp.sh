function _listsettings {
  [[ ! -f settings.cfg ]] && return

  local valid_years="2022 2022EE 2023 2023BPix 2024"
  local valid_steps="NANOGEN GENSIM HLT RECO MINI NANO"
  local valid_opts="-h --help -y --year -s --step"

  local cur="$2"
  local prev="$3"
  case "$prev" in
  -@(y|-year))
    COMPREPLY=($(compgen -W "$valid_years" -- "$cur"))
    ;;
  -@(s|-step))
    COMPREPLY=($(compgen -W "$valid_steps" -- "$cur"))
    ;;
  *)
    case "$cur" in
    -*)
      COMPREPLY=($(compgen -W "$valid_opts" -- "$cur"))
      ;;
    *)
      local settings_list=($(grep "^\s*\[.*\]\s*$" settings.cfg))
      local settings_list=(${settings_list[@]##*\[})
      local settings_list=(${settings_list[@]%%\]*})
      local settings_list=(${settings_list[@]/DEFAULT/})
      local settings_list=(${settings_list[@]%_[0-9]*})
      COMPREPLY=($(compgen -W "${settings_list[*]}" -- "$cur"))
      ;;
    esac
    ;;
  esac
}
complete -F _listsettings crabSubmit.sh
