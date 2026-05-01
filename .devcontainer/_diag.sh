#!/usr/bin/env bash
echo "whoami=$(whoami)"
echo "hostname=$(hostname)"
echo "pwd=$(pwd)"
echo "---"
ls / | head -20
echo "---"
ls /workspaces/ 2>&1 | head -5
echo "---"
ls /workspaces/dbt-analytics-engineer-certification/ 2>&1 | head -20
