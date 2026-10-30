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
valid_steps=(NANOGEN GENSIM HLT RECO MINI NANO)
valid_years=(2022 2022EE 2023 2023BPix 2024)
steps="all"

# Parse arguments
parse_args "$0" "$optstring" 1 "$@"
eval set -- "$BAP_PARSED"

year="$1"
shift
names="$@"

# Check for valid steps
[[ $steps = all ]] && steps="${valid_steps[*]}"
for step in $steps; do
  [[ " ${valid_steps[*]} " =~ [[:space:]]$step[[:space:]] ]] || die "invalid step: $step. must be one of ${valid_steps[*]}"
done

# Check for valid year
[[ " ${valid_years[*]} " =~ [[:space:]]$year[[:space:]] ]] || die "invalid year: $year. must be one of ${valid_years[*]}"

# Set names
names="$@"
if [[ -z $names ]]; then
  names=($utils/python/*_$year-fragment.py)
  names=(${names[@]##*\/})
  names=(${names[@]%%_$year-fragment.py})
fi

# Set options based on year
nThreads=4
mini_eventcontent=MINIAODSIM
nano_eventcontent=NANOEDMAODSIM
if [[ $year = 2022 ]]; then
  era=Run3
  mini_era="$era,run3_miniAOD_12X"
  nano_era=$era
  beamspot=Realistic25ns13p6TeVEarly2022Collision
  conditions=124X_mcRun3_2022_realistic_v12
  mini_conditions=130X_mcRun3_2022_realistic_v5
  nano_conditions=$mini_conditions
  pileup="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"
  procModifiers="premix_stage2,siPixelQualityRawToDigi"
  HLT="2022v12"

  reco_extra="--procModifiers siPixelQualityRawToDigi"
elif [[ $year = 2022EE ]]; then
  era=Run3
  mini_era="$era,run3_miniAOD_12X"
  nano_era=$era
  beamspot=Realistic25ns13p6TeVEarly2022Collision
  conditions=124X_mcRun3_2022_realistic_postEE_v1
  mini_conditions=130X_mcRun3_2022_realistic_postEE_v6
  nano_conditions=$mini_conditions
  pileup="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX"
  procModifiers="premix_stage2,siPixelQualityRawToDigi"
  HLT="2022v14"

  reco_extra="--procModifiers siPixelQualityRawToDigi"
elif [[ $year = 2023 ]]; then
  era=Run3_2023
  mini_era=$era
  nano_era=$era
  beamspot=Realistic25ns13p6TeVEarly2023Collision
  conditions=130X_mcRun3_2023_realistic_v14
  mini_conditions=$conditions
  nano_conditions=$mini_conditions
  pileup="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23_130X_mcRun3_2023_realistic_v13-v1/PREMIX"
  procModifiers="premix_stage2"
  HLT="2023v12"
elif [[ $year = 2023BPix ]]; then
  era=Run3_2023
  mini_era=$era
  nano_era=$era
  beamspot=Realistic25ns13p6TeVEarly2023Collision
  conditions=130X_mcRun3_2023_realistic_postBPix_v2
  mini_conditions=$conditions
  nano_conditions=$mini_conditions
  pileup="dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer23BPix_130X_mcRun3_2023_realistic_postBPix_v1-v1/PREMIX"
  procModifiers="premix_stage2"
  HLT="2023v12"
elif [[ $year = 2024 ]]; then
  era=Run3_2024
  beamspot=DBrealistic
  conditions=140X_mcRun3_2024_realistic_v26
  mini_conditions=150X_mcRun3_2024_realistic_v2
  nano_conditions=$mini_conditions
  pileup="dbs:/Neutrino_E-10_gun/RunIIISummer24PrePremix-Premixlib2024_140X_mcRun3_2024_realistic_v26-v1/PREMIX"
  procModifiers="premix_stage2"
  HLT="2024v14"

  mini_eventcontent=MINIAODSIM1
  nano_eventcontent=NANOEDMAODSIM1
else
  die "Only 2024 options are available - add more options if needed"
fi

# Create CMS files for each input/step
mkdir -p $utils/inputs
for name in ${names[@]}; do
  fragment="$utils/python/${name}_${year}-fragment.py"

  # Check name
  [[ ! -f $fragment ]] && echo && echo "WARNING: No fragment exists for $name. Make sure there isn't a typo!"
  echo
  echo "Generating cards for $name (steps: $steps)"
  for step in $steps; do
    echo "=====> Generating step $step"
    if [[ $step = NANOGEN ]]; then
      eventcontent=NANOAOD
      nanogen="NANO:@GEN"
      if echo -e "$(cut -d _ -f 1-4 <<<${CMSSW_VERSION#CMSSW_})\n14_1_0_pre5" | sort -C -V; then
        # This version uses the old NANOGEN syntax
        eventcontent=NANOAODGEN
        nanogen=NANOAOD
      fi

      outname=NANOGEN-${name}_${year}
      cmsDriver.py ${fragment##*src/} --fileout file:$outname.root --mc --eventcontent $eventcontent --datatier NANOAODSIM --conditions $conditions --beamspot $beamspot --step LHE,GEN,$nanogen --geometry DB:Extended --era $era --no_exec --python_filename=$utils/inputs/$outname.py --nThreads $nThreads ||
        die "failed to generate NANOGEN config file"

    elif [[ $step = GENSIM ]]; then
      outname=GENSIM-${name}_${year}
      (cmsDriver.py ${fragment##*src/} --fileout file:$outname.root --mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE --conditions $conditions --beamspot $beamspot --step LHE,GEN,SIM --geometry DB:Extended --era $era --no_exec --python_filename=$utils/inputs/$outname.py --nThreads $nThreads &&
        sed -i -e "s/^process.LHEoutput_step/#process.LHEoutput_step/" $utils/inputs/$outname.py &&
        sed -i -e "s/,process.LHEoutput_step)/) #process.LHEoutput_step)/" $utils/inputs/$outname.py) ||
        die "failed to generate GENSIM config file"

    elif [[ $step = HLT ]]; then
      outname=HLT-${name}_${year}
      cmsDriver.py step1 --fileout file:$outname.root --pileup_input "$pileup" --mc --eventcontent PREMIXRAW --datatier GEN-SIM-RAW --conditions $conditions --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:$HLT --geometry DB:Extended --datamix PreMix --era $era --procModifiers $procModifiers --no_exec --python_filename=${utils}/inputs/$outname.py --nThreads $nThreads ||
        die "failed to generate HLT config file"

    elif [[ $step = RECO ]]; then
      outname=RECO-${name}_${year}
      cmsDriver.py step2 --fileout file:$outname.root --mc --eventcontent AODSIM --datatier AODSIM --conditions $conditions --step RAW2DIGI,L1Reco,RECO,RECOSIM --geometry DB:Extended --era $era --no_exec --python_filename=${utils}/inputs/$outname.py $reco_extra --nThreads $nThreads ||
        die "failed to generate RECO config file"

    elif [[ $step = MINI ]]; then
      outname=MINI-${name}_${year}
      cmsDriver.py step3 --fileout file:$outname.root --mc --eventcontent $mini_eventcontent --datatier MINIAODSIM --conditions $mini_conditions --step PAT --geometry DB:Extended --era $mini_era --no_exec --python_filename=${utils}/inputs/$outname.py --nThreads $nThreads ||
        die "failed to generate MINI config file"

    elif [[ $step = NANO ]]; then
      outname=NANO-${name}_${year}
      cmsDriver.py step4 --fileout file:$outname.root --mc --eventcontent $nano_eventcontent --datatier NANOAODSIM --conditions $nano_conditions --step NANO --scenario pp --era $nano_era --nThreads $nThreads ||
        die "failed to generate NANO config file"
    else
      die "unknown step $step"
    fi
  done
done
