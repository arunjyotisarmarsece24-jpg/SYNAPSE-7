#!/bin/bash
# ==============================================================================
# Helper: verify_github_sync.sh
# Description: Verify SYNAPSE-7 Local vs Remote GitHub Synchronization
# ==============================================================================
export PATH=/home/dse/miniforge3/bin:$PATH
cd /home/dse/SYNAPSE-7

echo "======================================================================"
echo "  SYNAPSE-7 // GitHub Remote Synchronization Verification"
echo "======================================================================"

echo -e "\n[*] 1. Remote GitHub HEAD vs Local HEAD:"
LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git ls-remote origin refs/heads/main | awk '{print $1}')
echo "    Local Commit  : $LOCAL_SHA"
echo "    Remote Commit : $REMOTE_SHA"

if [ "$LOCAL_SHA" == "$REMOTE_SHA" ]; then
    echo "    >>> STATUS: 100% SYNCHRONIZED AND UP TO DATE! <<<"
else
    echo "    >>> STATUS: Desynchronized! Run 'git push' to sync. <<<"
fi

echo -e "\n[*] 2. Checking Tapeout Deliverables in Remote Commit ($REMOTE_SHA):"
git ls-tree -r --name-only origin/main | grep -E 'gds|outputs|reports|SYNAPSE7' | while read -r file; do
    echo "    [ON GITHUB] $file"
done

echo -e "\n======================================================================"
echo "  GitHub Web Links to View Your Results:"
echo "  - Repo: https://github.com/arunjyotisarmarsece24-jpg/SYNAPSE-7"
echo "  - Report: https://github.com/arunjyotisarmarsece24-jpg/SYNAPSE-7/blob/main/SYNAPSE7_ASIC_TAPEOUT_AND_SPECTRE_SIGN_OFF_REPORT.md"
echo "  - GDSII: https://github.com/arunjyotisarmarsece24-jpg/SYNAPSE-7/tree/main/gds"
echo "  - Outputs: https://github.com/arunjyotisarmarsece24-jpg/SYNAPSE-7/tree/main/outputs"
echo "======================================================================"
