# Copyright 2021 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it.

#!/bin/bash
# run this script to setup a git hook to run the code formatter before committing changes

GIT_HOOKS_DIR=$(dirname $0)
GIT_DIR=$(git rev-parse --git-dir)
cp $GIT_HOOKS_DIR/pre-commit $GIT_DIR/hooks
chmod +x $GIT_DIR/hooks/pre-commit
