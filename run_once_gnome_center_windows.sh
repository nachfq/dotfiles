#!/usr/bin/env bash
set -e

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.mutter center-new-windows true || true
fi
