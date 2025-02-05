import argparse
import ast
import json
import os
import subprocess
import sys

# CLI args
parser = argparse.ArgumentParser(
    prog="GetImageBuilds",
    description="Get latest image build numbers from BrewKoki"
)
parser.add_argument("--data-plane-tag", required=True, help="data plane image (skupper-router) build tag")
parser.add_argument("--control-plane-tag", required=True, help="control plane images build tag")
args = parser.parse_args()
data_plane_tag = args.data_plane_tag
control_plane_tag = args.control_plane_tag

packages = [
    "skupper-router-container",
    "skupper-controller-container",
    "skupper-kube-adaptor-container",
    "skupper-network-observer-container",
    "skupper-cli-container",
]

package_builds = {}
for package in packages:
    tag = data_plane_tag if package.__contains__("skupper-router-container") else control_plane_tag
    res = subprocess.run(
        ['brew', 'list-builds',
         '--package', package,
         '--pattern', '*' + tag + '-*',
         '--state', 'COMPLETE'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)
    try:
        res.check_returncode()
        outlines = res.stdout.splitlines()
        # remove headers
        outlines.pop(0)
        outlines.pop(0)

        builds = []
        for line in outlines:
            build = line.split()
            builds.append(build[0].decode())
        package_builds[package] = builds
    except:
        sys.exit("Unable to list brew builds - code: %s - %s" % (res.returncode, res.stderr.decode()))

print(json.dumps(package_builds, indent=2))
