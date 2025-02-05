import argparse
import ast
import json
import os
import subprocess
import sys

# CLI args
parser = argparse.ArgumentParser(
    prog="GetErrataImageBuilds",
    description="Get latest image build numbers associated with an Errata advisory"
)
parser.add_argument("--errata", required=True, type=int, help="errata id (i.e: 124155)")
args = parser.parse_args()
errata = args.errata

package_builds = {
    "skupper-router-container": "",
    "skupper-controller-container": "",
    "skupper-kube-adaptor-container": "",
    "skupper-network-observer-container": "",
    "skupper-cli-container": "",
}

res = subprocess.run(
    ['curl', '-s', '--user', ':',
     '--negotiate',
     'https://errata.devel.redhat.com/api/v1/erratum/%d/builds.json' % errata],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE)
try:
    res.check_returncode()
    buildJson = json.loads(res.stdout)
    buildKeys = list(buildJson.keys())
    if len(buildKeys) != 1:
        raise Exception("Expecting only one product version, found: %d" % len(buildJson.keys()))
    productVersion = buildKeys[0]
    builds = buildJson[productVersion]['builds']
    if len(builds) == 0:
        raise Exception("No builds found. Errata must have all builds associated first.")
    for build in builds:
        brew_build = list(build.keys())[0]
        for package in package_builds:
            if brew_build.startswith(package):
                package_builds[package] = brew_build
except Exception as e:
    sys.exit("Unable to list errata builds - exception: %s - code: %s - %s" % (e, res.returncode, res.stderr.decode()))

print(json.dumps(package_builds, indent=2))
