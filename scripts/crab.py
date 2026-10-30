import configparser
import os
import sys
from datetime import datetime

# Import user configurations
settings = configparser.ConfigParser()
if not os.path.isfile("settings.cfg"):
    print("error: file not found: settings.cfg")
    sys.exit(1)
settings.read("settings.cfg")
sectionSettings = settings[settings.get("DEFAULT", "name") + "_" + settings.get("DEFAULT", "year")]

jobAttempt = 1
requestName = f"{sectionSettings['requestName']}_{jobAttempt}"
while os.path.isdir(f"crab_{requestName}"):
    jobAttempt += 1
    requestName = f"{sectionSettings['requestName']}_{jobAttempt}"
if sectionSettings.getboolean("appendDate"):
    requestName += f"{datetime.now():%d%b%Y}"

VALID_STEPS = ["NANOGEN", "GENSIM", "HLT", "RECO", "MINI", "NANO"]
if sectionSettings["step"] not in VALID_STEPS:
    print("error: invalid step:", sectionSettings["step"])
    print(" valid steps:", ",".join(VALID_STEPS))
    sys.exit(1)
prev_step = VALID_STEPS.index(sectionSettings["step"]) - 1

is_gen = sectionSettings["step"] in ["NANOGEN", "GENSIM"]

# Print statements
print(f"Submitting {requestName}")
print(f"  step: {sectionSettings['step']}")
prev_input = ""
if not is_gen:
    prev_input = sectionSettings[VALID_STEPS[prev_step] + "Dataset"]
    if prev_input == "":
        print(f"error: empty input dataset for {VALID_STEPS[prev_step]}Dataset")
        sys.exit(1)
    print(f"  input: {prev_input}")

# Initialize CRAB config
from CRABClient.UserUtilities import config

config = config()

config.General.requestName = requestName
config.General.workArea = "."
config.General.transferOutputs = True
config.General.transferLogs = True

if is_gen:
    config.JobType.pluginName = "PrivateMC"
else:
    config.JobType.pluginName = "Analysis"
config.JobType.numCores = 4
config.JobType.maxMemoryMB = config.JobType.numCores * int(sectionSettings["memoryPerCore"])
config.JobType.psetName = f"{os.environ['CMSSW_BASE']}/src/{sectionSettings['psetName']}"
config.JobType.allowUndistributedCMSSW = True

if is_gen:
    config.Data.splitting = "EventBased"
    config.Data.unitsPerJob = int(sectionSettings["unitsPerGenJob"])
    config.Data.totalUnits = config.Data.unitsPerJob * int(sectionSettings["nGenJobs"])
    config.Data.outputPrimaryDataset = sectionSettings["outputPD"]
else:
    config.Data.splitting = "FileBased"
    config.Data.unitsPerJob = 1
    config.Data.inputDBS = "phys03"
    config.Data.inputDataset = prev_input
config.Data.publication = True
config.Data.publishDBS = "phys03"
config.Data.outputDatasetTag = sectionSettings["tag"]

config.Site.storageSite = sectionSettings["storageSite"]
