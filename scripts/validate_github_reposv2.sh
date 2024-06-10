#!/bin/bash

# GitHub username and personal access token
GITHUB_USERNAME=""
GITHUB_TOKEN=""

# Input CSV file containing Branchurl
INPUT_CSV="github_repos.csv"

# Output CSV file
OUTPUT_CSV="github_repos_info.csv"

# Write CSV header for output file
echo "Branchurl,Status,Forked,BranchForkedFrom,PRsAhead,CommitsAhead,LastCommitDate" > "$OUTPUT_CSV"

# Function to validate a Tree URL with GitHub and retrieve HTTP code as integer
validate_url() {
    local branch_name=$1
    

    # Construct the API URL for the repository
    local api_url="https://bankgit.onefiserv.net/api/v3/repos/fiserv/cc-core-server/branches/$branch"

    # Fetch the HTTP response code as integer
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$api_url")
    local http_code_int=$(expr $http_code + 0)  # Convert HTTP code to integer
    echo "$http_code"
    echo "$http_code_int"
}

# Function to retrieve repository information
get_repo_info() {
    local branch_url=$1
    local branch_name=$2
    local api_url=$(echo "$branch_url" | sed 's/tree/blob/')
    local prs_ahead="N/A"
    local commits_ahead="N/A"
    local last_commit_date="N/A"

    prs_ahead=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$api_url/pulls?state=open&base=$branch_name" | grep -c '"id":')
    commits_ahead=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$api_url/compare/$branch_name" | grep -o '"ahead_by": *[^,]*' | awk -F ': ' '{print $2}')
    # Get the last commit date
    last_commit_date=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$api_url" | jq -r '.commit.committer.date')

    # Get the last commit date
    last_commit_date=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$api_url/commits/$branch_name" | jq -r '.[0].commit.committer.date')

    echo "\"$branch_url\",\"Valid\",\"N/A\",\"N/A\",\"$prs_ahead\",\"$commits_ahead\",\"$last_commit_date\""
}

# Read the input CSV file and process each row
tail -n +2 "$INPUT_CSV" | while IFS=',' read -r servicename Core CoreVariant branchname Branchurl
do
    if [[ -z "$Branchurl" || -z "$branchname" ]]; then
        echo "Empty Branchurl or branchname, skipping..."
        continue
    fi
    status="Valid"
    http_code=$(validate_url "$branchname")
    http_code_int=$(expr $http_code + 0)  # Convert HTTP code to integer

    if [[ "$http_code_int" -ne 200 ]]; then
        status="Invalid URL"
        repo_info="\"$Branchurl\",\"$status\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\""
    else
        repo_info="$(get_repo_info "$Branchurl" "$branchname")"
    fi

    # echo "$repo_info" >> "$OUTPUT_CSV"
    echo "$repo_info"
    exit 1
done

echo "Repository information has been saved to $OUTPUT_CSV"