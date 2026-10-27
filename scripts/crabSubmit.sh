#!/bin/bash

source $CMSSW_BASE/src/PrivateProduction/Utilities/scripts/BashArgParse.sh
#@opt -h/--help
#@optdesc Print help and exit
#@opt -s/--step
#@optdesc Step for CRAB job submission. Choices: GENSIM, HLT, RECO, MINI, NANO.
#@opt -y/--year
#@optdesc Year for CRAB job submission. Choices: 2022, 2023, 2024.
#@arg name [name ...]
#@argdesc Name(s) of a name in settings.cfg with the desired options for CRAB job

optstring="h/help*,s/step:,y/year:"
utils="${CMSSW_BASE}/src/PrivateProduction/Utilities"
valid_steps="GENSIM HLT RECO MINI NANO"
valid_years="2022 2023 2024"

parse_args "$0" "$optstring" 1 "$@"
eval set -- "$BAP_PARSED"

names="$@"

# Check for settings file
[[ ! -f settings.cfg ]] && die "settings.cfg not found: make sure to run in $utils/submit/"

# Check for valid step
if [[ -n $step ]]; then
  [[ $valid_steps = *$step* ]] || die "invalid step: $step. must be one of $valid_steps"
  sed -i -e "s|^step: .*|step: $step|" settings.cfg
else
  step=$(grep "^step: " settings.cfg | sed -e "s|step: \(.*\)|\1|")
fi

# Check for valid year
if [[ -n $year ]]; then
  [[ $valid_years = *$year* ]] || die "invalid year: $year. must be one of $valid_years"
  sed -i -e "s|^year: .*|year: $year|" settings.cfg
else
  year=$(grep "^year: " settings.cfg | sed -e "s|year: \(.*\)|\1|")
fi

# Submit jobs for each requested section
while [ $# -gt 0 ]; do
  if [[ -z $(grep "^\s*\[$1_$year\]\s*$" settings.cfg) ]]; then
    echo "Section name $1_$year not found"
    shift
    continue
  fi

  sed -i -e "s|^name: .*|name: $1|" settings.cfg
  echo Submitting jobs for $1 for $year with step $step
  crab submit -c $utils/scripts/crab.py
  shift
done
