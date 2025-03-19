#!/bin/bash

#========================================================================================================================
# CLOUD PAK FOR DATA CONTROL PLANE INSTALLATION
# @Author: Dr. Jeffrey Chijioke-Uche
# @Usage:  Install cpd instance
#========================================================================================================================

# Defined Variables
source files/cpd_vars.sh

#################################################
# Progress Advisor
#################################################
progress_bar() {
    local duration=$1
    local bar_length=40  # 
    local spin_chars='🔄 🔃 🔁 🔂'  # 
    local spin_index=0

    echo -ne "["
    for ((i = 0; i < bar_length; i++)); do echo -ne "⚪"; done
    echo -ne "]\r["

    start_time=$(date +%s)
    while true; do
        elapsed=$(( $(date +%s) - start_time ))
        progress=$(( (elapsed * bar_length) / duration ))

        spin_char="${spin_chars:spin_index:1}"
        spin_index=$(( (spin_index + 1) % 4 ))

        echo -ne "\r["
        for ((i = 0; i < progress; i++)); do echo -ne "🟢"; done  # 
        for ((i = progress; i < bar_length; i++)); do echo -ne "🔵"; done  # 
        echo -ne "] $spin_char"  # 
        
        if [ $elapsed -ge $duration ]; then
            break
        fi
        sleep 0.1
    done

    echo -e "\n✅ Progress Completed! - 100%"
}

#################################################
# Read Entitlement Key from file: 
#################################################
ENTITLEMENT_KEY=$(cat files/entitlement_key.txt 2>/dev/null)
if [[ -z "$ENTITLEMENT_KEY" ]]; then
  echo "Error: Entitlement key not found or its text file is missing."
  exit 1
fi

#################################################
# Read OCP URL from file: 
#################################################
OCP_URL=$(cat files/ocp_token.txt 2>/dev/null)
if [[ -z "$OCP_URL" ]]; then
  echo "Error: OCP url not found or its text file is missing."
  exit 1
fi

#################################################
# Read OCP TOKEN from file: 
#################################################
OCP_TOKEN=$(cat files/ocp_token.txt 2>/dev/null)
if [[ -z "$OCP_TOKEN" ]]; then
  echo "Error: OCP token not found or its text file is missing."
  exit 1
fi

#################################################
# cpd-cli check
#################################################
cpd_cli_check() {
  if command -v cpd-cli &> /dev/null; then
    echo "cpd-cli is already installed. Skipping installation."
    progress_bar 5
  else
    echo "cpd-cli not installed - Please see https://github.com/IBM/cpd-cli/releases."
    exit 0
  fi
}

#################################################
# Login to OpenShift
#################################################
login_to_ocp() {
  echo "Logging into OpenShift..."
  cpd-cli manage login-to-ocp \
  --server=${OCP_URL} \
  --token=${OCP_TOKEN}
  echo "Logged into OpenShift successfully."
  progress_bar 5
}

#################################################
# Create necessary namespaces
#################################################
create_projects() {
  # Ensure variables are sourced
  if [[ -z "$PROJECT_CERT_MANAGER" || -z "$PROJECT_LICENSE_SERVICE" || -z "$PROJECT_SCHEDULING_SERVICE" || -z "$PROJECT_CPD_INST_OPERATORS" || -z "$PROJECT_CPD_INST_OPERANDS" ]]; then
    echo "Error: Project variables are not set. Ensure ./cpd_vars.sh is sourced."
    exit 1
  fi

  # List of OpenShift projects from sourced variables
  PROJECTS=(
    "$PROJECT_CERT_MANAGER"
    "$PROJECT_LICENSE_SERVICE"
    "$PROJECT_SCHEDULING_SERVICE"
    "$PROJECT_CPD_INST_OPERATORS"
    "$PROJECT_CPD_INST_OPERANDS"
  )

  echo "Checking OpenShift projects..."

  for PROJECT in "${PROJECTS[@]}"; do
    if oc get project "$PROJECT" &>/dev/null; then
      echo "✅ Project $PROJECT already exists. Skipping creation."
    else
      echo "🚀 Project $PROJECT does not exist. Creating..."
      oc new-project "$PROJECT"
      echo "✅ Project $PROJECT created successfully."
    fi
  done

  echo "Project check completed."
  progress_bar 5
}

#################################################
# Add IBM Entitlement Key to Global Pull Secret
#################################################
add_entitlement_key() {
  echo "🔑 Adding IBM Entitlement Key to global pull secret..."

  cpd-cli manage add-icr-cred-to-global-pull-secret \
    --entitled_registry_key=${ENTITLEMENT_KEY}

  echo "✅ IBM Entitlement Key added successfully."
  progress_bar 5
}

