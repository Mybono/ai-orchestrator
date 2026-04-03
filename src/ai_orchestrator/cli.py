import subprocess
import os
import sys

def main():
    """
    Finds the absolute path to scripts/install.sh and executes it.
    """
    # Finding the path to the scripts directory relative to this file
    # src/ai_orchestrator/cli.py -> src/ai_orchestrator/../.. -> root
    current_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.abspath(os.path.join(current_dir, "..", ".."))
    install_script = os.path.join(root_dir, "scripts", "install.sh")

    if not os.path.exists(install_script):
        print(f"❌ Could not find installation script at {install_script}")
        sys.exit(1)

    # Ensure it's executable
    os.chmod(install_script, 0o755)

    print(f"🚀 Starting ai-orchestrator installation from {root_dir}...")
    try:
        subprocess.run(["bash", install_script], check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Installation failed with exit code {e.returncode}")
        sys.exit(e.returncode)

if __name__ == "__main__":
    main()
