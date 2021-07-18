#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# This script downloads and sets up the following tools:
#   - [JDK 8](https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/tag/jdk8u292-b10)
#   - [Apache Maven](https://maven.apache.org)
#   - [Changes-Matcher](https://github.com/conflito/changes-matcher)
#   - [EvoSuite](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict-with-latest-evosuiter-version)
#
# Usage:
# get_tools.sh
#
# ------------------------------------------------------------------------------

SCRIPT_DIR=$(cd `dirname $0` && pwd)

#
# Print error message to the stdout and exit.
#
die() {
  echo "$@" >&2
  exit 1
}

# ------------------------------------------------------------------------- Deps

# Check whether 'wget' is available
wget --version > /dev/null 2>&1 || die "[ERROR] Could not find 'wget'. Please install 'wget' and re-run the script."

# Check whether 'git' is available
git --version > /dev/null 2>&1 || die "[ERROR] Could not find 'git'. Please install 'git' and re-run the script."

# ------------------------------------------------------------------------- Main

OS_NAME=$(uname -s | tr "[:upper:]" "[:lower:]")
OS_ARCH=$(uname -m | tr "[:upper:]" "[:lower:]")

if ! grep -q ".*linux.*" <<< "$OS_NAME" && ! grep -q ".*darwin.*" <<< "$OS_NAME"; then
  die "[ERROR] All scripts have been developed and tested on Linux and MacOS machines! Please re-run the script on a Unix machine."
fi

#
# Download JDK...
#

echo ""
echo "Setting up JDK..."

JDK_VERSION="8u292"
JDK_BUILD_VERSION="b10"
JDK_FILE=""
if grep -q ".*linux.*" <<< "$OS_NAME"; then
  JDK_FILE="OpenJDK8U-jdk_x64_linux_hotspot_${JDK_VERSION}${JDK_BUILD_VERSION}.tar.gz"
elif grep -q ".*darwin.*" <<< "$OS_NAME"; then
  JDK_FILE="OpenJDK8U-jdk_x64_mac_hotspot_${JDK_VERSION}${JDK_BUILD_VERSION}.tar.gz"
fi
[ "$JDK_FILE" != "" ] || die
JDK_INSTALL_DIR="$SCRIPT_DIR/jdk${JDK_VERSION}-${JDK_BUILD_VERSION}"
JDK_URL="https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk${JDK_VERSION}-${JDK_BUILD_VERSION}/$JDK_FILE"

# Remove any previous file or directory
rm -rf "$SCRIPT_DIR/$JDK_FILE" "$JDK_INSTALL_DIR" "$SCRIPT_DIR/jdk-8"

# Get JDK distribution
wget -np -nv "$JDK_URL" -O "$SCRIPT_DIR/$JDK_FILE" || die "[ERROR] Download of '$JDK_URL' has failed!"
[ -s "$SCRIPT_DIR/$JDK_FILE" ] || die "[ERROR] '$SCRIPT_DIR/$JDK_FILE' does not exist or it is empty!"

# Extract it
mkdir -p "$JDK_INSTALL_DIR" || die "[ERROR] Failed to create '$JDK_INSTALL_DIR'!"
tar -xvzf "$SCRIPT_DIR/$JDK_FILE" -C "$SCRIPT_DIR" || die "[ERROR] Extraction of '$SCRIPT_DIR/$JDK_FILE' to '$JDK_INSTALL_DIR' has failed!"
[ -d "$JDK_INSTALL_DIR" ] || die "[ERROR] '$JDK_INSTALL_DIR' does not exist!"

# Create a symbolic link to the installed JDK distribution
ln -s "$JDK_INSTALL_DIR" "$SCRIPT_DIR/jdk-8" || die "[ERROR] Failed to create a symbolic link named '$SCRIPT_DIR/jdk-8' to '$JDK_INSTALL_DIR'!"

JDK_HOME=""
if grep -q ".*linux.*" <<< "$OS_NAME"; then
  JDK_HOME="$SCRIPT_DIR/jdk-8"
elif grep -q ".*darwin.*" <<< "$OS_NAME"; then
  JDK_HOME="$SCRIPT_DIR/jdk-8/Contents/Home"
fi
[ "$JDK_HOME" != "" ] || die
[ -d "$JDK_HOME" ]    || die

# Runtime check whether JDK has been properly installed, e.g., by checking
# whether 'javac' command is available
(export JAVA_HOME="$JDK_HOME"; export PATH="$JAVA_HOME/bin:$PATH"; javac -version > /dev/null 2>&1) || die "[ERROR] Could not find 'java/javac' executable."

#
# Download Apache Maven
#

echo ""
echo "Setting up Apache Maven..."

MVN_VERSION="3.8.1"
MVN_FILE="apache-maven-$MVN_VERSION-bin.tar.gz"
MVN_URL="https://mirrors.up.pt/pub/apache/maven/maven-3/$MVN_VERSION/binaries/$MVN_FILE"
MVN_INSTALL_DIR="$SCRIPT_DIR/apache-maven-$MVN_VERSION"

# Remove any previous file or directory
rm -rf "$SCRIPT_DIR/$MVN_FILE" "$MVN_INSTALL_DIR" "$SCRIPT_DIR/apache-maven"

# Get Apache Maven distribution
wget -np -nv "$MVN_URL" -O "$SCRIPT_DIR/$MVN_FILE" || die "[ERROR] Download of '$MVN_URL' has failed!"
[ -s "$SCRIPT_DIR/$MVN_FILE" ] || die "[ERROR] '$SCRIPT_DIR/$MVN_FILE' does not exist or it is empty!"

