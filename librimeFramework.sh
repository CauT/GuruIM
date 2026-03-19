#!/usr/bin/env bash
# encoding: utf-8
set -e

OUTPUT="${PWD}/Frameworks"

# 如果存在就不再执行
# if [[ -d ${OUTPUT} ]]
# then
#   exit 0
# fi

# 下载依赖的 librime framework
mkdir -p $OUTPUT
rm -rf $OUTPUT/*.xcframwork && (
  # 获取最新 release 的下载 URL
  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/imfuxiao/LibrimeKit/releases/latest | grep 'browser_download_url.*Frameworks.tgz' | cut -d'"' -f4)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Failed to get download URL from GitHub API, trying fallback..."
    # 备用方案：使用最新的 release
    curl -OL https://github.com/imfuxiao/LibrimeKit/releases/latest/download/Frameworks.tgz
  else
    curl -OL "$DOWNLOAD_URL"
  fi

  tar -zxf Frameworks.tgz -C ${OUTPUT}/..
  rm -rf Frameworks.tgz
)
