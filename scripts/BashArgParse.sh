__SCRIPT_PATH=

# === Minimal argument parsing script ===
#
# Usage:
#  To add parsing for your script, first `source` this file
#  and then run `parse_args` to parse and store the command-line
#  variables you specified.
#
#  Example:
#   parse_args "$scriptname" "$optstring" $num_posargs "$@"
#
#  - "$scriptname": The first argument sets the script name, which is used in
#  usage and help printouts. (Most often, this is just "$0")
#  - "$optstring": This argument tells this script how to expect
#  arguments from the command-line. More on this below.
#  - $num_posargs: The number of positional arguments *required* by
#  your script.
#  - "$@": This argument should remain unchanged - this passes all of
#  the command-line arguments to the function to be parsed.
#
# The $optstring parameter
#
#  Arguments should be provided as a comma-separated list of entries of
#  the following form:
#   short/long[*:]
#
#  - short: This is the 'short' option for the argument. Only one alphanumeric character allowed.
#  - long: This is the 'long' option for the argument. Alphanumeric characters and '-' are allowed.
#  - [*:]: These are optional symbols to express properties of the argument. To specify that
#  this argument will print the help message, add '*'. To specify that this argument takes one or more
#  values, add ':'.
#
#  Example
#   'h/help*,/num:'
#
#   This would allow for parsing `SCRIPT -h` or `SCRIPT --num 3`, for example. You don't need to provide
#   both a short and long name, just one will suffice.
#
#  For debugging, you can precede the entire optstring with '*'. To handle all errors yourself, precede the
#  entire optstring with ':'.
#

function print_usage() {
  # Prints usage based on opts/args defined with '#--:' comments
  local opts="[OPTS]"
  local reqopts=$(egrep -i '#@reqopt[[:space:]]' $__SCRIPT_PATH | sed -E 's/^[[:space:]]*#@reqopt[[:space:]]+(.*)/\1/' | xargs)
  [[ -n $reqopts ]] && local opts="$opts $reqopts"
  local args=$(egrep -i '#@arg[[:space:]]' $__SCRIPT_PATH | sed -E 's/^[[:space:]]*#@arg[[:space:]]+(.*)/\1/' | xargs)
  echo "usage: $__SCRIPT_PATH $opts $args"
}

function print_help() {
  # Prints help based on opts/args defined with '#--:' comments
  local desc=$(egrep -i '#@desc' $__SCRIPT_PATH | sed -E 's/^[[:space:]]*#@desc[[:space:]]+(.*)/\1/')
  local optshelp=$(egrep -i '#@(req)?opt' $__SCRIPT_PATH | sed -E 's/^[[:space:]]*#@(req)?optdesc[[:space:]]+(.*)/   \2\n/' | sed -E 's/^[[:space:]]*#@(req)?opt[[:space:]]+(.*)/ \2/')
  local argshelp=$(egrep -i '#@arg' $__SCRIPT_PATH | sed -E 's/^[[:space:]]*#@argdesc[[:space:]]+(.*)/   \1\n/' | sed -E 's/^[[:space:]]*#@arg[[:space:]]+(.*)/ \1/')

  print_usage
  if [[ -n $desc ]]; then
    echo
    echo $desc
  fi
  if [[ -n $optshelp ]]; then
    echo
    echo OPTS
    echo "$optshelp"
  fi
  if [[ -n $argshelp ]]; then
    echo
    echo ARGS
    echo "$argshelp"
  fi
  exit 1
}

function die() {
  print_usage >&2
  [[ -z $1 ]] && local message="unknown error" || local message="$1"
  echo "error: $message" >&2
  exit 1
}

function check_valid_option() {
  # check_valid_option NAME OPTION [OPTION ...]
  name="$1"
  shift
  local options=("$@")
  [[ " ${options[*]} " =~ [[:space:]]${!name}[[:space:]] ]] || die "invalid $name: ${!name}. must be one of ${options[*]}"
}

function parse_args() {
  # parse_args SCRIPT_PATH OPTSTRING NUM_POSARGS "$@"
  local silent=false
  local debug=false

  __SCRIPT_PATH="$1"
  local fulloptstring="$2"
  local num_posargs="$3"
  shift 3

  if [[ $fulloptstring = :* ]]; then
    local fulloptstring="${fulloptstring#:}"
    local silent=true
  elif [[ $fulloptstring = \** ]]; then
    local fulloptstring="${fulloptstring#?}"
    local debug=true
  fi

  # Determine optstring and long optstring for getopt command
  local optstring=":"
  local loptstring=""
  local fullopts=(${fulloptstring//,/ })
  for fullopt in "${fullopts[@]}"; do
    local shortopt=$(cut -d / -f 1 <<<$fullopt)
    local longopt=$(cut -d / -f 2 <<<$fullopt)
    [[ $shortopt = $longopt ]] && unset longopt

    [[ -n $longopt && -n $shortopt && ${fullopt: -1} = ":" ]] && local shortopt="$shortopt:" && [[ ${fullopt: -2:1} = ":" ]] && local shortopt="$shortopt:"
    [[ ${longopt: -1} = "*" ]] && local longopt="${longopt%?}"

    [[ -n $shortopt ]] && local optstring="$optstring$shortopt"
    [[ -n $longopt ]] && local loptstring="$loptstring,$longopt"
  done

  # Call getopt command
  $debug && echo "getopt -n $__SCRIPT_PATH -o $optstring --long ${loptstring#,} -- $@"
  local parsed=$(getopt -n $__SCRIPT_PATH -o $optstring --long ${loptstring#,} -- "$@")
  [[ $? -ne 0 ]] && $silent && echo && die "failed to parse arguments"
  eval set -- "$parsed"

  # Parse variables from getopt
  while true; do
    local found=false

    for fullopt in "${fullopts[@]}"; do
      local has_val=false
      local is_help=false
      [[ ${fullopt: -1} = ":" ]] && local has_val=true && local fullopt="${fullopt%%:*}"
      [[ ${fullopt: -1} = "*" ]] && local is_help=true && local fullopt="${fullopt%?}"

      # Get short and long option name
      local shortopt=$(cut -d / -f 1 <<<$fullopt)
      local longopt=$(cut -d / -f 2 <<<$fullopt)
      local name="${longopt//-/_}"
      [[ -z $name ]] && local name="${shortopt}_arg"

      # Set default
      if ! $has_val && [[ -z ${!name} ]]; then
        printf -v "$name" "%s" "false"
        export $name
        $debug && echo "Set default variable $name=${!name}"
      fi

      # Check argument for this option
      if [[ -n $shortopt && $1 = -$shortopt ]] || [[ -n $longopt && $1 = --$longopt ]]; then
        $is_help && print_help

        # Save value to variable
        local found=true
        if $has_val; then
          printf -v "$name" "%s" "$2"
          shift
        else
          printf -v "$name" "%s" "true"
        fi
        export $name
        $debug && echo "Set variable $name=${!name}"

        shift
        break
      fi
    done
    $found && continue

    if [[ $1 = "--" ]]; then
      shift
      break
    else
      break
    fi
  done

  # Check positional arguments
  ! $silent && [[ $# -lt $num_posargs ]] && die "not enough arguments"

  # Save remaining arguments
  PARSED="$@"
  $debug && echo "Set remaining variables PARSED=$PARSED"
}