#################################################
# Install Cloud Pak for Data Catalog Source 
#################################################
catalog_source() {
    echo "🔍 Checking if the IBM Operator Catalog Source is already installed..."

    # Check if the CatalogSource exists in the openshift-marketplace namespace
    if oc get catalogsource ibm-operator-catalog -n openshift-marketplace &>/dev/null; then
        echo "✅ IBM Operator Catalog Source is already installed. Skipping installation."
    else
        echo "🚀 Installing Cloud Pak for Data Catalog Source..."
        oc apply -k prepare/kustomize/prepare
        echo "✅ Catalog Source installed successfully."
        echo "Please wait..." && sleep 5
        progress_bar 5
    fi
}

#################################################
# Install IBM Cloud Pak foundational services
#################################################
install_foundational_services() {
  echo "🔍 Checking if IBM Cloud Pak foundational services are already installed..."

  # Check if foundational services Custom Resource (CR) exists
  if oc get csv -n ${PROJECT_CPD_INST_OPERATORS} | grep -q "ibm-common-service-operator"; then
    echo "✅ Foundational services are already installed. Skipping installation."
    return 0
  fi

  echo "🚀 Installing IBM Cloud Pak foundational services..."

  cpd-cli manage apply-cluster-components \
    --release=${VERSION} \
    --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --components=cpfs,ibm-licensing,ibm-cert-manager,scheduler \
    --license_acceptance=true

  echo "✅ Foundational services installed successfully."
  progress_bar 5
}

#################################################
# Install IBM Cloud Pak Cert Manager and Licensing Services
#################################################
install_cert_licensing_services() {
  echo "🚀 Installing Cert Manager and Licensing Services..."

  cpd-cli manage apply-cluster-components \
    --release=${VERSION} \
    --license_acceptance=true \
    --cert_manager_ns=${PROJECT_CERT_MANAGER} \
    --licensing_ns=${PROJECT_LICENSE_SERVICE}

  echo "✅ Cert Manager and Licensing Services installed successfully."
  progress_bar 5
}

#################################################
# Authorize IBM Cloud Pak for Data Instance Topology
#################################################
authorize_instance_topology() {
  echo "🔐 Authorizing Cloud Pak for Data instance topology..."

  cpd-cli manage authorize-instance-topology \
    --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}

  echo "✅ Cloud Pak for Data instance topology authorized successfully."
  progress_bar 5
}

#################################################
# Setup IBM Cloud Pak for Data Instance Topology
#################################################
setup_instance_topology() {
  echo "🔧 Setting up Cloud Pak for Data instance topology..."

  ./cpd-cli manage setup-instance-topology \
    --release=${VERSION} \
    --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --block_storage_class=${STG_CLASS_BLOCK} \
    --license_acceptance=true

  echo "✅ Cloud Pak for Data instance topology setup completed successfully."
  progress_bar 5
}


#################################################
# Apply IBM Cloud Pak for Data OLM Components
#################################################
apply_olm_components() {
  echo "📦 Applying Cloud Pak for Data OLM components..."

  cpd-cli manage apply-olm \
    --release=${VERSION} \
    --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --components=cpd_platform,${COMPONENTS}

  echo "✅ OLM components applied successfully."
  progress_bar 5
}


#################################################
# Install Cloud Pak for Data control plane
#################################################
install_cpd_control_plane() {
  echo "🚀 Installing Cloud Pak for Data control plane..."

  cpd-cli manage apply-cr \
    --release=${VERSION} \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --components=cpd_platform \
    --license_acceptance=true \
    --STG_CLASS_BLOCK=${STG_CLASS_BLOCK} \
    --STG_CLASS_FILE=${STG_CLASS_FILE}

  echo "✅ Cloud Pak for Data control plane installed successfully."
  progress_bar 5
}


#################################################
# Retrieve admin credentials
#################################################
get_admin_credentials() {
  echo "Retrieving initial admin credentials..."
  oc extract secret/admin-user-details -n ${PROJECT_CPD_INST_OPERANDS} --keys=initial_admin_password --to=-
  progress_bar 5
}

#################################################
# Main execution
#################################################
main() {
  cpd_cli_check
  login_to_ocp
  create_projects
  add_entitlement_key
  catalog_source
  install_cert_licensing_services
  install_foundational_services
  apply_olm_components
  setup_instance_topology
  install_cpd_control_plane
  authorize_instance_topology
  get_admin_credentials
}

