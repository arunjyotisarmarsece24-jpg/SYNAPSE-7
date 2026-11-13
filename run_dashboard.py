"""
Launches the SYNAPSE-7 Live Interactive Cyberpunk Web Dashboard.
"""

import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from synapse7.web_dashboard.app import app

if __name__ == "__main__":
    print("\n" + "=" * 70)
    print(" >>> [SYNAPSE-7] LAUNCHING LIVE INTERACTIVE QUANTUM WEB DASHBOARD")
    print(" >>> Open your browser at: http://127.0.0.1:5000")
    print("=" * 70 + "\n")
    app.run(host="127.0.0.1", port=5000, debug=False)
