#!/bin/bash
#
# SPDX-License-Identifier: MIT
# Copyright © 2022 Apolo Pena
#
# directives.sh
#
# Requires:
# utils.sh
#
# Description:
# Executes directives from a manifest to either keep or backup files or directories
# Files and driectories are recommended to be backed up if they have the potential to share project data
# such as .gitignore or even a hybrid setup where .gitpod.yml or .gitpod.Dockerfile has been altered
# Backed up files and directories can then be merged by hand back into the updated project.
#
# About the manifest:
# The manifest is loaded from: https://github.com/apolopena/gls-tools/blob/main/.latest_gls_manifest
# where it is dynamically generated each time gitpod-laravel-starter is released.
# If for some reason the manifest cannot be loaded then a hardcoded version will be used
# Supported directives in the manifest are:
#    [keep]
#    [recommend-backup]
#
# All unsupported directives in the manifest will be ignored
#
# Note:
# NOTE SURE WHAT TO DO ABOUT UTILITY FUNCTIONS, 
# SHARING THEM MAKES A MESSY PATTERN AND SO DOES DUPLICATING THEM



# NEW GLOBALS NEEDED
# __manifest
#

# GLOBALS USED
# data_keeps=(), data_bakups=()

# FUNCTIONS TO BRING IN
# set_directives() # requires: $data_keeps, $data_backups
# has_directive()
# execute_directives() # requires: $data_keeps, $data_backups, err_msg()
# keep() # requires: $project_root, $target_dir, $note_prefix, err_msg(), is_subpath(), yes_no()
# recommend_backup() # requires: $project_root, $backups_dir, err_msg(), is_subpath(), yes_no()
