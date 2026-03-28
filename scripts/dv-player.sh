#!/usr/bin/env bash
exec mpv --vo=gpu-next --tone-mapping=hable --tone-mapping-mode=hybrid "$@"
