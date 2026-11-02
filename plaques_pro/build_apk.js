#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const root = __dirname;
const run = (cmd, args) => {
  console.log(`\n> ${cmd} ${args.join(" ")}`);
  const r = spawnSync(cmd, args, { cwd: root, stdio: "inherit", shell: process.platform === "win32" });
  if (r.error) { console.error(r.error.message); process.exit(1); }
  if (r.status !== 0) process.exit(r.status || 1);
};
if (!fs.existsSync(path.join(root, "pubspec.yaml")) || !fs.existsSync(path.join(root, "lib", "main.dart"))) {
  console.error("Execute this script from the Plaques Pro project root."); process.exit(1);
}
const check = spawnSync("flutter", ["--version"], { encoding: "utf8", shell: process.platform === "win32" });
if (check.error || check.status !== 0) {
  console.error("Flutter SDK not found. Install Flutter and add flutter/bin to PATH."); process.exit(1);
}
console.log(check.stdout.split("\n").slice(0, 2).join("\n"));
const android = path.join(root, "android");
if (!fs.existsSync(android)) {
  run("flutter", ["create", "--platforms=android", "--org", "ma.plaques", "--project-name", "plaques_pro_copy", "."]);
}
run("flutter", ["pub", "get"]);
run("flutter", ["analyze"]);
run("flutter", ["build", "apk", "--release"]);
const source = path.join(root, "build", "app", "outputs", "flutter-apk", "app-release.apk");
if (!fs.existsSync(source)) { console.error("APK output not found: " + source); process.exit(1); }
const out = path.join(root, "dist");
fs.mkdirSync(out, { recursive: true });
const target = path.join(out, "PlaquesPro-V2-release.apk");
fs.copyFileSync(source, target);
console.log("\nAPK created: " + target);
