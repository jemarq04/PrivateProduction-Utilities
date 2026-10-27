#!/bin/bash

source $CMSSW_BASE/src/PrivateProduction/Utilities/scripts/BashArgParse.sh
#@opt -h/--help
#@optdesc Print help and exit
#@opt -s/--steps "STEP [STEP ...]"
#@optdesc Step(s) for CMS config files or 'all' to generate files for each step (default: all)
#@arg year
#@argdesc Year to generate CMS config files for with cmsDriver.py
#@arg [name ...]
#@argdesc Identifier(s) for dataset (e.g. TTZ). Fragments follow the name "NAME_YEAR-fragment.py". By default, all names found with the given year are used.

# Set default values
optstring="h/help*,s/steps:"
utils="${CMSSW_BASE}/src/PrivateProduction/Utilities"
valid_steps="GENSIM HLT RECO MINI NANO"
valid_years="2022 2023 2024"
steps="$valid_steps"

# Parse arguments
parse_args "$0" "$optstring" 1 "$@"
eval set -- "$BAP_PARSED"

year="$1"
shift
names="$@"

# Check for valid steps
[[ $steps = all ]] && steps="$valid_steps"
[[ $valid_steps = *$steps* ]] || die "invalid steps: $steps. must be one of $valid_steps"

# Check for valid year
[[ $valid_years = *$year* ]] || die "invalid year: $year. must be one of $valid_years"

# Set names
names="$@"
if [[ -z $names ]]; then
  names=($utils/python/*_$year-fragment.py)
  names=(${names[@]##*\/})
  names=(${names[@]%%_$year-fragment.py})
fi

# Set options based on year
nThreads=4
beamspot=DBrealistic
if [[ $year = 2024 ]]; then
  era=Run3_2024
  conditions=140X_mcRun3_2024_realistic_v26
  newconditions=150X_mcRun3_2024_realistic_v2
  pileup="dbs:/Neutrino_E-10_gun/RunIIISummer24PrePremix-Premixlib2024_140X_mcRun3_2024_realistic_v26-v1/PREMIX"
else
  die "Only 2024 options are available - add more options if needed"
fi

# Create CMS files for each input/step
for name in ${names[@]}; do
  fragment="$utils/python/${name}_${year}-fragment.py"

  # Check name
  [[ ! -f $fragment ]] && echo && echo "WARNING: No fragment exists for $name. Make sure there isn't a typo!"
  echo
  echo "Generating cards for $name (steps: $steps)"
  for step in $steps; do
    echo "=====> Generating step $step"
    if [[ $step = GENSIM ]]; then
      outname=GENSIM-${name}_${year}
      cmsDriver.py ${fragment##*src/} --fileout file:$outname.root --mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE --conditions $conditions --beamspot $beamspot --step LHE,GEN,SIM --geometry DB:Extended --era $era --no_exec --python_filename=$utils/inputs/$outname.py --nThreads $nThreads &&
        sed -i -e "s/^process.LHEoutput_step/#process.LHEoutput_step/" $utils/inputs/$outname.py &&
        sed -i -e "s/,process.LHEoutput_step)/) #process.LHEoutput_step)/" $utils/inputs/$outname.py

    elif [[ $step = HLT ]]; then
      outname=HLT-${name}_${year}
      cmsDriver.py step1 --fileout file:$outname.root --pileup_input "$pileup" --mc --eventcontent PREMIXRAW --datatier GEN-SIM-RAW --conditions $conditions --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2024v14 --geometry DB:Extended --datamix PreMix --era $era --procModifiers premix_stage2 --no_exec --python_filename=${utils}/inputs/$outname.py --nThreads $nThreads

    elif [[ $step = RECO ]]; then
      outname=RECO-${name}_${year}
      cmsDriver.py step2 --fileout file:$outname.root --mc --eventcontent AODSIM --datatier AODSIM --conditions $conditions --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --era $era --no_exec --python_filename=${utils}/inputs/$outname.py --nThreads $nThreads

    elif [[ $step = MINI ]]; then
      eventcontent=MINIAODSIM
      tempconditions=$conditions
      [[ $year = 2024 ]] && eventcontent=MINIAODSIM1 && tempconditions=$newconditions

      outname=MINI-${name}_${year}
      cmsDriver.py step3 --fileout file:$outname.root --mc --eventcontent $eventcontent --datatier MINIAODSIM --conditions $tempconditions --step PAT --geometry DB:Extended --era $era --no_exec --python_filename=${utils}/inputs/$outname.py --nThreads $nThreads

    elif [[ $step = NANO ]]; then
      eventcontent=NANOEDMAODSIM
      [[ $year = 2024 ]] && eventcontent=NANOEDMAODSIM1 && tempconditions=$newconditions

      outname=NANO-${name}_${year}
      cmsDriver.py step4 --fileout file:$outname.root --mc --eventcontent $eventcontent --datatier NANOAODSIM --conditions $tempconditions --step NANO --scenario pp --era $era --nThreads $nThreads
    else
      die "unknown step $step"
    fi
  done
done
