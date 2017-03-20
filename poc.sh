#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echoc () {
    GREEN=$(tput setaf 2)
    RESET=$(tput sgr 0)
	echo -e "\n${GREEN}*** $1${RESET}"
}


ORIGIN_REPO="${SCRIPT_DIR}/origin-repo"
CLONE_REPO="${SCRIPT_DIR}/clone-repo"
BUILD_AWARE_REPO="${SCRIPT_DIR}/build-aware-repo"

cd $SCRIPT_DIR

# Clean out any previous build.
rm -fr "${ORIGIN_REPO}"
rm -fr "${CLONE_REPO}"
rm -fr "${BUILD_AWARE_REPO}"

echoc "Creating source repo"
mkdir "${ORIGIN_REPO}"
cd "${ORIGIN_REPO}"
git init

# Simulate source code in two branches that should be kept seperate from builds.
echoc "Creating master and develop branches"
echo "Hello world" > source.txt 
git add source.txt
git commit -m "Initial commit"
git checkout -b develop
echo " how are you" >> source.txt
git add source.txt
git commit -m "First develop commit"

echoc "Setting up build root"
# Only way I know of to get us a new parent-less commit is to checkout an
# orphan branch, checking something else out, and deleting the branch.
git checkout --orphan to-be-deleted

# Clear index and produce our first clean commit without a parent.
git rm -fr .
echo "no build yet" > build.txt
git add build.txt
git commit -m "Initial build commit"

# From now on we reference build by our own custom builds/* references.
# Setup the initial build reference
echoc "Producing 3 builds"
git update-ref refs/builds/latest $(git rev-parse HEAD)
# We now have a ref, check it out and delete the branch
git checkout refs/builds/latest
git branch -D to-be-deleted
# We're now in detached head (aka, on a commit without a corrosponding refs/heads/)

# Produce first build
echo "build 1" > build.txt
git add build.txt
git commit -m "First build"
# TODO - figure out how to lay out the refs
git update-ref refs/builds/1 HEAD
git update-ref refs/builds/latest refs/builds/1

# Produce extra builds, move the "latest" reference along (to simulate that
# we're actually doing seperate build with pushes inbeween).
git checkout refs/builds/1
echo "build 2" > build.txt
git add build.txt
git commit -m "Second build commit"
git update-ref refs/builds/2 $(git rev-parse HEAD)
# Update latest, but only if it points to refs/builds/1 (thats what the
# third arg does)
git update-ref refs/builds/latest refs/builds/2 refs/builds/1

echo "build 3" > build.txt
git add build.txt
git commit -m "Third build commit"
git update-ref refs/builds/3 HEAD
git update-ref refs/builds/latest refs/builds/3 refs/builds/2

# We're going to clone this repo in a moment, but as its not a bare repo we
# reset HEAD to something that is not a build to make sure it does not get
# fetched by the clone.
git checkout master

# Setup ordinary clone that should be oblivious of our builds.
echoc "Setting up a clean clone"
cd "${SCRIPT_DIR}"
git clone "${ORIGIN_REPO}" "${CLONE_REPO}"
cd "${CLONE_REPO}"
git fetch

# Setup a clone that maps builds to branches
echoc "Setting up a build-aware"
cd "${SCRIPT_DIR}"
git clone "${ORIGIN_REPO}" "${BUILD_AWARE_REPO}"
cd "${BUILD_AWARE_REPO}"
echo '
[remote "origin"]
	fetch = +refs/builds/*:refs/remotes/origin/build/*
' >> .git/config
git fetch

# Finish of by a status of which refs each repo is aware of.
cd "${ORIGIN_REPO}"
echoc "Bracnhes and refs in origin-repo:"
git branch -a
git show-ref

cd "${CLONE_REPO}"
echoc "Bracnhes and refs in clone-repo:"
git branch -a
git show-ref

cd "${BUILD_AWARE_REPO}"
echoc "Bracnhes and refs in build-aware-repo:"
git branch -a
git show-ref



