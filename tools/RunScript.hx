package;

import hxp.*;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;

class RunScript
{
	private static final MEME_VIDEO_EXTENSIONS:Array<String> = [".mp4", ".webm", ".mov", ".avi", ".mkv", ".wmv"];

	private static function rebuildTools(rebuildBinaries = true):Void
	{
		var limeDirectory = Haxelib.getPath(new Haxelib("lime"), true);
		var toolsDirectory = Path.combine(limeDirectory, "tools");

		if (!FileSystem.exists(toolsDirectory))
		{
			toolsDirectory = Path.combine(limeDirectory, "../tools");
		}

		/*var extendedToolsDirectory = Haxelib.getPath (new Haxelib ("lime-extended"), false);

			if (extendedToolsDirectory != null && extendedToolsDirectory != "") {

				var buildScript = File.getContent (Path.combine (extendedToolsDirectory, "tools.hxml"));
				buildScript = StringTools.replace (buildScript, "\r\n", "\n");
				buildScript = StringTools.replace (buildScript, "\n", " ");

				System.runCommand (toolsDirectory, "haxe", buildScript.split (" "));

		} else {*/

		System.runCommand(toolsDirectory, "haxe", ["tools.hxml"]);

		// }

		if (!rebuildBinaries) return;

		var platforms = ["Windows", "Mac", "Mac64", "MacArm64", "Linux", "Linux64"];

		for (platform in platforms)
		{
			var source = Path.combine(limeDirectory, "ndll/" + platform + "/lime.ndll");
			// var target = Path.combine (toolsDirectory, "ndll/" + platform + "/lime.ndll");

			if (!FileSystem.exists(source))
			{
				var args = ["tools/tools.n", "rebuild", "lime", "-release", "-nocffi"];

				if (Log.verbose)
				{
					args.push("-verbose");
				}

				if (!Log.enableColor)
				{
					args.push("-nocolor");
				}

				switch (platform)
				{
					case "Windows":
						if (System.hostPlatform == WINDOWS)
						{
							System.runCommand(limeDirectory, "neko", args.concat(["windows", toolsDirectory]));
						}

					case "Mac", "Mac64", "MacArm64":
						if (System.hostPlatform == MAC)
						{
							System.runCommand(limeDirectory, "neko", args.concat(["mac", toolsDirectory]));
						}

					case "Linux":
						if (System.hostPlatform == LINUX && System.hostArchitecture != X64)
						{
							System.runCommand(limeDirectory, "neko", args.concat(["linux", "-32", toolsDirectory]));
						}

					case "Linux64":
						if (System.hostPlatform == LINUX && System.hostArchitecture == X64)
						{
							System.runCommand(limeDirectory, "neko", args.concat(["linux", "-64", toolsDirectory]));
						}
				}
			}

			if (!FileSystem.exists(source))
			{
				if (Log.verbose)
				{
					Log.warn("", "Source path \"" + source + "\" does not exist");
				}
			}
			else
			{
				// System.copyIfNewer (source, target);
			}
		}
	}

	public static function runCommand(path:String, command:String, args:Array<String>, throwErrors:Bool = true):Int
	{
		var oldPath:String = "";

		if (path != null && path != "")
		{
			oldPath = Sys.getCwd();

			try
			{
				Sys.setCwd(path);
			}
			catch (e:Dynamic)
			{
				Log.error("Cannot set current working directory to \"" + path + "\"");
			}
		}

		var captureForMeme = shouldCaptureForMeme(command, args);
		var captureSuffix = captureForMeme ? temporaryCaptureSuffix() : null;
		var outputPath = captureForMeme ? getTemporaryPath("lime-error-output-" + captureSuffix + ".txt") : null;
		var result:Dynamic = captureForMeme ? runCommandWithOutputCapture(command, args, outputPath, captureSuffix) : Sys.command(command, args);

		if (oldPath != "")
		{
			Sys.setCwd(oldPath);
		}

		if (throwErrors && result != 0)
		{
			showMemeErrorVideo(outputPath, result);
			Sys.exit(1);
		}

		return result;
	}

