# PrivateProduction/Utilities

This is a CMSSW package to help submit CRAB jobs for private production.

## Setup

To get started, work in a `CMSSW_15_X_Y` release (e.g. `CMSSW_15_0_19`) and activate
the environment. If you need to recreate the environment, you can run

```bash
cmsrel CMSSW_15_0_19
cd CMSSW_15_0_19/src
cmsenv
```

To download the package and set it up, run

```bash
git clone git@github.com:jemarq04/PrivateProduction-Utilities PrivateProduction/Utilities
scram build -j12
cd PrivateProduction/Utilities
cp submit/settings_template.cfg submit/settings.cfg
```

## Adding new fragments

If you want to add new CMS config fragment, just copy and paste it into
`PrivateProduction/Utilities/python`. Whenever you add any fragments, make sure
to re-compile with `scram build -j12`. This will register the fragment for CMSSW.

Make sure that the name of the fragment matches the form
`<NAME>_<YEAR>-fragment.py`, where `<NAME>` is any identifier for your dataset.
For example, you could add `WZpol_2024-fragment.py`.

## Creating config files (running cmsDriver.py)

To create the config files you need, you can use the `prepareCMSSW.sh` helper
script. Since you have compiled the package, just run `prepareCMSSW.sh --help`
to get a help printout explaining how to use the script. To generate config
files for all steps for 'WZpol' in 2024, for example, you would run
`prepareCMSSW.sh 2024 WZpol`.

## Submitting jobs and generating events

Before you submit the jobs to CRAB, `cd` into
`PrivateProduction/Utilities/submit`. To submit jobs, you can use the
`crabSubmit.sh` helper script. Once again, to get a help printout, just run
`crabSubmit.sh --help`. This script will read the options set in
`submit/settings.cfg` to submit the CRAB jobs you need. To edit which job is
submitted (i.e. which dataset/year/step), edit those three fields before running
`crabSubmit.sh` Alternatively, you can use the `--year` and `--step` options in
the script to specify them in the command-line. However, the relevant section
needs to exist first. For example, to submit GENSIM
jobs for 'WZpol' you would run `crabSubmit.sh -y 2024 -s GENSIM WZpol`. Before
running this, the section "WZpol_2024" should be added like the following:

```cfg
# This is an example section in settings.cfg
[WZpol_2024]
GENSIMDataset:
HLTDataset:
RECODataset:
```

The "general options" dictate how the jobs and output directories are named for
the jobs, and for the most part can be left alone. The "job options" determine
the memory per core for the jobs as well as some configuration for the GENSIM
step regarding the number of jobs and events per job. You can always start these
lower to test it works.

Each step will be published to a "USER" area, which allows you to use that
dataset as the input dataset for the next step. For example, once you've
submitted a GENSIM job you can get the name of the output dataset with `crab
status -d <CRAB_DIR>`. This dataset name will end in "USER" (instead of the
usual "GENSIM"). Copy this and add it to the "GENSIMDataset" option in
`settings.cfg`.

### Tab-completion with crabSubmit.sh

There is also a bash script that will add tab-completion to the `crabSubmit.sh`
script. To activate it, run

```bash
source $CMSSW_BASE/src/PrivateProduction/Utilities/submit/autocomp.sh
```

You'll need to run this each time you log in to the server and activate this
environment to benefit from the tab-completion.
