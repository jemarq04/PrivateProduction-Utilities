# PrivateProduction/Utilities

This is a CMSSW package to help submit CRAB jobs for private production.

## Setup

To get started, work in a CMSSW environment (e.g. `CMSSW_15_0_19`) and activate
the environment.

I would recommend working in a fresh environment in some directory you create
for organization, as you may need several CMSSW environments to get these jobs
submitted. For example, creating different CMSSW environments in some
`private-production` directory in your home directory. For creating a new one,
you can use the following example.

```bash
# cd private-production
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

When switching between environments, you need to deactivate the CMSSW
environment. For some reason, this is not set as an alias by default! When you
want to deactivate your environment, run the following command.

```bash
eval `scram unsetenv -sh`
```

As a tip, you can add an alias to this in your `~/.bashrc` file so that you can
run this more easily. To do this, add the following line to your `~/.bashrc` file.

```bash
alias uncmsenv='eval `scram unsetenv -sh`'
```

### Setting up a fork of this package

It might be easier to create a fork of this repository so you can more easily
transfer changes and config files between your CMSSW environments. Fork the
repository through GitHub and then follow the setup instructions above, but
replace `jemarq04` with your GitHub username. To still have access to any
changes/fixes implemented from here, add this as an "upstream" repository by
running the following command.

```bash
git remote add upstream git@github.com:jemarq04/PrivateProduction-Utilities
```

Then, when you want updates from this repository, just run `git pull upstream
main` to pull changes from this main branch to your current working branch.

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
files for the GENSIM and HLT steps for 'WZpol' in 2024, for example, you would run
`prepareCMSSW.sh -s "GENSIM HLT" 2024 WZpol`. The quotation marks are important
for the script to recognize multiple steps.

Note that different steps may require different CMSSW releases! For example, the
`HLT:2024_v14` step does not exist in `CMSSW_15_X_Y`, but is part of the
standard process for 2024 MC. You'll need two different CMSSW releases to submit
those jobs. Other years have similar restrictions.

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
running this, the section `WZpol_2024` should be added like the following:

```cfg
# This is an example section in settings.cfg
[WZpol_2024]
GENSIMDataset:
HLTDataset:
RECODataset:
MINIDataset:
```

These sections are the outputs from the CRAB jobs to help each job run in
sequence. For example, the "GENSIMDataset" field would be the DAS identifier for
the output from your GENSIM CRAB jobs. That way, when you submit HLT jobs, the
package knows what to use as the input dataset.

Instead of using any command-line options to specify the year/step/name, you
can edit all of these values manually in `submit/settings.cfg` and then simply
run `crabSubmit.sh` with no arguments. The script will submit CRAB jobs based
on the information already present in the settings file.

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
`settings.cfg`. Then it can be retrieved as the input dataset for the next set
of CRAB jobs.

### Tips with CRAB jobs

After submitting your job with `crabSubmit.sh`, there are some helpful commands
available to you.

- `crab status -d <DIR>`: This lets you get the status of your jobs. Idle jobs
are pending and are waiting for resources to be free to run. Transferring jobs
have finished and are in the "post-processing" stage, often waiting to establish
a connection with your desired output storage. Removed jobs often exceeded
limitations (e.g. memory) and were killed, but these are often automatically
re-submitted by CRAB to try again. If you have any failing jobs, you can view
more information using the `--verboseErrors` flag when you run this command.
It'll print a bit of its message and the error code, which you can look up.
  - The status printout also gives some helpful links and information. The
  "dashboard monitoring" page is a great way to visually check on your jobs'
  statuses. You can even set a refresh rate at the top right. There should also
  be information about the "published" dataset, which a DAS identifier for your
  output dataset from these jobs. This dataset can be found through the CMS DAS
  service and then used as an input dataset for other jobs (handled by this
  package).
- `crab resubmit -d <DIR>`: This lets you resubmit any failed jobs. Sometimes, a
job gets caught trying to access remote files or maybe there's an odd memory bug
that comes up sometimes, affecting your jobs. These may not be automatically
re-run by CRAB, so you need to request it with the `resubmit` subcommand. These
jobs are already at the maximum (2GB) for multi-threaded requests, but you can
always request more time on resubmissions with `--maxjobruntime` (in minutes).
- `crab report -d <DIR>`: This gives you a report on your submitted jobs
(generally done when the jobs are finished or consistently failing). If
everything finished successfully, this isn't too helpful with MC. With data, it
can tell you what lumi sections were processed. If there were any jobs that kept
failing, this will create a `failedFiles.json` file in `<DIR>/results/` that
will tell you which job ID failed and which files it attempted to process.
- `crab kill -d <DIR>`: This stops the jobs from running -- mostly helpful if
you notice something wrong with the job itself and you know they'll eventually fail.

Some helpful CRAB pages to bookmark:

- [CRAB file configurations](https://twiki.cern.ch/twiki/bin/view/CMSPublic/CRAB3ConfigurationFile):
Describes the configurations used in `scripts/crab.py`.
- [General guide for CRAB](https://twiki.cern.ch/twiki/bin/view/CMSPublic/SWGuideCrab)

### Submitting jobs with custom gridpacks

If you need to use a custom gridpack and not one that is centrally available on
`/cvmfs`, then you can copy your gridpack to the HDFS storage and access it via
`xrootd`. For the UW HDFS storage, you would write the path
`/hdfs/store/user/<USER>/mypath` as
`root://cmsxrootd.hep.wisc.edu:1094/store/user/<USER>/mypath`. To be able to
access the file, make sure the `scriptName` parameter for the
ExternalLHEProducer in your desired fragment uses
`GeneratorInterface/LHEInterface/data/run_generic_tarball_xrootd.sh`.

### Tab-completion with crabSubmit.sh

There is also a bash script that will add tab-completion to the `crabSubmit.sh`
script. To activate it, run

```bash
source $CMSSW_BASE/src/PrivateProduction/Utilities/submit/autocomp.sh
```

You'll need to run this each time you log in to the server and activate this
environment to benefit from the tab-completion.
