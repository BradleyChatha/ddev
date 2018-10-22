#!/usr/bin/env dub run --single
/+ dub.sdl:
    name "ddev"
    dependency "scriptlike" version="~>0.10.2"
+/
module ddev;

import scriptlike;

// ========================
// = CONFIGURATION        =
// ========================
// = Stuff you can change =
// ========================
const SCRIPTLIKE_ECHO   = true;                                 // Whether scriptlike should echo it's commands.
const HOST_DC           = "dmd";                                // The host D compiler used.
                                                                // NOTE: If dmd has been compiled, and exists in the OUTPUT_BIN_FOLDER, then that will be used instead.

const GITHUB_USER_NAME  = "SealabJaster";                       // Your username on Github, this is used to download your forks of the repos.
const USER_REPO_MAP     = [PHOBOS_LINK_NAME];                   // Use this list to specify which projects should make use of your own forks. 
const OFFICIAL_REPO_MAP = [DRUNTIME_LINK_NAME, DMD_LINK_NAME];  // Use this list to specify which projects use the official version of the repos.

// ============================================
// = AUTO CONFIGURATION                       =
// ============================================
// = Stuff that you probably shouldn't change =
// ============================================
const OFFICIAL_GITHUB_USER_NAME = "dlang";                      // Username used to get the official versions of the repos.
const PHOBOS_LINK_NAME          = "phobos";                     // The name in the github link used to get the phobos repo.
const DRUNTIME_LINK_NAME        = "druntime";                   // ^^
const DMD_LINK_NAME             = "dmd";                        // ^^^^

enum PRECOMPILED_FOLDER        = Path("precompiled");          // The folder containing the precompiled stuff.
enum REPO_FOLDER               = Path("dmd2/src/");            // The folder to clone all the repos to.
enum OUTPUT_FOLDER             = Path("dmd2/output/") ;        // The folder where all the output folders and files go.
enum OUTPUT_BIN_FOLDER         = OUTPUT_FOLDER ~ Path("bin/"); // The folder where all the binaries are outputted. (dmd.exe's final resting place)
enum OUTPUT_LIB_FOLDER         = OUTPUT_FOLDER ~ Path("lib/"); // The folder where all the libraries are outputted. (phobos.lib's final resting place)
enum DMD_OUTPUT_PATH           = OUTPUT_BIN_FOLDER ~ Path(DMD_LINK_NAME ~ ".exe"); // The path to the DMD executable once compiled.

// A map of all the output files for each project, and where they should be copied to.
Path[string][string] OUTPUT_COPY_MAP;
void setupCopyMap()
{
    OUTPUT_COPY_MAP = 
    [
        DMD_LINK_NAME:
        [
            "dmd.exe": OUTPUT_BIN_FOLDER
        ],

        DRUNTIME_LINK_NAME: null,

        PHOBOS_LINK_NAME: 
        [
            "phobos.lib": OUTPUT_LIB_FOLDER
        ]
    ];
}

// The name of the makefile to use.
version(Windows) const MAKEFILE_NAME = "\"win32.mak\"";
else             static assert(false, "Need makefile name for this platformer");

// Some folder names used when moving over some precompiled files.
version(Windows)
{
    const PRECOMPILED_BIN_FOLDER = "bin";
    const PRECOMPILED_LIB_FOLDER = "lib";
}
else version(OSX)
{
    const PRECOMPILED_BIN_FOLDER = "bin";
    const PRECOMPILED_LIB_FOLDER = "lib";
}
else version(linux)
{
    version(X86)
    {
        const PRECOMPILED_BIN_FOLDER = "bin32";
        const PRECOMPILED_LIB_FOLDER = "lib32"; 
    }
    else version(X86_64)
    {
        const PRECOMPILED_BIN_FOLDER = "bin64";
        const PRECOMPILED_LIB_FOLDER = "lib64";
    }
    else
        static assert(false, "Not supported");
}
else
    static assert(false, "Need precompiled folder names for this platform.");

// Self-explanatory.
const HELP_STRING =
`Commands:
    build dmd [release/debug]=debug - Builds dmd in release/debug mode, defaults to debug.
    build druntime                  - Builds DRuntime.
    build phobos                    - Builds Phobos
    setup                           - The dev environment will be setup based on the configuration built with.
    help                            - Displays this helpful message.
`;

const POST_SETUP_HELP =
`################
## What next? ##
################
    The next step after setup is to use the 'ddev build' command to build
    druntime, dmd, and then phobos in that order.

    In general, whenever DMD needs to be updated, you should also update
    druntime, and vice-versa. Always build druntime before dmd.

    All the projects have had their upstream and origin setup based on your configuration,
    so for example after you've made whatever changes you want, you can use git to push to 
    your local repository, and then open a PR for it.
`;

// ====================
// = GLOBAL VARIABLES =
// ====================
Path[] pathStack; // Used by `pushLocation` and `popLocation`

// ==============================================
// = HELPER FUNCTIONS                           =
// ==============================================
// = Useful functions for creating the commands =
// ==============================================
string createRepoLink(string username, string repoName)
{
    failEnforceRepoName(repoName);
    return format("http://www.github.com/%s/%s", username, repoName);
}

