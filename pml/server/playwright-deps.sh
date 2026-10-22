#!/usr/bin/env bash
# Ubuntu 24.04 libraries for the Chromium of PML's pinned Playwright 1.55.1, so
# the browser gate chain runs. The list is Playwright's own
# `npx playwright install-deps --dry-run chromium` output on Ubuntu 24.04
# (2026-10-21). Take the list again from that command when PML's Playwright pin
# or the Ubuntu release changes. Run as root through pml/run-on.sh.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

apt-get update -q
apt-get install -y -q --no-install-recommends \
  libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 libcairo2 \
  libcups2t64 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0t64 libnspr4 libnss3 \
  libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
  libxkbcommon0 libxrandr2 xvfb fonts-noto-color-emoji fonts-unifont \
  libfontconfig1 libfreetype6 xfonts-cyrillic xfonts-scalable fonts-liberation \
  fonts-ipafont-gothic fonts-wqy-zenhei fonts-tlwg-loma-otf fonts-freefont-ttf
echo "== Playwright system libraries installed"
