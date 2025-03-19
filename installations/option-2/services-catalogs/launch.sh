#!/bin/bash

# Usage:  IBM Cloud Pak for Data
# Author: Dr. Jeffrey Chijioke-Uche, IBM

# IBM Cloud Pak for Data Services
declare -A SERVICES=(
  [1]="AI Factsheets"
  [2]="Analytics Engine powered by Apache Spark"
  [3]="Cognos Dashboards"
  [4]="Data Gate"
  [5]="Data Privacy"
  [6]="Data Refinery"
  [7]="Data Replication"
  [8]="DataStage"
  [9]="Data Virtualization"
  [10]="Db2"
  [11]="Db2 Big SQL"
  [12]="Db2 Data Management Console"
  [13]="Db2 Warehouse"
  [14]="Decision Optimization"
  [15]="EDB Postgres"
  [16]="Execution Engine for Apache Hadoop"
  [17]="IBM Automated Data Lineage"
  [18]="IBM Knowledge Catalog"
  [19]="IBM Match 360"
  [20]="Informix"
  [21]="MANTA Automated Data Lineage"
  [22]="IBM Cloud Databases for MongoDB"
  [23]="Orchestration Pipelines"
  [24]="RStudio Server Runtimes"
  [25]="SPSS Modeler"
  [26]="Watson Machine Learning"
  [27]="Watson OpenScale"
  [28]="Watson Studio"
  [29]="Watson Studio Runtimes"
)

# Function to display services
display_services() {
  echo "Please select which IBM Cloud Pak for Data service you wish to install:"
  for i in "${!SERVICES[@]}"; do
    echo "$i - ${SERVICES[$i]}"
  done
  echo "0 - Quit"
  echo -n "Enter the number corresponding to your choice and press Enter: "
}

# Function to show progress bar
show_progress_bar() {
  local duration=$1
  local interval=1
  local elapsed=0
  while [ $elapsed -lt $duration ]; do
    printf "\r["
    for ((i=0; i<$elapsed; i++)); do printf "#"; done
    for ((i=$elapsed; i<$duration; i++)); do printf " "; done
    printf "] $((elapsed * 100 / duration))%%"
    sleep $interval
    ((elapsed+=interval))
  done
  printf "\r["
  for ((i=0; i<$duration; i++)); do printf "#"; done
  printf "] 100%%\n"
}

# Function to install service
install_service() {
  local service_name=$1
  echo "Installing $service_name..."
  # Simulate installation progress
  show_progress_bar 30
  # Actual installation command
  cpd-cli manage apply-cr \
    --cpd_instance_ns=cpd-namespace \
    --components=$(echo $service_name | tr ' ' '_') \
    --license_acceptance=true \
    --storage_class=ocs-storagecluster-ceph-rbd
  echo "$service_name installed successfully."
}

# Main script loop
while true; do
  display_services
  read -r choice

  if [[ "$choice" == "0" ]]; then
    echo "Exiting installation script. No services were installed."
    exit 0
  fi

  if [[ -z "${SERVICES[$choice]}" ]]; then
    echo "Invalid selection. Please enter a valid number from the list."
    continue
  fi

  selected_service=${SERVICES[$choice]}
  echo "You selected: $selected_service"

  # Confirm selection
  read -p "Do you want to proceed with the installation of $selected_service? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Installation of $selected_service aborted."
    continue
  fi

  # Install the selected service
  install_service "$selected_service"

  # Ask if the user wants to install another service
  read -p "Do you want to install another service? (y/n): " another
  if [[ "$another" != "y" && "$another" != "Y" ]]; then
    echo "Installation process completed."
    exit 0
  fi
done