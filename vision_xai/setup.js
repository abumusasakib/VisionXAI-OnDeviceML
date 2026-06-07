const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// Check if Node.js is installed
function checkNodeInstalled() {
  try {
    execSync("node -v", { stdio: "ignore" });
    console.log("Node.js is properly installed.");
    return true;
  } catch (error) {
    console.log("Node.js is not properly installed.");
    return false;
  }
}

// Install Node.js
function installNode() {
  console.log("Installing Node.js...");
  const platform = process.platform;
  const url =
    platform === "win32"
      ? "https://nodejs.org/dist/v18.17.1/node-v18.17.1-x64.msi"
      : "https://nodejs.org/dist/v18.17.1/node-v18.17.1.pkg";

  console.log(`Please download and install Node.js from ${url}`);
  console.log("After installing, please re-run this script.");
  process.exit(1);
}

// Check if Docker is installed
function checkDockerInstalled() {
  try {
    execSync("docker -v", { stdio: "ignore" });
    console.log("Docker is already installed.");
  } catch (error) {
    console.error("Docker is not installed.");

    const dockerUrl = {
      win32:
        "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe",
      darwin: "https://desktop.docker.com/mac/stable/Docker.dmg",
      linux: "https://docs.docker.com/engine/install/",
    };

    console.log(
      `Please download and install Docker from: ${
        dockerUrl[process.platform] || dockerUrl.linux
      }`
    );
    console.log("After installing Docker, please re-run this script.");
    process.exit(1);
  }
}

// Read Flutter version from `.fvmrc`
function getFlutterVersion() {
  try {
    const fvmrcPath = path.join(__dirname, ".fvmrc");
    const fvmrcContent = fs.readFileSync(fvmrcPath, "utf-8");
    const fvmrcJson = JSON.parse(fvmrcContent);
    return fvmrcJson.flutter;
  } catch (error) {
    console.error("Error reading .fvmrc file:", error.message);
    process.exit(1);
  }
}

// Extract package name from pubspec.yaml
function extractPackageName() {
  try {
    const pubspecPath = path.join(__dirname, "pubspec.yaml");
    const pubspecContent = fs.readFileSync(pubspecPath, "utf-8");

    const nameMatch = pubspecContent.match(/name:\s*(.*)/);
    if (nameMatch && nameMatch[1]) {
      return nameMatch[1].trim().toLowerCase();
    } else {
      console.error("Package name not found in pubspec.yaml");
      process.exit(1);
    }
  } catch (error) {
    console.error("Error reading pubspec.yaml:", error.message);
    process.exit(1);
  }
}

// Replace placeholder in Dockerfile.template and create Dockerfile
function generateDockerfile(flutterVersion) {
  try {
    const templatePath = path.join(__dirname, "Dockerfile.template");
    const dockerfilePath = path.join(__dirname, "Dockerfile");
    let dockerfileContent = fs.readFileSync(templatePath, "utf-8").trim();
    dockerfileContent = dockerfileContent.replace(
      "${FLUTTER_VERSION}",
      flutterVersion
    );
    dockerfileContent = dockerfileContent.replace(
      "$PACKAGE_NAME",
      extractPackageName()
    );
    fs.writeFileSync(dockerfilePath, dockerfileContent);
    console.log("Dockerfile created successfully.");
  } catch (error) {
    console.error("Error creating Dockerfile:", error.message);
    process.exit(1);
  }
}

// Function to create docker-compose.yml
function createDockerCompose() {
  const dockerComposePath = path.join(__dirname, "docker-compose.yml");

  if (fs.existsSync(dockerComposePath)) {
    console.log("docker-compose.yml already exists. Skipping creation.");
    return;
  }

  const dockerComposeContent = `
version: '3.8'

services:
  flutter-build:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${extractPackageName()}-container
    volumes:
      - ./build:/app/build
    ports:
      - "5000:5000"
    command: /bin/bash -c "
      flutter build apk --release &&
      flutter build web --release &&
      cp /output/${extractPackageName()}-release.apk /app/build/ &&
      serve -s /app/build/web -l 5000"
    restart: "no"
    stop_grace_period: 30s
`.trim();

  try {
    fs.writeFileSync(dockerComposePath, dockerComposeContent);
    console.log("docker-compose.yml created successfully.");
  } catch (error) {
    console.error("Error creating docker-compose.yml:", error.message);
    process.exit(1);
  }
}

// Build the Docker image
function buildDockerImage(flutterVersion) {
  try {
    execSync(
      `docker build --build-arg FLUTTER_VERSION=${flutterVersion} --build-arg PACKAGE_NAME=${extractPackageName()} -t ${extractPackageName()} .`,
      { stdio: "inherit" }
    );
    console.log("Docker image built successfully.");
  } catch (error) {
    console.error("Error building Docker image:", error.message);
    process.exit(1);
  }
}

// Clean up generated Dockerfile
function cleanUp() {
  const dockerfilePath = path.join(__dirname, "Dockerfile");
  if (fs.existsSync(dockerfilePath)) {
    fs.unlinkSync(dockerfilePath);
    console.log("Temporary Dockerfile deleted.");
  }
}

// Extract app version from pubspec.yaml
function extractVersion() {
  try {
    const pubspecPath = path.join(__dirname, "pubspec.yaml");
    const pubspecContent = fs.readFileSync(pubspecPath, "utf-8");

    const versionMatch = pubspecContent.match(/version:\s*(.*)/);
    if (versionMatch && versionMatch[1]) {
      return versionMatch[1].trim().split("+")[0];
    } else {
      console.error("Version not found in pubspec.yaml");
      process.exit(1);
    }
  } catch (error) {
    console.error("Error reading version from pubspec.yaml:", error.message);
    process.exit(1);
  }
}

// Export functions for use in GitHub Actions
module.exports = {
  checkNodeInstalled,
  checkDockerInstalled,
  getFlutterVersion,
  extractPackageName,
  extractVersion,
  generateDockerfile,
  createDockerCompose,
  buildDockerImage,
  cleanUp,
};

// Main execution (only if called directly)
if (require.main === module) {
  (async function main() {
    if (!checkNodeInstalled()) {
      installNode();
    }

    checkDockerInstalled();

    const flutterVersion = getFlutterVersion();
    console.log(`Flutter version found in .fvmrc: ${flutterVersion}`);

    generateDockerfile(flutterVersion);
    createDockerCompose();

    try {
      execSync("docker-compose up --build", { stdio: "inherit" });
    } catch (error) {
      console.error("Error running docker-compose up:", error.message);
      console.error("Maybe you need to run docker compose up --build instead?");
      process.exit(1);
    }

    cleanUp();
  })();
}
