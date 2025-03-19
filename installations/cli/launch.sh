
  #!/bin/bash
  
  #---------------------------------------------------------------------------------------------------------------------
  #                                 CLOUD PAK FOR DATA CLI INSTALLATION
  #---------------------------------------------------------------------------------------------------------------------
  # @Author: Dr. Jeffrey Chijioke-Uche
  # @Usage:  Install cpd-cli

install_cpd_cli() {
   # Set variables
  CPD_CLI_VERSION="14.1.1"
  OS_ARCH="linux-SE"  # linux, darwin, s390x, etc
  URL="https://github.com/IBM/cpd-cli/releases/download/v${CPD_CLI_VERSION}/cpd-cli-${OS_ARCH}-${CPD_CLI_VERSION}.tgz"
  FILENAME="cpd-cli-${OS_ARCH}-${CPD_CLI_VERSION}.tgz"
  EXTRACT_DIR="cpd-cli-${OS_ARCH}-${CPD_CLI_VERSION}"
  INSTALL_DIR="/usr/local/bin"  # Default is Linux OS Path. Change if you are on another Operating System (OS)

  # Download the cpd-cli archive
  echo "Downloading cpd-cli CPD_CLI_VERSION ${CPD_CLI_VERSION}..."
  curl -L -o "$FILENAME" "$URL"

  # Verify the download (optional, but recommended)
  if [ $? -ne 0 ]; then
    echo "Error downloading cpd-cli. Exiting."
    return 1
  fi

  # Extract the archive
  echo "Extracting cpd-cli..."
  tar -xzf "$FILENAME"

  # Move the binaries
  echo "Installing cpd-cli..."
  cd cpd-cli-${OS_ARCH}-${CPD_CLI_VERSION}
  sudo mv cpd-cli ${INSTALL_DIR}
  sudo mv plugins ${INSTALL_DIR}
  sudo mv LICENSES ${INSTALL_DIR}

  # Make the binary executable
  sudo chmod +x "$INSTALL_DIR/cpd-cli"

  # Clean up temporary files
  echo "Cleaning up..."
  cd ../
  rm "$FILENAME"
  rm -rf "$EXTRACT_DIR"

  # Verify the installation
  echo "Verifying installation..."
  cpd-cli --help

  echo "cpd-cli CPD_CLI_VERSION ${CPD_CLI_VERSION} installed successfully."
}

# cpd-cli check
cpd_cli_check() {
  if command -v cpd-cli &> /dev/null; then
    echo "cpd-cli is already installed. Skipping installation."
    exit 0
  else
    echo "cpd-cli not installed, please wait.."
    sleep 4
    install_cpd_cli
  fi
}

# Main:
cpd_cli_check
