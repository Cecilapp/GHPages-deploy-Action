#!/bin/sh
set -e

# which branch?
REPONAME="$(echo $GITHUB_REPOSITORY| cut -d'/' -f 2)"
OWNER="$(echo $GITHUB_REPOSITORY| cut -d'/' -f 1)"
GHIO="${OWNER}.github.io"
if [[ "$REPONAME" == "$GHIO" ]]; then
  TARGET_BRANCH="${default-branch}"
else
  TARGET_BRANCH="gh-pages"
fi

# DEBUG
echo ">>>${default-branch}"

echo "### Started deploy to $GITHUB_REPOSITORY/$TARGET_BRANCH"

echo "- email: $INPUT_EMAIL"
echo "- build_dir: $INPUT_BUILD_DIR"
echo "- cname: $INPUT_CNAME"
echo "- Jekyll: $INPUT_JEKYLL"

# Prepare build_dir
BUILD_DIR=$INPUT_BUILD_DIR
BUILD_DIR=${BUILD_DIR%/} # remove the ending slash if exists
mkdir -p $HOME/$BUILD_DIR
cp -R $BUILD_DIR/* $HOME/$BUILD_DIR/
cd $HOME

# Create or clone the gh-pages repo
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$INPUT_EMAIL"
if [ -z "$(git ls-remote --heads https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git ${TARGET_BRANCH})" ]; then
  git clone --quiet https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
  cd $TARGET_BRANCH
  git checkout --orphan $TARGET_BRANCH
  git rm -rf .
  echo "$REPONAME" > README.md
  git add README.md
  git commit -a -m "Create $TARGET_BRANCH branch"
  git push origin $TARGET_BRANCH
  cd ..
else
  git clone --quiet --branch=$TARGET_BRANCH https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
fi

# Sync repo with build_dir
cp -R $TARGET_BRANCH/.git $HOME/.git
rm -rf $TARGET_BRANCH/*
cp -R $HOME/.git $TARGET_BRANCH/.git
cd $TARGET_BRANCH
cp -Rf $HOME/${BUILD_DIR}/* .

# Custom domain
if [ ! -z "$INPUT_CNAME" ]; then
  echo "$INPUT_CNAME" > CNAME
fi

# .nojekyll
if [ "$INPUT_JEKYLL" != "yes" ]; then
  touch .nojekyll
fi

# Deploy/Push (or not?)
if [ -z "$(git status --porcelain)" ]; then
  echo "Nothing to deploy"
else
  git add -Af .
  git commit -m "$GITHUB_ACTOR published a site update"
  git push -fq origin $TARGET_BRANCH > /dev/null
fi

echo "### Finished deploy"
