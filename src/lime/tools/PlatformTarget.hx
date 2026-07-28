package lime.tools;

import haxe.Timer;
import haxe.rtti.Meta;
import hxp.*;
import lime.tools.AssetHelper;
import lime.tools.CommandHelper;
import sys.FileSystem;
import sys.io.File;

class PlatformTarget
{
	public var additionalArguments:Array<String>;
	public var buildType:String;
	public var command:String;
	public var noOutput:Bool;
	public var project:HXProject;
	public var targetDirectory:String;
	public var targetFlags:Map<String, String>;
	public var traceEnabled = true;

	public function new(command:String = null, project:HXProject = null, targetFlags:Map<String, String> = null)
	{
		this.command = command;
		this.project = project;
		this.targetFlags = targetFlags;

		buildType = "release";

		if (project != null)
		{
			if (project.debug)
			{
				buildType = "debug";
			}
			else if (project.targetFlags.exists("final"))
			{
				buildType = "final";
			}
		}

		for (haxeflag in project.haxeflags)
		{
			if (haxeflag == "--no-output")
			{
				noOutput = true;
			}
		}
	}

	public function execute(additionalArguments:Array<String>):Void
	{
		// Log.info ("", Log.accentColor + "Using target platform: " + Std.string (project.target).toUpperCase () + Log.resetColor);

		this.additionalArguments = additionalArguments;
		var metaFields = Meta.getFields(Type.getClass(this));

		// known issue: this may not log in `-eval` mode on Linux
		inline function logCommand(command:String):Void
		{
			if (!Reflect.hasField(metaFields, command)
				|| !Reflect.hasField(Reflect.field(metaFields, command), "ignore"))
			{
				emitStage(getCommandStageLabel(command));
			}
		}

		if (project.targetFlags.exists("watch"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: WATCH" + Log.resetColor);
			watch();
			return;
		}

		if (command == "display")
		{
			display();
		}

		// if (command == "clean" || project.targetFlags.exists ("clean")) {
		if (command == "clean"
			|| (project.targetFlags.exists("clean") && (command == "update" || command == "build" || command == "test")))
		{
			logCommand("CLEAN");
			var started = Timer.stamp();
			clean();
			emitStageSummary("Completed clean", started);
		}

		if (command == "rebuild" || project.targetFlags.exists("rebuild"))
		{
			logCommand("REBUILD");

			// hack for now, need to move away from project.rebuild.path, probably

			if (project.targetFlags.exists("rebuild"))
			{
				project.config.set("project.rebuild.path", null);
			}

			var started = Timer.stamp();
			rebuild();
			emitStageSummary("Completed rebuild", started);
		}

		if (command == "update" || command == "build" || command == "test")
		{
			logCommand("update");
			// #if lime
			// AssetHelper.processLibraries (project, targetDirectory);
			// #end
			var started = Timer.stamp();
			update();
			emitStageSummary("Prepared project", started);
		}

		if (command == "build" || command == "test")
		{
			CommandHelper.executeCommands(project.preBuildCallbacks);

			logCommand("build");
			var started = Timer.stamp();
			build();
			emitStageSummary("Build stage complete", started);

			CommandHelper.executeCommands(project.postBuildCallbacks);
		}

		if (command == "deploy")
		{
			logCommand("deploy");
			var started = Timer.stamp();
			deploy();
			emitStageSummary("Deployment complete", started);
		}

		if (command == "install" || command == "run" || command == "test")
		{
			logCommand("install");
			var started = Timer.stamp();
			install();
			emitStageSummary("Install stage complete", started);
		}

		if (command == "run" || command == "rerun" || command == "test")
		{
			logCommand("run");
			var started = Timer.stamp();
			run();
			emitStageSummary("Launch stage complete", started);
		}

		if ((command == "test" || command == "trace" || command == "run" || command == "rerun")
			&& (traceEnabled || command == "trace"))
		{
			logCommand("trace");
			var started = Timer.stamp();
			this.trace();
			emitStageSummary("Trace stage complete", started);
		}

		if (command == "uninstall")
		{
			logCommand("UNINSTALL");
			var started = Timer.stamp();
			uninstall();
			emitStageSummary("Uninstall complete", started);
		}
	}

	public function emitStage(label:String):Void
	{
		Log.println("\n" + Log.accentColor + "[Stage] " + label + Log.resetColor);
	}

	public function emitStageSummary(label:String, started:Float):Void
	{
		var elapsed = Timer.stamp() - started;
		Log.println(label + " in " + (Std.int(elapsed * 10) / 10) + "s");
	}

	public function getCommandStageLabel(command:String):String
	{
		return switch (command.toLowerCase())
		{
			case "clean": "Cleaning target";
			case "rebuild": "Rebuilding native libraries";
			case "update": "Preparing project assets";
			case "build": "Building application";
			case "deploy": "Packaging output";
			case "install": "Installing application";
			case "run": "Launching application";
			case "trace": "Streaming logs";
			case "uninstall": "Removing application";
			default: "Running " + command.toLowerCase();
		}
	}

	public function runHaxeWithSourceCheck(args:Array<String>):Void
	{
		var hxml:String = null;
		for (arg in args)
		{
			if (arg != null && StringTools.endsWith(arg.toLowerCase(), ".hxml") && FileSystem.exists(arg))
			{
				hxml = arg;
				break;
			}
		}

		if (hxml != null)
			showHaxeSourceCheck(hxml);

		emitStage("Running Haxe compiler");
		System.runCommand("", "haxe", args);
	}

	public function showHaxeSourceCheck(hxml:String):Void
	{
		var startTime = Timer.stamp();
		var classPaths:Array<String> = [];
		collectHxmlClassPaths(hxml, classPaths, new Map<String, Bool>());

		if (classPaths.length == 0)
			return;

		var files:Array<String> = [];
		collectHxFiles(classPaths, files);

		if (files.length == 0)
			return;

		files.sort(function(a, b) return Reflect.compare(a, b));

		var engineFiles:Array<String> = [];
		var generatedFiles:Array<String> = [];
		var libraryFiles:Array<String> = [];

		for (file in files)
		{
			if (isGeneratedSourcePath(file))
				generatedFiles.push(file);
			else if (isProjectSourcePath(file))
				engineFiles.push(file);
			else
				libraryFiles.push(file);
		}

		emitStage("Scanning Haxe sources");
		Log.println("Checking Haxe source files: "
			+ files.length
			+ " ("
			+ engineFiles.length
			+ " engine, "
			+ generatedFiles.length
			+ " generated, "
			+ libraryFiles.length
			+ " libraries)");

		if (engineFiles.length > 0)
			showSourceProgress("Engine source", engineFiles);

		if (generatedFiles.length > 0)
			showSourceProgress("Generated source", generatedFiles);

		if (libraryFiles.length > 0)
			showSourceProgress("Library source", libraryFiles);

		Log.println('Scanned ' + files.length + ' source files in ' + (Std.int((Timer.stamp() - startTime) * 10) / 10) + 's');
	}

	public function showSourceProgress(label:String, files:Array<String>):Void
	{
		var supportsAnsi = (Sys.getEnv("ANSICON") != null
			|| Sys.getEnv("WT_SESSION") != null
			|| Sys.getEnv("ConEmuANSI") == "ON"
			|| Sys.getEnv("TERM") == "xterm"
			|| Sys.getEnv("TERM_PROGRAM") != null);

		var green = supportsAnsi ? "\x1b[32m" : "";
		var yellow = supportsAnsi ? "\x1b[33m" : "";
		var red = supportsAnsi ? "\x1b[31m" : "";
		var reset = supportsAnsi ? "\x1b[0m" : "";
		var width = 20;
		var total = files.length;
		var previousLineLength = 0;
		var liveOutputInitialized = false;
		var lastPercent = -1;

		Log.println(label + ": " + total + " files");

		for (i in 0...total)
		{
			var current = i + 1;
			var percent = Std.int((current / total) * 100);
			if (percent > 100) percent = 100;
			if (percent == lastPercent && current < total) continue;
			lastPercent = percent;

			var full = Std.int(percent / 5);
			var rem = percent % 5;
			var half = rem >= 3 && full < width;
			var empty = width - full - (half ? 1 : 0);

			var bar = "";
			for (j in 0...full) bar += green + "#" + reset;
			if (half) bar += yellow + "=" + reset;
			for (j in 0...empty) bar += red + "-" + reset;

			var file = files[i].split("\\").join("/");
			if (file.length > 95)
				file = "..." + file.substr(file.length - 92);

			var flatBar = "";
			for (j in 0...full) flatBar += "#";
			if (half) flatBar += "=";
			for (j in 0...empty) flatBar += "-";

			var progressLine = "[" + flatBar + "] " + percent + "%";
			var plainLine = progressLine + " " + file;
			var displayLine = "[" + bar + "] " + percent + "%";

			if (supportsAnsi)
			{
				if (!liveOutputInitialized)
				{
					Sys.print("\n\n");
					liveOutputInitialized = true;
				}
				Sys.print("\x1b[2A\r\x1b[2K" + displayLine + "\n\x1b[2K" + file + "\n");
			}
			else
			{
				var padCount = previousLineLength - plainLine.length;
				if (padCount < 0) padCount = 0;
				var pad = "";
				for (j in 0...padCount) pad += " ";
				Sys.print("\r" + plainLine + pad);
				previousLineLength = plainLine.length;
			}
		}

		Sys.println("");
	}

	public function collectHxmlClassPaths(hxml:String, out:Array<String>, visited:Map<String, Bool>):Void
	{
		var normalized = Path.tryFullPath(hxml);
		if (visited.exists(normalized) || !FileSystem.exists(normalized))
			return;

		visited.set(normalized, true);
		var baseDir = Path.directory(normalized);
		var lines = ~/\r\n|\r|\n/g.split(File.getContent(normalized));

		for (line in lines)
		{
			var l = StringTools.trim(line);
			if (l == "" || StringTools.startsWith(l, "#"))
				continue;

			if (StringTools.startsWith(l, "-cp ") || StringTools.startsWith(l, "--class-path "))
			{
				var cp = StringTools.trim(l.substr(l.indexOf(" ") + 1));
				if (cp != "")
				{
					if (!Path.isAbsolute(cp))
					{
						var projectPath = project != null ? Path.combine(project.workingDirectory, cp) : cp;
						cp = FileSystem.exists(projectPath) ? projectPath : Path.combine(baseDir, cp);
					}
					cp = Path.tryFullPath(cp);
					if (FileSystem.exists(cp) && FileSystem.isDirectory(cp))
						out.push(cp);
				}
			}
			else if (!StringTools.startsWith(l, "-") && StringTools.endsWith(l.toLowerCase(), ".hxml"))
			{
				var nested = l;
				if (!Path.isAbsolute(nested))
				{
					var projectNested = project != null ? Path.combine(project.workingDirectory, nested) : nested;
					nested = FileSystem.exists(projectNested) ? projectNested : Path.combine(baseDir, nested);
				}
				collectHxmlClassPaths(nested, out, visited);
			}
		}
	}

	public function collectHxFiles(classPaths:Array<String>, out:Array<String>):Void
	{
		var seen = new Map<String, Bool>();
		for (cp in classPaths)
			collectHxFilesRecursive(cp, out, seen);
	}

	public function collectHxFilesRecursive(dir:String, out:Array<String>, seen:Map<String, Bool>):Void
	{
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
			return;

		for (entry in FileSystem.readDirectory(dir))
		{
			var full = Path.combine(dir, entry);
			if (FileSystem.isDirectory(full))
			{
				if (shouldScanHxDirectory(full, entry))
					collectHxFilesRecursive(full, out, seen);
			}
			else if (StringTools.endsWith(entry.toLowerCase(), ".hx"))
			{
				var normalized = Path.tryFullPath(full);
				if (!seen.exists(normalized))
				{
					seen.set(normalized, true);
					out.push(normalized);
				}
			}
		}
	}

	public function shouldScanHxDirectory(dir:String, entry:String):Bool
	{
		var lower = entry.toLowerCase();
		if (StringTools.startsWith(lower, ".")) return false;
		if (isGeneratedSourcePath(dir)) return true;
		if (isProjectSourcePath(dir)) return true;
		return ["sample", "samples", "example", "examples", "test", "tests", "doc", "docs"].indexOf(lower) == -1;
	}

	public function isGeneratedSourcePath(path:String):Bool
	{
		if (targetDirectory == null || targetDirectory == "") return false;

		var normalized = normalizeSourcePath(path);
		var target = normalizeSourcePath(targetDirectory);

		if (!StringTools.endsWith(target, "/")) target += "/";
		return StringTools.startsWith(normalized, target);
	}

	public function isProjectSourcePath(path:String):Bool
	{
		if (project == null || project.workingDirectory == null || project.workingDirectory == "") return false;

		var normalized = normalizeSourcePath(path);
		var workingDirectory = normalizeSourcePath(project.workingDirectory);


		if (!StringTools.endsWith(workingDirectory, "/")) workingDirectory += "/";
		return StringTools.startsWith(normalized, workingDirectory);
	}

	public function normalizeSourcePath(path:String):String
	{
		var normalized = Path.standardize(Path.tryFullPath(path));

		if (Sys.systemName() == "Windows")
			normalized = normalized.toLowerCase();

		return normalized;
	}

	@ignore public function build():Void {}

	@ignore public function clean():Void {}

	@ignore public function deploy():Void {}

	@ignore public function display():Void {}

	@ignore public function install():Void {}

	@ignore public function rebuild():Void {}

	@ignore public function run():Void {}

	@ignore public function trace():Void {}

	@ignore public function uninstall():Void {}

	@ignore public function update():Void {}

	@ignore public function watch():Void {}
}
