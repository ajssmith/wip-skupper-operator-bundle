import argparse
import ast
import json
import os
import subprocess
import sys

# CLI args
parser = argparse.ArgumentParser(
    prog="GetImageSHAs",
    description="Get latest image SHAs based on required image tags"
)
parser.add_argument("--router-build", required=False, help="skupper-router brewkoji build")
parser.add_argument("--controller-build", required=False, help="skupper-controller brewkoji build")
parser.add_argument("--kube-adaptor-build", required=False, help="skupper-kube-adaptor brewkoji build")
parser.add_argument("--cli-build", required=False, help="skupper-cli brewkoji build")
parser.add_argument("--network-observer-build", required=False, help="skupper-network-observer brewkoji build")
#parser.add_argument("--cli-build", required=False, help="skupper-cli brewkoji build")
args = parser.parse_args()

router_build = args.router_build
controller_build = args.controller_build
kube_adaptor_build = args.kube_adaptor_build
cli_build = args.cli_build
network_observer_build = args.network_observer_build
#cli_build = args.cli_build

packages = [
    router_build,
    controller_build,
    kube_adaptor_build,
    cli_build,
    network_observer_build,
]

buildShas = {}
for package in packages:
    if package == "" or package is None:
        continue
    try:
        res = None
        res = subprocess.run(['brew', 'buildinfo', package],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        res.check_returncode()
    except Exception as ex:
        suffix = ""
        if res is not None:
            suffix = " - exit code: %s - stderr: %s" % (res.returncode, res.stderr.decode())
        sys.exit("Unable to retrieve build info for %s - %s%s" % (
            package, ex, suffix))
    else:
        outlines = res.stdout.decode().splitlines()
        for line in outlines:
            if line.startswith('Extra: '):
                buildAst = line[7:]
                build = ast.literal_eval(buildAst)
                for sha in build['image']['index']['digests'].values():
                    buildShas[package] = sha
                    break

print(json.dumps(buildShas, indent=2))
