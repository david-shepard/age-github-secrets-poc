# 🔐 age-secrets-poc

**A proof‑of‑concept repo to manage secrets with ssh keys out-of-the-box.**

## 🚀 Table of Contents

1. [Overview](#-overview)
2. [How it works](#-how-it-works)
3. [Prerequisites](#-prerequisites)
4. [Installing age on windows](#installing-age-on-windows)
5. [Next Steps](#-next-steps--best-practices)
6. [Links](#assorted-links)


## 📘 Overview

This POC repo demonstrates how we can use simple asymmetric public/private key encryption and a small utility called `age` for simple secret management.

- `secrets/*` is where a user could put their plaintext secrets (added to [./gitignore](./.gitignore))

- `encrypted/*` is where encrypted secrets are stored (safe for git)

- Includes scripts:
  - [export_team_to_recipients.sh](./export_team_to_recipients.sh) exports a github team's age-formatted keys to `recipients.txt`
  - [encrypt_files_age.sh](./encrypt_files_age.sh) encrypts all secrets in `./secrets` to `./encrypted`

## Setup

**Approach 1: Collect recipients from team with script**

- Repo admin has to query the GitHub API for each team member's public SSH keys and aggregate them into a single recipients.txt file.
  - [export_team_to_recipients.sh](./export_team_to_recipients.sh) fetch users that with in github org & team , get their public keys, and append them to a [recipients.txt](./recipients.txt), for example:
    ```bash
    GH_ORG='my_org' GH_TEAM='qa-users' ./export_team_to_recipients.sh
    ```
  - [recipients.txt](./recipients.txt) acts as the access control single source of truth (ACL)

**Approach 2: Automatically encrypt/decrypt with .gitattributes**

Use a `.gitattributes` file to automatically encrypt/decrypt files. See [`age-crypt`](https://github.com/sandorex/age-crypt/tree/main)for an [example implementation](https://github.com/sandorex/age-crypt/blob/main/age/age.sh).

> [!NOTE]
> - `clean` runs on adding a secret
> - `smudge` runs on checking out a secret
> - change `KEY` to the location of the SSH key you use with GitHub
> - change `PUB_KEY` to reference `recipients.txt`

## Usage: How to Encrypt/Decrypt Secrets

**Encrypt**
- For each file in your `secrets/` directory

  ```bash
  age -R recipients.txt -a -o encrypted/$(basename "$FILE").age "$FILE"
  ```

  > [!TIP]: 
  > Run [encrypt_files_age.sh](./encrypt_secret_age.sh#L19) to automatically encrypt files in `./secrets` and output the age-encrypted files to `./encrypted`

- **Example**: `age -R recipients.txt -e -a my-secret -o encrypted/prod/secret-dev.yaml.enc`
- Commit & Push
- Only the .age encrypted files go into version control (see [encrypted dir](./encrypted))

```bash
git add encrypted/
git commit -m "chore: add/update encrypted secrets"
git push
```

**Decrypt**
- A user with the matching private SSH key just runs:

```bash
# Decrypt to file
age -d -i ~/.ssh/id_private_key -o values-do-not-commit.yaml encrypted/helm/prod/values-some-env.yaml.enc
```
- **Example (outputs earlier file to stdout, *RECOMMENDED*)** : `age -d -i ~/.ssh/my_private_key.key encrypted/helm/prod/values-production.yaml.enc`

## 📋 Prerequisites
- `age` (v1.0+)
  - Mac: `brew install age`,
  - Ubuntu: `apt install age`
  - Windows: Download & Unzip https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-windows-amd64.zip
  - Other operating systems see [Installation](https://github.com/FiloSottile/age?tab=readme-ov-file#installation)
- `jq` (for parsing JSON)
- GitHub personal‑access token (read‐only) with public_key scope
- A `secrets/` directory containing the plaintext files you wish to protect
- An SSH public key an associated private key to encrypt/decrypt files, see guide on [GitHub](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Installing age on windows

1. If your on windows, especially on a adminless workstation, instructions are a little trickier than a simple `brew install age`  📂
  - First, you'll create a dedicated folder for command-line tools inside your user profile and then download and extract the age executables into it.
    - Open File Explorer and navigate to your user folder by typing `%USERPROFILE%` in the address bar and pressing Enter. This usually goes to `C:\Users\YourUsername`.
    - Create a new folder here and name it bin. The final path will be `%USERPROFILE%\bin`.
    - Download the age utility from the official GitHub release: [age-v1.2.1-windows-amd64.zip](https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-windows-amd64.zip)
    - Extract the contents of the downloaded .zip file directly into the bin folder you just created. You should now have the following files inside `%USERPROFILE%\bin`:
    ```
    age.exe
    age-keygen.exe
    ```
2. Add the Folder to Your User PATH
    - Now, you must tell Windows where to find these new executables. You'll do this by adding the bin folder's path to your user PATH environment variable.
    - Press the Windows Key, type `env`, and select `Edit environment variables for your account`.
    - In the "User variables" section at the top, select the `Path variable` and click **Edit**
    - Click New and paste the path to your new folder: `%USERPROFILE%\bin`
    - Click OK on all the windows to save the changes.

3. Verify the Installation ✅
    - To ensure everything is working correctly, you must close any open terminal windows and then open a new PowerShell or Git Bash session.

Run the following commands. If the installation was successful, you will see the version number for each tool.

```Bash

# Verify the age tool
age --version

# Verify the age-keygen tool
age-keygen --version
```

### Next Steps & Goals
- Integrate with `sops`, see:
  - https://gist.github.com/osher/d49decfd7ae480a1a60bd88a01066a0a
  - https://github.com/Mic92/ssh-to-age/tree/main
- Github Integration
  - Github action to auto-add recipient keys
  - Github App to listen for webhooks on team membership changes and auto-update recipients.txt (see [Creating webhooks (Organization) - GitHub Docs](https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks#creating-an-organization-webhook))
- Rotate secrets regularly, can be done with  `sops`
- Secure CI logs: avoid printing secrets; GitHub masks known secrets, but custom blobs may not be redacted
-  Use environment-level secrets with mandatory approvals for production workflows
- Integration examples with [AWS Secret Parameter store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)


## ✨ Links
- [awesome-age](https://github.com/FiloSottile/awesome-age?tab=readme-ov-file)
- Use [agebox](https://github.com/slok/agebox), a utility specially designed for this exact purppose
- `.gitignore` preconfigured for private data files.
- [ssh-to-age](https://github.com/Mic92/ssh-to-age/tree/main) would allow this PoC to work with sops, makes thing even more conveniant as we can supports a `.sops.yaml` file describing the keys and yaml keys can be plaintext while their values are encrypted
- [`git-secrets`](https://github.com/awslabs/git-secrets) (pre-commit hook to detect indavertant secret commits)
- [`agec`](https://github.com/aca/agec)
- [`git-agecrypt`](https://github.com/vlaci/git-agecrypt).
- [`git-crypt`](https://github.com/AGWA/git-crypt),
- [`blackbox`](https://github.com/StackExchange/blackbox),
- https://github.com/FiloSottile/awesome-age?tab=readme-ov-file (all these projects are so much cooler than this PoC)
- https://agewasm.marin-basic.com/ (age web tool, try it now!)
- https://12factor.net/config
- https://www.stepsecurity.io/blog/github-actions-secrets-management-best-practices
- https://spectralops.io/blog/how-to-use-git-secrets-for-better-code-security
- https://webstandards.ca.gov/2023/04/19/github-best-practices
- https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
