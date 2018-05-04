#!/bin/bash

git submodule deinit .
rm -rf product/* vendor/*
git reset --hard
git submodule update --init --recursive
