const fs = require("fs");
const path = require("path");
const paths = require("../../utils/paths");
const functions = require("../../utils/functions");
const os = require("os");
const { spawn } = require("child_process");

let self = module.exports = {
    commandInfo: {
        info: "This command is used to launch Need for Speed World.",
        helpInfo: "Select nfsw.exe and launch the game through Wine.",
        extraInfo:
            "-- Selected nfsw.exe path is saved into config.\n" +
            "-- The game is launched through Wine.\n" +
            "-- NFS World is limited to a maximum of 8 CPU cores because higher counts may cause instability.",
        name: "play",
    },

    execute: async (args, readline) => {
        if (process.platform === "win32") {
            console.log("\nPlease use the Windows version of this command.");
            return;
        }

        console.log(`\n${self.commandInfo.info}\n\n${self.commandInfo.extraInfo}`);

        const configPath = path.join(paths.configPath, "config.json");
        const configData = JSON.parse(fs.readFileSync(configPath).toString());

        console.log(
            `\nCurrent selected nfsw.exe file path: "${configData.nfswFilePath || "NONE"}".`
        );

        console.log(
            `\nChoose an action:\n` +
            ` [0] Select - Set the nfsw.exe file path.\n` +
            ` [1] Launch - Run Need for Speed World.`
        );

        const optionSelect = await functions.askQuestion(
            "\nEnter a number: ",
            readline
        );

        const actionOptionNum = Number.isInteger(parseInt(optionSelect))
            ? parseInt(optionSelect)
            : -1;

        switch (actionOptionNum) {
            case 0: {
                let filePath;

                try {
                    console.log(
                        "\nOpening file picker. Please select nfsw.exe."
                    );

                    filePath = await selectNfswExe(
                        path.dirname(
                            configData.nfswFilePath || process.cwd()
                        )
                    );
                } catch {
                    console.log(
                        "\nFailed to open file picker. Manual input required."
                    );

                    filePath = (
                        await functions.askQuestion(
                            "Enter the file path: ",
                            readline
                        )
                    )
                        .trim()
                        .replace(/"/g, "");
                }

                if (!checkExeValid(filePath)) {
                    console.log(
                        "\nInvalid nfsw.exe file path, cancelling operation."
                    );
                    break;
                }

                configData.nfswFilePath = filePath;

                fs.writeFileSync(
                    configPath,
                    JSON.stringify(configData, null, 4)
                );

                console.log(
                    `\nSuccessfully changed the nfsw.exe file path to "${filePath}".`
                );

                break;
            }

            case 1: {
                if (!checkExeValid(configData.nfswFilePath)) {
                    console.log(
                        "\nInvalid nfsw.exe file path, cancelling operation."
                    );
                    break;
                }

                console.log(
                    `\nLaunching Need for Speed World at "${configData.nfswFilePath}".`
                );

                try {
                    launchNfsw(configData.nfswFilePath);
                } catch (err) {
                    console.error(
                        "\nFailed to launch nfsw.exe:",
                        err.message
                    );
                }

                break;
            }

            default: {
                console.log("\nInvalid action, cancelling operation.");
                break;
            }
        }
    },
};

function checkExeValid(filePath) {
    if (typeof filePath !== "string") return false;

    if (
        !path.basename(filePath).toLowerCase().endsWith(".exe")
    ) {
        return false;
    }

    try {
        return fs.statSync(filePath).isFile();
    } catch {
        return false;
    }
}

function buildCpuList(maxCpuCount) {
    const cpuCount = os.cpus().length;
    const n = Math.min(Math.max(1, cpuCount), maxCpuCount);

    return Array.from({ length: n }, (_, i) => i).join(",");
}

function attemptFileDelete(filePath) {
    try {
        (fs.rmSync ?? fs.unlinkSync)(filePath);
    } catch {}
}

function launchNfsw(nfswExePath) {
    attemptFileDelete(
        path.join(path.dirname(nfswExePath), ".links")
    );

    const cpuList = buildCpuList(8);

    const args = [
        "-c",
        cpuList,
        "wine",
        nfswExePath,
        `US`,
        `http://${functions.getHost()}/Engine.svc`,
        "a",
        "1",
    ];

    const child = spawn("taskset", args, {
        detached: true,
        stdio: "ignore",
    });

    child.on("error", (err) => {
        console.error("\nFailed to start:", err);
    });

    child.unref();
}

async function selectNfswExe(startDir) {
    return new Promise((resolve, reject) => {
        const child = spawn("zenity", [
            "--file-selection",
            "--title=Select nfsw.exe",
            `--filename=${path.join(startDir, "/")}`,
            "--file-filter=*.exe",
        ]);

        let stdout = "";
        let stderr = "";

        child.stdout.on("data", (d) => {
            stdout += d.toString();
        });

        child.stderr.on("data", (d) => {
            stderr += d.toString();
        });

        child.on("close", (code) => {
            if (code !== 0) {
                reject(
                    new Error(stderr || "File picker cancelled")
                );
                return;
            }

            resolve(stdout.trim());
        });

        child.on("error", reject);
    });
}