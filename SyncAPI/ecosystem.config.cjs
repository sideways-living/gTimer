const path = require("node:path");

const appDirectory = __dirname;

module.exports = {
  apps: [
    {
      name: "gtimer-sync-api",
      cwd: appDirectory,
      script: path.join(appDirectory, "src/server.js"),
      args: "--port 8787",
      exec_mode: "fork",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "256M",
      env: {
        NODE_ENV: "production",
        PORT: "8787"
      }
    }
  ]
};