	private static function shouldCaptureForMeme(command:String, args:Array<String>):Bool
	{
		if (Sys.systemName() != "Windows") return false;
		if (command == null || args == null || args.length < 1) return false;
		return Path.withoutDirectory(command).toLowerCase() == "neko" && StringTools.replace(args[0], "\\", "/") == "tools/tools.n";
	}

	private static function temporaryCaptureSuffix():String
	{
		return Std.string(Date.now().getTime()).split(".").join("") + "-" + Std.string(Std.int(Math.random() * 0xFFFFFF));
	}

	private static function runCommandWithOutputCapture(command:String, args:Array<String>, outputPath:String, captureSuffix:String):Int
	{
		var scriptPath = getTemporaryPath("lime-error-capture-" + captureSuffix + ".ps1");
		var commandPath = getTemporaryPath("lime-error-command-" + captureSuffix + ".bat");
		var commandLine = ([cmdQuote(command)].concat([for (arg in args) cmdQuote(arg)])).join(" ");
		var script = [];
		var output = psQuote(outputPath);
		File.saveContent(commandPath, "@echo off\r\n" + commandLine + " 2>&1\r\nexit /b %ERRORLEVEL%\r\n");
		script.push("$ErrorActionPreference = 'Continue'");
		script.push("$commandFile = " + psQuote(commandPath));
		script.push("$startInfo = New-Object System.Diagnostics.ProcessStartInfo");
		script.push("$startInfo.FileName = 'cmd.exe'");
		script.push("$startInfo.Arguments = '/d /c \"' + $commandFile + '\"'");
		script.push("$startInfo.UseShellExecute = $false");
		script.push("$startInfo.RedirectStandardOutput = $true");
		script.push("$startInfo.RedirectStandardError = $false");
		script.push("$startInfo.CreateNoWindow = $false");
		script.push("$process = New-Object System.Diagnostics.Process");
		script.push("$process.StartInfo = $startInfo");
		script.push("$console = [Console]::OpenStandardOutput()");
		script.push("$file = $null");
		script.push("$file = [System.IO.File]::Open(" + output + ", [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)");
		script.push("$buffer = New-Object byte[] 4096");
		script.push("$null = $process.Start()");
		script.push("try {");
		script.push("    while (($read = $process.StandardOutput.BaseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {");
		script.push("        $console.Write($buffer, 0, $read)");
		script.push("        $console.Flush()");
		script.push("        if ($file -ne $null) {");
		script.push("            $file.Write($buffer, 0, $read)");
		script.push("            $file.Flush()");
		script.push("        }");
		script.push("    }");
		script.push("    $process.WaitForExit()");
		script.push("    $exitCode = $process.ExitCode");
		script.push("} finally {");
		script.push("    if ($file -ne $null) { $file.Dispose() }");
		script.push("    if ($process -ne $null) { $process.Dispose() }");
		script.push("}");
		script.push("exit $exitCode");
		File.saveContent(scriptPath, script.join("\n"));
		return Sys.command("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath]);
	}

	private static function showMemeErrorVideo(outputPath:String, exitCode:Int):Void
	{
		var video = findMemeErrorVideo();
		if (video == null) return;

		var title = getErrorTitle(outputPath, exitCode);
		var cause = getErrorCause(outputPath, exitCode);
		var causePath = getTemporaryRunPath("lime-error-cause.txt");
		var scriptPath = getTemporaryRunPath("lime-meme-error-player.ps1");
		File.saveContent(causePath, cause);
		File.saveContent(scriptPath, getMemePlayerScript());
		Sys.command("powershell.exe", [
			"-STA",
			"-NoProfile",
			"-ExecutionPolicy", "Bypass",
			"-File", scriptPath,
			"-Video", video,
			"-Title", title,
			"-CausePath", causePath
		]);
	}

	private static function findMemeErrorVideo():String
	{
		var limeDirectory = Haxelib.getPath(new Haxelib("lime"), true);
		var folders = [
			Path.combine(limeDirectory, "assets/meme-error"),
			Path.combine(Sys.getCwd(), "assets/meme-error")
		];
		var videos = [];

		for (folder in folders)
		{
			if (folder == null || !FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;

			for (file in FileSystem.readDirectory(folder))
			{
				var fullPath = Path.combine(folder, file);
				if (!FileSystem.exists(fullPath) || FileSystem.isDirectory(fullPath)) continue;

				var lower = file.toLowerCase();
				for (extension in MEME_VIDEO_EXTENSIONS)
				{
					if (StringTools.endsWith(lower, extension))
					{
						videos.push(fullPath);
						break;
					}
				}
			}
		}

		return videos.length > 0 ? videos[Std.random(videos.length)] : null;
	}

	private static function getErrorTitle(outputPath:String, exitCode:Int):String
	{
		if (outputPath != null && FileSystem.exists(outputPath))
		{
			var content = File.getContent(outputPath);
			content = StringTools.replace(content, "\r\n", "\n");
			content = StringTools.replace(content, "\r", "\n");
			var lines = content.split("\n");
			for (line in lines)
			{
				var clean = normalizeTitle(line);
				if (clean != "" && isErrorDetailLine(clean)) return clean;
			}
		}

		return "Lime build failed with exit code " + exitCode;
	}

	private static function getErrorCause(outputPath:String, exitCode:Int):String
	{
		if (outputPath == null || !FileSystem.exists(outputPath))
		{
			return "Lime exited with code " + exitCode + ". No captured output was available.";
		}

		var content = File.getContent(outputPath);
		content = StringTools.replace(content, "\r\n", "\n");
		content = StringTools.replace(content, "\r", "\n");
		var lines = content.split("\n");
		var cleanLines:Array<String> = [];
		for (line in lines)
		{
			var clean = normalizeDetailLine(line);
			if (isProgressNoiseLine(clean)) continue;
			if (clean != "") cleanLines.push(clean);
		}

		if (cleanLines.length == 0)
		{
			return "Lime exited with code " + exitCode + ". The command did not print a useful error message.";
		}

		var firstErrorLine = -1;
		for (i in 0...cleanLines.length)
		{
			if (isErrorDetailLine(cleanLines[i]))
				firstErrorLine = i;
			if (firstErrorLine > -1) break;
		}

		var start = firstErrorLine > -1 ? Std.int(Math.max(0, firstErrorLine - 1)) : Std.int(Math.max(0, cleanLines.length - 12));
		var selected:Array<String> = [];
		var maxLines = 14;
		var i = start;
		while (i < cleanLines.length && selected.length < maxLines)
		{
			selected.push(cleanLines[i]);
			i++;
		}

		if (i < cleanLines.length) selected.push("...");
		selected.push("");
		selected.push("Exit code: " + exitCode);
		return selected.join("\n");
	}

	private static function normalizeTitle(title:String):String
	{
		if (title == null) return "";

		var clean = stripAnsi(title);
		clean = StringTools.replace(clean, "\r", " ");
		clean = StringTools.replace(clean, "\n", " ");
		clean = StringTools.replace(clean, "\t", " ");
		clean = StringTools.trim(clean);
		while (clean.indexOf("  ") > -1) clean = StringTools.replace(clean, "  ", " ");
		if (clean.length > 180) clean = clean.substr(0, 177) + "...";
		return clean;
	}

	private static function normalizeDetailLine(line:String):String
	{
		if (line == null) return "";

		var clean = stripAnsi(line);
		clean = StringTools.replace(clean, "\r", "");
		clean = StringTools.replace(clean, "\t", "    ");
		clean = StringTools.trim(clean);
		if (clean.length > 320) clean = clean.substr(0, 317) + "...";
		return clean;
	}

	private static function isProgressNoiseLine(line:String):Bool
	{
		if (line == null || line == "") return false;
		return ~/^\[[#=\-]{3,}\]\s+[0-9]+%/.match(line);
	}

	private static function isErrorDetailLine(line:String):Bool
	{
		if (line == null || line == "" || isProgressNoiseLine(line)) return false;

		return ~/^\s*(ERROR|Fatal|PANIC)\b/.match(line)
			|| ~/^\s*Error:/.match(line)
			|| ~/\berror\s+[A-Z]*[0-9]+:/i.match(line)
			|| ~/^\s*Exception:/i.match(line)
			|| ~/CALLBACK ERROR/i.match(line)
			|| ~/Type not found/i.match(line)
			|| ~/Expected .+/i.match(line)
			|| ~/Build failed/i.match(line)
			|| ~/Compilation failed/i.match(line);
	}

	private static function stripAnsi(value:String):String
	{
		if (value == null) return "";
		return new EReg(String.fromCharCode(27) + "\\[[0-9;]*m", "g").replace(value, "");
	}

	private static function getMemePlayerScript():String
	{
		return [
			"param(",
			"    [string]$Video,",
			"    [string]$Title,",
			"    [string]$CausePath",
			")",
			"Add-Type -AssemblyName PresentationCore",
			"Add-Type -AssemblyName PresentationFramework",
			"Add-Type -AssemblyName WindowsBase",
			"if ([string]::IsNullOrWhiteSpace($Title)) { $Title = 'Lime build failed' }",
			"$cause = 'No error details were captured.'",
			"if (![string]::IsNullOrWhiteSpace($CausePath) -and (Test-Path -LiteralPath $CausePath)) {",
			"    $cause = Get-Content -LiteralPath $CausePath -Raw -Encoding UTF8",
			"}",
			"$window = New-Object Windows.Window",
			"$window.Title = $Title",
			"$window.Width = 854",
			"$window.Height = 620",
			"$window.MinWidth = 640",
			"$window.MinHeight = 420",
			"$window.ResizeMode = 'CanResize'",
			"$window.WindowStartupLocation = 'CenterScreen'",
			"$window.Topmost = $true",
			"$window.Background = [Windows.Media.Brushes]::Black",
			"$panel = New-Object Windows.Controls.DockPanel",
			"$panel.LastChildFill = $true",
			"$media = New-Object Windows.Controls.MediaElement",
			"$media.LoadedBehavior = 'Manual'",
			"$media.UnloadedBehavior = 'Stop'",
			"$media.Stretch = 'Uniform'",
			"$media.Source = [Uri]::new((Resolve-Path -LiteralPath $Video).Path)",
			"$causeBorder = New-Object Windows.Controls.Border",
			"$causeBorder.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(12, 12, 12))",
			"$causeBorder.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(70, 70, 70))",
			"$causeBorder.BorderThickness = [Windows.Thickness]::new(0, 1, 0, 0)",
			"$causeBorder.Padding = [Windows.Thickness]::new(12, 9, 12, 10)",
			"$scroll = New-Object Windows.Controls.ScrollViewer",
			"$scroll.Height = 132",
			"$scroll.VerticalScrollBarVisibility = 'Auto'",
			"$scroll.HorizontalScrollBarVisibility = 'Disabled'",
			"$text = New-Object Windows.Controls.TextBlock",
			"$text.Text = $cause",
			"$text.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(255, 95, 95))",
			"$text.FontFamily = [Windows.Media.FontFamily]::new('Consolas')",
			"$text.FontSize = 13",
			"$text.TextWrapping = 'Wrap'",
			"$scroll.Content = $text",
			"$causeBorder.Child = $scroll",
			"[Windows.Controls.DockPanel]::SetDock($causeBorder, [Windows.Controls.Dock]::Bottom)",
			"$panel.Children.Add($causeBorder) | Out-Null",
			"$panel.Children.Add($media) | Out-Null",
			"$window.Content = $panel",
			"$media.add_MediaEnded({ $window.Close() })",
			"$media.add_MediaFailed({ $window.Close() })",
			"$window.add_ContentRendered({ $media.Play() })",
			"$window.add_Closed({ $media.Stop() })",
			"$window.ShowDialog() | Out-Null"
		].join("\n");
	}

	private static function getTemporaryPath(name:String):String
	{
		var temp = Sys.getEnv("TEMP");
		if (temp == null || temp == "") temp = Sys.getEnv("TMP");
		if (temp == null || temp == "") temp = Sys.getCwd();
		return Path.combine(temp, name);
	}

	private static function getTemporaryRunPath(name:String):String
	{
		var dot = name.lastIndexOf(".");
		var suffix = "-" + Std.string(Date.now().getTime()) + "-" + Std.random(1000000);
		if (dot > -1)
		{
			name = name.substr(0, dot) + suffix + name.substr(dot);
		}
		else
		{
			name += suffix;
		}
		return getTemporaryPath(name);
	}

	private static function psQuote(value:String):String
	{
		if (value == null) value = "";
		return "'" + StringTools.replace(value, "'", "''") + "'";
	}

	private static function cmdQuote(value:String):String
	{
		if (value == null) value = "";
		return '"' + StringTools.replace(value, '"', '\\"') + '"';
	}

	public static function main()
	{
		var args = Sys.args();

		if (args.length > 2 && args[0] == "rebuild" && args[1] == "tools")
		{
			var lastArgument = new Path(args[args.length - 1]).toString();
			var cacheDirectory = Sys.getCwd();

			if (((StringTools.endsWith(lastArgument, "/") && lastArgument != "/") || StringTools.endsWith(lastArgument, "\\"))
				&& !StringTools.endsWith(lastArgument, ":\\"))
			{
				lastArgument = lastArgument.substr(0, lastArgument.length - 1);
			}

			if (FileSystem.exists(lastArgument) && FileSystem.isDirectory(lastArgument))
			{
				Sys.setCwd(lastArgument);
			}

			Haxelib.workingDirectory = Sys.getCwd();
			var rebuildBinaries = true;

			for (arg in args)
			{
				var equals = arg.indexOf("=");

				if (equals > -1 && StringTools.startsWith(arg, "--"))
				{
					var argValue = arg.substr(equals + 1);
					var field = arg.substr(2, equals - 2);

					if (StringTools.startsWith(field, "haxelib-"))
					{
						var name = field.substr(8);
						Haxelib.pathOverrides.set(name, Path.tryFullPath(argValue));
					}
				}
				else if (StringTools.startsWith(arg, "-"))
				{
					switch (arg)
					{
						case "-v", "-verbose":
							Log.verbose = true;

						case "-nocolor":
							Log.enableColor = false;

						case "-nocffi":
							rebuildBinaries = false;

						default:
					}
				}
			}

			rebuildTools(rebuildBinaries);

			if (args.indexOf("-openfl") > -1)
			{
				Sys.setCwd(cacheDirectory);
			}
			else
			{
				Sys.exit(0);
			}
		}

		if (args.indexOf("-eval") >= 0)
		{
			args.remove("-eval");
			Log.info("Experimental: executing `lime " + args.slice(0, args.length - 1).join(" ")
				+ "` using Eval (https://haxe.org/blog/eval/)");

			var args = [
				"-D", "lime",
				"-cp", "tools",
				"-cp", "tools/platforms",
				"-cp", "src",
				"-lib", "format",
				"-lib", "hxp",
				"--run", "CommandLineTools"].concat(args);
			Sys.exit(runCommand("", "haxe", args));
		}

		if (!FileSystem.exists("tools/tools.n") || args.indexOf("-rebuild") > -1)
		{
			rebuildTools();
		}

		var args = ["tools/tools.n"].concat(args);
		Sys.exit(runCommand("", "neko", args));
	}
}
