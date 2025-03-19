#!/bin/bash

#========================================================================================================================
# CLOUD PAK FOR DATA CONTROL PLANE INSTALLATION WITH YAML & KUSTOMIZATION
# @Author: Dr. Jeffrey Chijioke-Uche
# @Usage:  Install CPD instance on OpenShift using YAML files & Kustomize
#========================================================================================================================

# Load environment variables
source files/cpd_vars.sh

###############################################
#  VAR Check
################################################
var_check() {
    REQUIRED_VARS=( "PROJECT_CERT_MANAGER" "PROJECT_LICENSE_SERVICE" "PROJECT_SCHEDULING_SERVICE"
                    "PROJECT_CPD_INST_OPERATORS" "PROJECT_CPD_INST_OPERANDS" 
                    "STG_CLASS_BLOCK" "STG_CLASS_FILE" "ENTITLEMENT_KEY" "OCP_URL" "OCP_TOKEN" )

    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "❌ Error: $var is not set. Ensure cpd_vars.sh is correctly sourced."
            exit 1
        fi
    done
}

#################################################
# Progress Bar Function
#################################################
progress_bar() {
    local duration=$1
    local bar_length=40
    local spin_chars='🔄 🔃 🔁 🔂'
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
        for ((i = 0; i < progress; i++)); do echo -ne "🟢"; done
        for ((i = progress; i < bar_length; i++)); do echo -ne "🔵"; done
        echo -ne "] $spin_char"
        
        if [ $elapsed -ge $duration ]; then
            break
        fi
        sleep 0.1
    done

    echo -e "\n✅ Progress Completed! - 100%"
}

#################################################
# Login to OpenShift
#################################################
login_to_ocp() {
    echo "🔐 Logging into OpenShift..."
    oc login --server=${OCP_URL} --token=${OCP_TOKEN} --insecure-skip-tls-verify=true
    echo "✅ Logged into OpenShift successfully."
    progress_bar 5
}

#################################################
# Ensure Required OpenShift Projects Exist
#################################################
create_projects() {
    PROJECTS=( "$PROJECT_CERT_MANAGER" "$PROJECT_LICENSE_SERVICE" "$PROJECT_SCHEDULING_SERVICE"
               "$PROJECT_CPD_INST_OPERATORS" "$PROJECT_CPD_INST_OPERANDS" )

    echo "🔍 Checking OpenShift projects..."
    for PROJECT in "${PROJECTS[@]}"; do
        if oc get project "$PROJECT" &>/dev/null; then
            echo "✅ Project $PROJECT already exists. Skipping creation."
        else
            echo "🚀 Creating project: $PROJECT..."
            oc new-project "$PROJECT"
            echo "✅ Project $PROJECT created successfully."
        fi
    done
    progress_bar 5
}

#################################################
# Add IBM Entitlement Key to OpenShift
#################################################
add_entitlement_key() {
    echo "🔑 Adding IBM Entitlement Key..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ibm-entitlement-key
  namespace: ${PROJECT_CPD_INST_OPERATORS}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "{\"auths\":{\"cp.icr.io\":{\"username\":\"cp\",\"password\":\"${ENTITLEMENT_KEY}\"}}}" | base64 -w 0)
EOF
    echo "✅ IBM Entitlement Key added successfully."
    progress_bar 5
}

#################################################
# Install Cloud Pak for Data Catalog Source (If Not Already Installed)
#################################################
catalog_source() {
    echo "🔍 Checking if the IBM Operator Catalog Source is already installed..."

    # Check if the CatalogSource exists in the openshift-marketplace namespace
    if oc get catalogsource ibm-operator-catalog -n openshift-marketplace &>/dev/null; then
        echo "✅ IBM Operator Catalog Source is already installed. Skipping installation."
    else
        echo "🚀 Installing Cloud Pak for Data Catalog Source..."
        oc apply -k kustomize/prepare
        echo "✅ Catalog Source installed successfully."
        progress_bar 5
    fi
}

#################################################
# Install IBM Cloud Pak Foundational Services with Kustomize
#################################################
install_foundational_services() {
    echo "🔍 Checking if foundational services are already installed..."
    if oc get csv -n ${PROJECT_CPD_INST_OPERATORS} | grep -q "ibm-common-service-operator"; then
        echo "✅ Foundational services are already installed. Skipping installation."
        return 0
    fi

    echo "🚀 Installing foundational services with Kustomize..."
    oc apply -k kustomize/foundational-services
    echo "✅ Foundational services installed successfully."
    progress_bar 5
}

#################################################
# Install Cloud Pak for Data Control Plane with Kustomize
#################################################
install_cpd_control_plane() {
    echo "🚀 Deploying Cloud Pak for Data control plane..."
    oc apply -k kustomize/cpd-control-plane
    echo "✅ Cloud Pak for Data control plane deployed successfully."
    progress_bar 5
}

#################################################
# Retrieve Cloud Pak for Data Admin Credentials
#################################################
get_admin_credentials() {
    echo "🔑 Retrieving CPD admin credentials..."
    oc extract secret/admin-user-details -n ${PROJECT_CPD_INST_OPERANDS} --keys=initial_admin_password --to=-
    progress_bar 5
}

#################################################
# Main Execution
#################################################
main() {
    var_check
    login_to_ocp
    create_projects
    add_entitlement_key
    catalog_source
    install_foundational_services
    install_cpd_control_plane
    get_admin_credentials
}
# Run the main function
main
