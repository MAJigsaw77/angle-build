package angle;

import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

import angle.util.ANSIUtil;
import angle.util.FileUtil;

class Setup
{
	public static function run():Void
	{
		if (Sys.systemName() == 'Windows')
		{
			// We need to set DEPOT_TOOLS_WIN_TOOLCHAIN to 0 for non-Googlers.
			Sys.putEnv('DEPOT_TOOLS_WIN_TOOLCHAIN', '0');
		}

		// Surpress Chromium development Git warnings.
		Sys.command('git', ['config', '--global', 'depot-tools.allowGlobalGitConfig', 'false']);

		// Create the export folder.
		if (!FileSystem.exists('export'))
			FileSystem.createDirectory('export');

		// Go to the export folder.
		FileUtil.moveToDir('export');

		// Print
		Sys.println(ANSIUtil.apply('Angle setup starting...', [ANSICode.Bold, ANSICode.Blue]));

		// Clone depot_tools.
		gitClone('depot_tools', 'https://chromium.googlesource.com/chromium/tools/depot_tools.git');

		// Add depot_tools to PATH.
		addToPATH(FileSystem.absolutePath('depot_tools'));

		// Clone angle.
		gitClone('angle', 'https://chromium.googlesource.com/angle/angle');

		// Configure and sync ANGLE dependencies
		FileUtil.goAndBackFromDir('angle', function():Void
		{
			// Configure and sync ANGLE dependencies
			Sys.command('gclient', ['config', '--unmanaged', 'https://chromium.googlesource.com/angle/angle']);

			{
				// Create a .gclient file with proper setup
				final gclientFile:Array<String> = [];
				gclientFile.push('solutions = [');
				gclientFile.push('  {');
				gclientFile.push('     "name": ".",');
				gclientFile.push('     "url": "https://chromium.googlesource.com/angle/angle",');
				gclientFile.push('     "deps_file": "DEPS",');
				gclientFile.push('     "managed": False,');
				gclientFile.push('  }');
				gclientFile.push(']');
				File.saveContent('.gclient', gclientFile.join('\n'));
			}

			// Syncing ANGLE dependencies with gclient...
			Sys.command('gclient', ['sync', '--no-history', '--shallow', '--jobs', '8']);

			// Apply patches to ANGLE (to fix stupid issues).
			readAndApplyGitPatches('../patches');
		});

		// Print
		Sys.println(ANSIUtil.apply('Angle setup complete!', [ANSICode.Bold, ANSICode.Blue]));
	}

	@:noCompletion
	static function gitClone(name:String, url:String):Void
	{
		if (!FileSystem.exists(name))
			Sys.command('git', ['clone', '--depth', '1', url]);
	}

	@:noCompletion
	static function readAndApplyGitPatches(dir:String):Void
	{
		if (!FileSystem.exists(dir))
			return;

		final patches:Array<String> = FileSystem.readDirectory(dir);

		patches.sort(Reflect.compare);

		for (patch in patches)
		{
			if (Path.extension(patch) == 'patch')
			{
				final patchPath:String = Path.join([dir, patch]);

				final patchCheck:Int = Sys.command('git', ['apply', '--check', patchPath]);
	
				if (patchCheck != 0)
				{
					Sys.println(ANSIUtil.apply('Cannot apply "$patch"! Continuing without being applied', [ANSICode.Bold, ANSICode.Yellow]));
				}
				else
					Sys.command('git', ['apply', patchPath]);
			}
		}
	}

	@:noCompletion
	static function addToPATH(string:String):Void
	{
		if (Path.isAbsolute(string))
		{
			if (Sys.systemName() == 'Windows')
				Sys.putEnv('PATH', [string, Sys.getEnv('PATH')].join(';'));
			else
				Sys.putEnv('PATH', [string, Sys.getEnv('PATH')].join(':'));
		}
	}
}