# Extract it
mkdir -p "$MVN_INSTALL_DIR" || die "[ERROR] Failed to create '$MVN_INSTALL_DIR'!"
tar -xvzf "$SCRIPT_DIR/$MVN_FILE" -C "$SCRIPT_DIR" || die "[ERROR] Extraction of '$SCRIPT_DIR/$MVN_FILE' to '$MVN_INSTALL_DIR' has failed!"
[ -d "$MVN_INSTALL_DIR" ] || die "[ERROR] '$MVN_INSTALL_DIR' does not exist!"

# Create a symbolic link to the installed Apache Maven distribution
ln -s "$MVN_INSTALL_DIR" "$SCRIPT_DIR/apache-maven" || die "[ERROR] Failed to create a symbolic link named '$SCRIPT_DIR/jdk-8' to '$MVN_INSTALL_DIR'!"

# Runtime check whether Apache Maven has been properly installed, e.g., by checking
# whether 'mvn' command is available
(export JAVA_HOME="$JDK_HOME"; export PATH="$JAVA_HOME/bin:$SCRIPT_DIR/apache-maven/bin:$PATH"; mvn -version > /dev/null 2>&1) || die "[ERROR] Could not find 'mvn' executable."

# Set up MVN_M2_HOME
MVN_M2_HOME="$SCRIPT_DIR/.m2"
rm -rf "$MVN_M2_HOME"; mkdir -p "$MVN_M2_HOME" || die "[ERROR] Failed to create '$MVN_M2_HOME'!"

#
# Download Changes-Matcher
#

echo ""
echo "Setting up Changes-Matcher..."

CHANGES_MATCHER_REPO_DIR="$SCRIPT_DIR/changes-matcher"
CHANGES_MATCHER_JAR_FILE="$SCRIPT_DIR/changes-matcher.jar"
CHANGES_MATCHER_GEN_JAR_FILE="$CHANGES_MATCHER_REPO_DIR/target/org.conflito.changes-matcher-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
CHANGES_MATCHER_BRANCH_NAME="master"
CHANGES_MATCHER_COMMIT_HASH="eae866508344d909bb13fae0a2eb14f2679c4415"

# Remove any previous file or directory
rm -rf "$CHANGES_MATCHER_REPO_DIR" "$CHANGES_MATCHER_JAR_FILE"

# Clone it
git clone https://github.com/conflito/changes-matcher.git "$CHANGES_MATCHER_REPO_DIR" || die "[ERROR] Clone of 'Changes-Matcher' repository has failed!"
[ -d "$CHANGES_MATCHER_REPO_DIR" ] || die "[ERROR] '$CHANGES_MATCHER_REPO_DIR' does not exist!"

# Build it
(export JAVA_HOME="$JDK_HOME"; export PATH="$JAVA_HOME/bin:$PATH"; cd "$CHANGES_MATCHER_REPO_DIR"; git checkout "$CHANGES_MATCHER_BRANCH_NAME"; git checkout "$CHANGES_MATCHER_COMMIT_HASH"; mvn clean package -Dmaven.repo.local="$MVN_M2_HOME" -DskipTests=true) || die "[ERROR] Failed to build 'Changes-Matcher'!"
[ -s "$CHANGES_MATCHER_GEN_JAR_FILE" ] || die "[ERROR] '$CHANGES_MATCHER_GEN_JAR_FILE' does not exist or it is empty!"

# Create a symbolic link to Changes-Matcher's distribution package
ln -s "$CHANGES_MATCHER_GEN_JAR_FILE" "$CHANGES_MATCHER_JAR_FILE" || die "[ERROR] Failed to create a symbolic link named '$CHANGES_MATCHER_JAR_FILE' to '$CHANGES_MATCHER_GEN_JAR_FILE'!"

#
# Download EvoSuite
#

echo ""
echo "Setting up EvoSuite..."

EVOSUITE_REPO_DIR="$SCRIPT_DIR/evosuite"
EVOSUITE_JAR_FILE="$SCRIPT_DIR/evosuite.jar"
EVOSUITE_GEN_JAR_FILE="$EVOSUITE_REPO_DIR/master/target/evosuite-master-1.0.7-SNAPSHOT.jar"
EVOSUITE_BRANCH_NAME="trigger-semantic-conflict"
EVOSUITE_COMMIT_HASH="cee583f23076b4bea032548c080c065ff54fbef1"

# Remove any previous file or directory
rm -rf "$EVOSUITE_REPO_DIR" "$EVOSUITE_JAR_FILE"

# Clone it
git clone https://github.com/conflito/evosuite.git "$EVOSUITE_REPO_DIR" || die "[ERROR] Clone of 'EvoSuite' repository has failed!"
[ -d "$EVOSUITE_REPO_DIR" ] || die "[ERROR] '$EVOSUITE_REPO_DIR' does not exist!"

# Build it
(export JAVA_HOME="$JDK_HOME"; export PATH="$JAVA_HOME/bin:$SCRIPT_DIR/apache-maven/bin:$PATH"; cd "$EVOSUITE_REPO_DIR"; git checkout "$EVOSUITE_BRANCH_NAME"; git checkout "$EVOSUITE_COMMIT_HASH"; mvn clean package -Dmaven.repo.local="$MVN_M2_HOME" -DskipTests=true) || die "[ERROR] Failed to build 'EvoSuite'!"
[ -s "$EVOSUITE_GEN_JAR_FILE" ] || die "[ERROR] '$EVOSUITE_GEN_JAR_FILE' does not exist or it is empty!"

# Create a symbolic link to EvoSuite's distribution package
ln -s "$EVOSUITE_GEN_JAR_FILE" "$EVOSUITE_JAR_FILE" || die "[ERROR] Failed to create a symbolic link named '$EVOSUITE_JAR_FILE' to '$EVOSUITE_GEN_JAR_FILE'!"

echo ""
echo "DONE! All tools have been successfully prepared."

# EOF
