#!/bin/bash

# Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# install_flutter.sh
# GitHub Codespaces setup: Install Flutter SDK following this Dockerfile recipe:
#    https://github.com/appleboy/flutter-docker/blob/master/Dockerfile
# or this git area
#    https://github.com/yostane/flutter2-desktop
#
# 2024 February 12
# Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

set -euo pipefail

wget -O /tmp/flutter_linux.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.5-stable.tar.xz

# If running as root, install to /usr/local (typical for container images). If
# running as a regular user, extract to $HOME/flutter to avoid needing sudo.
if [ "$(id -u)" -eq 0 ]; then
	echo "Installing Flutter to /usr/local/flutter (running as root)"
	cd /usr/local
	tar -xf /tmp/flutter_linux.tar.xz
	profile_path="/etc/profile.d/flutter.sh"
	echo 'export PATH="$PATH:/usr/local/flutter/bin"' > "$profile_path"
	echo "Wrote PATH to $profile_path"
else
	echo "Installing Flutter to $HOME/flutter (no sudo required)"
	mkdir -p "$HOME/flutter"
	tar -xf /tmp/flutter_linux.tar.xz -C "$HOME"
	# Add to user's bashrc
	echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
fi

rm /tmp/flutter_linux.tar.xz