Path getRepoLocation(string repoName)
{
    failEnforceRepoName(repoName);
    return REPO_FOLDER ~ Path(repoName);
}

void failEnforceRepoName(string repoName)
{
    bool failed = true;
    foreach(name; [DMD_LINK_NAME, DRUNTIME_LINK_NAME, PHOBOS_LINK_NAME])
    {
        if(name == repoName)
            failed = false;
    }

    if(failed)
        fail("No repo called '%s' exists.".format(repoName));
}

void downloadRepo(string username, string repoName)
{
    auto link = createRepoLink(username, repoName);
    auto path = getRepoLocation(repoName);

    // See if we even need to set it up.
    writefln("Checking for '%s'...", repoName);
    if(path.exists)
    {
        writefln("It seems that '%s' is already setup, skipping download.", repoName);
        return;
    }
    else
        mkdirRecurse(path);

    // Clone it
    writefln("'%s' doesn't seem to be setup, downloading...", repoName);
    pushLocation(REPO_FOLDER);
    run("git clone %s".format(link));
    pushLocation(getcwd() ~ Path(repoName));
    run("git remote add upstream %s".format(createRepoLink(OFFICIAL_GITHUB_USER_NAME, repoName)));
    popLocation();
    popLocation();

    writefln("The setup for '%s' has been completed.", repoName);
}

// Works the same way as Powershell's Push-Location
void pushLocation(Path newLocation)
{
    pathStack ~= getcwd();
    chdir(newLocation);
}

// Works the same way as Powershell's Pop-Location
void popLocation()
{
    assert(pathStack.length > 0, "Buuuuug");
    auto location = pathStack[$-1];
    pathStack.length -= 1;
    chdir(location);
}

void runMake(Args args = Args.init)
{
    run("make -f %s %s".format(MAKEFILE_NAME, args.data));
}

void setEnv(string envVar, string value)
{
    environment[envVar] = value;
    writefln("ENV VARIABLE '%s' SET TO '%s'", envVar, value);
}

// ============
// = COMMANDS =
// ============
void doSetup()
{
    // Copy over the precompiled files we need.
    failEnforce(PRECOMPILED_FOLDER.exists,
        "Please goto https://dlang.org/download.html and download the archive for your platform.\n"
        ~"Then, open it, and extract the 'dmd2/windows' 'dmd2/linux' 'dmd2/osx' etc. folder into the same folder as this tool.\n"
        ~"Rename this folder to '%s', and then you can continue with setup.".format(PRECOMPILED_FOLDER)
    );

    tryMkdirRecurse(OUTPUT_BIN_FOLDER);
    foreach(Path entry; dirEntries(PRECOMPILED_FOLDER ~ PRECOMPILED_BIN_FOLDER, SpanMode.breadth))
    {
        if(entry.existsAsDir || entry.baseName.toString().startsWith("dmd"))
            continue;

        copy(entry, OUTPUT_BIN_FOLDER ~ entry.baseName);
    }

    tryMkdirRecurse(OUTPUT_LIB_FOLDER);
    foreach(Path entry; dirEntries(PRECOMPILED_FOLDER ~ PRECOMPILED_LIB_FOLDER, SpanMode.breadth))
    {
        if(entry.existsAsDir)
            continue;

        copy(entry, OUTPUT_LIB_FOLDER ~ entry.baseName);
    }

    // Download the repos
    foreach(name; USER_REPO_MAP)
        downloadRepo(GITHUB_USER_NAME, name);

    foreach(name; OFFICIAL_REPO_MAP)
        downloadRepo(OFFICIAL_GITHUB_USER_NAME, name);

    writeln(POST_SETUP_HELP);
}

void doBuild(string repoName, string[] remainingArgs, Path[string] outputCopyMap)
{
    auto path = getRepoLocation(repoName);
    
    // Special case for dmd
    if(repoName == DMD_LINK_NAME)
        path ~= Path("src/");

    // Special case for druntime and phobos
    if(repoName == DRUNTIME_LINK_NAME || repoName == PHOBOS_LINK_NAME)
        remainingArgs ~= "DMD="~Path(environment["HOST_DC"]).toString();

    pushLocation(path);

    // Run make
    Args args;
    foreach(arg; remainingArgs)
        args ~= arg;
    runMake(args);
    popLocation();

    // Copy over all the files according to the map.
    foreach(file, output; outputCopyMap)
    {
        tryMkdirRecurse(output);
        copy(path ~ file, output ~ Path(file.baseName));
    }
}

void main(string[] args)
{
    scriptlikeEcho = SCRIPTLIKE_ECHO;

    setEnv("HOST_DC", DMD_OUTPUT_PATH.exists ? (getcwd() ~ DMD_OUTPUT_PATH).toString() : HOST_DC);

    setupCopyMap();

    if(args.length == 1)
        args ~= "help";

    switch(args[1])
    {
        case "build":
            failEnforce(args.length > 2, "Expected 1 arg for the 'build' command. ['phobos', 'druntime', 'dmd']");
            doBuild(args[2], (args.length == 3) ? [] : args[3..$], OUTPUT_COPY_MAP[args[2]]);
            break;

        case "setup":
            doSetup();
            break;

        case "help":
        default:
            writeln(HELP_STRING);
            break;
    }
}